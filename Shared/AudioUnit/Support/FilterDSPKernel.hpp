// Copyright © 2020 Brad Howes. All rights reserved.

#pragma once

#import "DSPKernel.hpp"
#import "ParameterRamper.hpp"
#import <vector>

enum {
    FilterParamCutoff = 0,
    FilterParamResonance = 1
};

/*
 FilterDSPKernel
 Performs our filter signal processing.
 As a non-ObjC class, this is safe to use from render thread.
 */
class FilterDSPKernel : public DSPKernel {
public:
    // MARK: Types
    struct FilterState {
        float x1 = 0.0;
        float x2 = 0.0;
        float y1 = 0.0;
        float y2 = 0.0;

        void clear() {
            x1 = 0.0;
            x2 = 0.0;
            y1 = 0.0;
            y2 = 0.0;
        }

        static float convertBadValuesToZero(float x)
        {
            constexpr float minValue = 1.0E-15;
            constexpr float maxValue = 1.0E15;
            float absx = fabs(x);
            return (absx >= minValue && absx <= maxValue) ? x : 0.0;
        }

        void convertBadStateValuesToZero() {
            x1 = convertBadValuesToZero(x1);
            x2 = convertBadValuesToZero(x2);
            y1 = convertBadValuesToZero(y1);
            y2 = convertBadValuesToZero(y2);
        }
    };

    struct BiquadCoefficients {
        float a1 = 0.0;
        float a2 = 0.0;
        float b0 = 0.0;
        float b1 = 0.0;
        float b2 = 0.0;

        void calculateLopassParams(double frequency, double resonance) {

            // Convert from decibels to linear.
            double r = pow(10.0, 0.05 * -resonance);

            double k  = 0.5 * r * sin(M_PI * frequency);
            double c1 = (1.0 - k) / (1.0 + k);
            double c2 = (1.0 + c1) * cos(M_PI * frequency);
            double c3 = (1.0 + c1 - c2) * 0.25;

            b0 = float(c3);
            b1 = float(2.0 * c3);
            b2 = float(c3);
            a1 = float(-c2);
            a2 = float(c1);
        }

        // Arguments in Hertz.
        double magnitudeForFrequency( double inFreq) {
            // Cast to Double.
            double _b0 = double(b0);
            double _b1 = double(b1);
            double _b2 = double(b2);
            double _a1 = double(a1);
            double _a2 = double(a2);

            // Frequency on unit circle in z-plane.
            double zReal      = cos(M_PI * inFreq);
            double zImaginary = sin(M_PI * inFreq);

            // Zeros response.
            double numeratorReal = (_b0 * (squared(zReal) - squared(zImaginary))) + (_b1 * zReal) + _b2;
            double numeratorImaginary = (2.0 * _b0 * zReal * zImaginary) + (_b1 * zImaginary);

            double numeratorMagnitude = sqrt(squared(numeratorReal) + squared(numeratorImaginary));

            // Poles response.
            double denominatorReal = squared(zReal) - squared(zImaginary) + (_a1 * zReal) + _a2;
            double denominatorImaginary = (2.0 * zReal * zImaginary) + (_a1 * zImaginary);

            double denominatorMagnitude = sqrt(squared(denominatorReal) + squared(denominatorImaginary));

            // Total response.
            double response = numeratorMagnitude / denominatorMagnitude;

            return response;
        }

        static double squared(double x) { return x * x; }
    };

    // MARK: Member Functions

    FilterDSPKernel()
    : DSPKernel(), cutoffRamper(400.0 / 44100.0), resonanceRamper(20.0)
    {}

    void setFormat(AVAudioFormat* format) override
    {
        channelStates_.resize(format.channelCount);
        sampleRate = float(format.sampleRate);
        nyquist = 0.5 * sampleRate;
        inverseNyquist = 1.0 / nyquist;
        rampDuration_ = (AUAudioFrameCount)floor(0.02 * sampleRate);
        cutoffRamper.reset();
        resonanceRamper.reset();
    }

