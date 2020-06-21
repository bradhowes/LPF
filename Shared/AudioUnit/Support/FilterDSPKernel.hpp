// Copyright © 2020 Brad Howes. All rights reserved.

#pragma once

#import <Accelerate/Accelerate.h>
#import <vector>

#import "DSPKernel.hpp"
#import "ParameterMonitor.hpp"

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
        enum Index { B0 = 0, B1, B2, A1, A2 };

        std::vector<double> coeffs_;
        vDSP_biquadm_Setup setup_ = nullptr;

        double lastFrequency_ = -1.0;
        double lastResonance_ = 1E10;
        size_t lastNumChannels_ = 0;

        float threshold_ = 0.05;
        float updateRate_ = 0.4;

        void calculateLopassParams(double frequency, double resonance, size_t numChannels)
        {
            if (lastFrequency_ == frequency && lastResonance_ == resonance && numChannels == lastNumChannels_) return;

            double r = pow(10.0, 0.05 * -resonance);
            double k  = 0.5 * r * sin(M_PI * frequency);
            double c1 = (1.0 - k) / (1.0 + k);
            double c2 = (1.0 + c1) * cos(M_PI * frequency);
            double c3 = (1.0 + c1 - c2) * 0.25;

            coeffs_.clear();
            for (auto channel = 0; channel < numChannels; ++channel) {
                coeffs_.push_back(c3);
                coeffs_.push_back(2.0 * c3);
                coeffs_.push_back(c3);
                coeffs_.push_back(-c2);
                coeffs_.push_back(c1);
            }

            if (setup_ != nullptr && numChannels == lastNumChannels_) {
                vDSP_biquadm_SetTargetsDouble(setup_, coeffs_.data(), updateRate_, threshold_, 0, 0, 1,
                                              numChannels);
            }
            else {
                if (setup_ != nullptr) vDSP_biquadm_DestroySetup(setup_);
                setup_ = vDSP_biquadm_CreateSetup(coeffs_.data(), 1, numChannels);
            }

            lastFrequency_ = frequency;
            lastResonance_ = resonance;
            lastNumChannels_ = numChannels;
        }

        // Arguments in Hertz.
        double magnitudeForFrequency(double inFreq)
        {
            double theta = M_PI * inFreq;

            // Frequency on unit circle in z-plane.
            double zReal = cos(theta);
            double zImaginary = sin(theta);

            // Zeros response.
            double numeratorReal = (coeffs_[B0] * (squared(zReal) - squared(zImaginary))) +
            (coeffs_[B1] * zReal) + coeffs_[B2];
            double numeratorImaginary = (2.0 * coeffs_[B0] * zReal * zImaginary) +
            (coeffs_[B1] * zImaginary);
            double numeratorMagnitude = sqrt(squared(numeratorReal) + squared(numeratorImaginary));

            // Poles response.
            double denominatorReal = squared(zReal) - squared(zImaginary) + (coeffs_[A1] * zReal) +
            coeffs_[A2];
            double denominatorImaginary = (2.0 * zReal * zImaginary) + (coeffs_[A1] * zImaginary);

            double denominatorMagnitude = sqrt(squared(denominatorReal) + squared(denominatorImaginary));
            return numeratorMagnitude / denominatorMagnitude;
        }

        static double squared(double x) { return x * x; }
    };

    // MARK: Member Functions

    FilterDSPKernel() : DSPKernel(), cutoff_{float(400.0)}, resonance_{20.0} {}

    void setFormat(AVAudioFormat* format) override
    {
        sampleRate_ = format.sampleRate;
        nyquistFrequency_ = 0.5 * sampleRate_;
        nyquistPeriod_ = 1.0 / nyquistFrequency_;
        channelCount_ = format.channelCount;
        reset();
    }

    void reset() {
        cutoff_.reset();
        resonance_.reset();
    }

    bool isBypassed() { return bypassed; }
    void setBypass(bool shouldBypass) { bypassed = shouldBypass; }

    void setParameterValue(AUParameterAddress address, AUValue value) override {
        switch (address) {
            case FilterParamCutoff:
                cutoff_ = value;
                break;

            case FilterParamResonance:
                resonance_ = value;
                break;
        }
    }

    AUValue getParameterValue(AUParameterAddress address) override {
        switch (address) {
            case FilterParamCutoff: return cutoff_;
            case FilterParamResonance: return resonance_;
            default: return 0.0;
        }
    }

    void handleParameterEvent(AUParameterEvent const& event) override
    {
        setParameterValue(event.parameterAddress, event.value);
    }

    void setBuffers(AudioBufferList* inputs, AudioBufferList* outputs) override {
        inputs_ = inputs;
        outputs_ = outputs;
        ins_.clear();
        outs_.clear();
        for (size_t channel = 0; channel < channelCount(); ++channel) {
            ins_.emplace_back(static_cast<float*>(inputs_->mBuffers[channel].mData));
            outs_.emplace_back(static_cast<float*>(outputs_->mBuffers[channel].mData));
        }
    }

    void renderFrames(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        if (bypassed) {
            for (size_t channel = 0; channel < channelCount(); ++channel) {
                if (inputs_->mBuffers[channel].mData == outputs_->mBuffers[channel].mData) {
                    continue;
                }
                for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                    int frameOffset = int(frameIndex + bufferOffset);
                    auto in = (float*)inputs_->mBuffers[channel].mData  + frameOffset;
                    auto out = (float*)outputs_->mBuffers[channel].mData + frameOffset;
                    *out = *in;
                }
            }
            return;
        }

        for (size_t channel = 0; channel < channelCount(); ++channel) {
            ins_[channel] = static_cast<float*>(inputs_->mBuffers[channel].mData) + bufferOffset;
            outs_[channel] = static_cast<float*>(outputs_->mBuffers[channel].mData) + bufferOffset;
        }

        coeffs_.calculateLopassParams(cutoffFilterSetting(), resonanceFilterSetting(), channelCount());

        vDSP_biquadm(coeffs_.setup_,
                     (const float * __nonnull * __nonnull)ins_.data(), vDSP_Stride(1),
                     (float * __nonnull * __nonnull)outs_.data(), vDSP_Stride(1),
                     vDSP_Length(frameCount));
    }

    size_t channelCount() const { return channelCount_; }
    float cutoffFilterSetting() const { return cutoff_ * nyquistPeriod_; }
    float resonanceFilterSetting() const { return resonance_; }

private:
    BiquadCoefficients coeffs_;

    float sampleRate_ = 44100.0;
    float nyquistFrequency_ = 0.5 * sampleRate_;
    float nyquistPeriod_ = 1.0 / nyquistFrequency_;
    size_t channelCount_ = 1;

    ParameterMonitor<float> cutoff_;
    ParameterMonitor<float> resonance_;

    AudioBufferList* inputs_ = nullptr;
    AudioBufferList* outputs_ = nullptr;

    std::vector<float*> ins_;
    std::vector<float*> outs_;

    bool bypassed = false;
};
