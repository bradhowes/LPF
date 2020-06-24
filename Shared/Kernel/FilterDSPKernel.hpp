// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#pragma once

#import <AVFoundation/AVFoundation.h>
#import <vector>

#import "BiquadFilter.hpp"
#import "DSPKernel.hpp"
#import "ValueChangeDetector.hpp"

class FilterDSPKernel : public DSPKernel {
public:

    FilterDSPKernel() : DSPKernel(), cutoff_{float(400.0)}, resonance_{20.0} {}

    void setFormat(AVAudioFormat* format);

    void reset();

    bool isBypassed() { return bypassed; }
    void setBypass(bool shouldBypass) { bypassed = shouldBypass; }

    void setParameterValue(AUParameterAddress address, AUValue value);

    AUValue getParameterValue(AUParameterAddress address) const;

    void handleParameterEvent(AUParameterEvent const& event) override
    {
        setParameterValue(event.parameterAddress, event.value);
    }

    void setBuffers(AudioBufferList* inputs, AudioBufferList* outputs);

    void renderFrames(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override;

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