    void reset() {
        cutoffRamper.reset();
        resonanceRamper.reset();
        for (FilterState& state : channelStates_) {
            state.clear();
        }
    }

    bool isBypassed() {
        return bypassed;
    }

    void setBypass(bool shouldBypass) {
        bypassed = shouldBypass;
    }

    float cutoffToDisplay() const
    {
        return round(cutoffRamper.getValue() * nyquist * 100.0) / 100.0;
    }

    void setCutoffFromDisplay(float value)
    {
        cutoffRamper.setValue(value * inverseNyquist);
    }

    void setParameterValue(AUParameterAddress address, AUValue value) override {
        switch (address) {
            case FilterParamCutoff:
                cutoffRamper.setValue(value * inverseNyquist);
                break;

            case FilterParamResonance:
                resonanceRamper.setValue(value);
                break;
        }
    }

    AUValue getParameterValue(AUParameterAddress address) override {
        switch (address) {
            case FilterParamCutoff: return cutoffRamper.getValue() * nyquist;
            case FilterParamResonance: return resonanceRamper.getValue();
            default: return 0.0;
        }
    }

    void handleParameterEvent(AUParameterEvent const& event) override
    {
        switch (event.parameterAddress) {
            case FilterParamCutoff:
                cutoffRamper.setValue(event.value, event.rampDurationSampleFrames);
                break;

            case FilterParamResonance:
                resonanceRamper.setValue(event.value, event.rampDurationSampleFrames);
                break;
        }
    }

    void setBuffers(AudioBufferList* inBufferList, AudioBufferList* outBufferList) override {
        inBufferListPtr = inBufferList;
        outBufferListPtr = outBufferList;
    }

    void renderFrames(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        if (bypassed) {
            // Pass the samples through
            int channelCount = int(channelStates_.size());
            for (int channel = 0; channel < channelCount; ++channel) {
                if (inBufferListPtr->mBuffers[channel].mData ==  outBufferListPtr->mBuffers[channel].mData) {
                    continue;
                }
                for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                    int frameOffset = int(frameIndex + bufferOffset);
                    float* in  = (float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
                    float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                    *out = *in;
                }
            }
            return;
        }

        // Consider using vDSP functions for vectorizing this
        // Slight difficulting involving the ramping parameters

        int channelCount = int(channelStates_.size());

        cutoffRamper.startRamping(rampDuration_);
        resonanceRamper.startRamping(rampDuration_);

        for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
            double cutoff = double(cutoffRamper.getAndStep() * nyquist);
            double resonance = double(resonanceRamper.getAndStep());
            coeffs_.calculateLopassParams(cutoff, resonance);

            int frameOffset = int(frameIndex + bufferOffset);

            for (int channel = 0; channel < channelCount; ++channel) {
                FilterState& state = channelStates_[channel];
                float* in  = static_cast<float*>(inBufferListPtr->mBuffers[channel].mData)  + frameOffset;
                float* out = static_cast<float*>(outBufferListPtr->mBuffers[channel].mData) + frameOffset;

                float x0 = *in;
                float y0 = (coeffs_.b0 * x0) + (coeffs_.b1 * state.x1) + (coeffs_.b2 * state.x2) -
                (coeffs_.a1 * state.y1) - (coeffs_.a2 * state.y2);
                *out = y0;

                state.x2 = state.x1;
                state.x1 = x0;
                state.y2 = state.y1;
                state.y1 = y0;
            }
        }

        for (int channel = 0; channel < channelCount; ++channel) {
            channelStates_[channel].convertBadStateValuesToZero();
        }
    }

private:
    std::vector<FilterState> channelStates_;
    BiquadCoefficients coeffs_;

    float sampleRate = 44100.0;
    float nyquist = 0.5 * sampleRate;
    float inverseNyquist = 1.0 / nyquist;
    AUAudioFrameCount rampDuration_;

    AudioBufferList* inBufferListPtr = nullptr;
    AudioBufferList* outBufferListPtr = nullptr;

    bool bypassed = false;

public:

    // Parameters.
    ParameterRamper<float> cutoffRamper;
    ParameterRamper<float> resonanceRamper;
};
