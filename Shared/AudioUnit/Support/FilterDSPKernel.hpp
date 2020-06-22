// Copyright © 2020 Brad Howes. All rights reserved.

#pragma once

#import <Accelerate/Accelerate.h>
#import <vector>

#import "BiquadFilter.hpp"
#import "DSPKernel.hpp"
#import "ValueChangeDetector.hpp"

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

    FilterDSPKernel() : DSPKernel(), cutoff_{float(400.0)}, resonance_{20.0} {}

    void setFormat(AVAudioFormat* format)
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

    void setParameterValue(AUParameterAddress address, AUValue value) {
        switch (address) {
            case FilterParamCutoff:
                cutoff_ = value;
                break;

            case FilterParamResonance:
                resonance_ = value;
                break;
        }
    }

    AUValue getParameterValue(AUParameterAddress address) {
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

    void setBuffers(AudioBufferList* inputs, AudioBufferList* outputs) {
        if (inputs == inputs_ && outputs_ == outputs) return;
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

        filter_.calculateParams(cutoffFilterSetting(), resonanceFilterSetting(), channelCount());
        filter_.apply(ins_, outs_, frameCount);
    }

    float sampleRate() const { return sampleRate_; }
    size_t channelCount() const { return channelCount_; }

    float nyquistFrequency() const { return nyquistFrequency_; }
    float nyquistPeriod() const { return nyquistPeriod_; }

    float cutoffFilterSetting() const { return cutoff_ * nyquistPeriod_; }
    float resonanceFilterSetting() const { return resonance_; }

private:
    BiquadFilter filter_;

    float sampleRate_ = 44100.0;
    size_t channelCount_ = 1;
    float nyquistFrequency_ = 0.5 * sampleRate_;
    float nyquistPeriod_ = 1.0 / nyquistFrequency_;

    ValueChangeDetector<float> cutoff_;
    ValueChangeDetector<float> resonance_;

    AudioBufferList* inputs_ = nullptr;
    AudioBufferList* outputs_ = nullptr;

    std::vector<float const*> ins_;
    std::vector<float*> outs_;

    bool bypassed = false;
};
