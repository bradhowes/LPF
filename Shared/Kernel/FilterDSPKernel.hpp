// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#pragma once

#import <AVFoundation/AVFoundation.h>

#import "BiquadFilter.hpp"
#import "FilterDSPKernelAdapter.h"
#import "KernelEventProcessor.hpp"

class FilterDSPKernel : public KernelEventProcessor<FilterDSPKernel> {
public:
    using super = KernelEventProcessor<FilterDSPKernel>;

    FilterDSPKernel() : super(os_log_create("LPF", "FilterDSPKernel")), cutoff_{float(400.0)}, resonance_{20.0}
    {
        filter_.calculateParams(cutoff_, resonance_, nyquistPeriod_, 2);
    }

    /**
     Update kernel and buffers to support the given format and channel count
     */
    void startProcessing(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender)
    {
        super::startProcessing(format, maxFramesToRender);

        sampleRate_ = format.sampleRate;
        nyquistFrequency_ = 0.5 * sampleRate_;
        nyquistPeriod_ = 1.0 / nyquistFrequency_;
        channelCount_ = format.channelCount;
    }

    void stopProcessing() {
        super::stopProcessing();
    }

    void setParameterValue(AUParameterAddress address, AUValue value)
    {
        switch (address) {
            case FilterParameterAddressCutoff:
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "set cutoff: %f", value);
                cutoff_ = value;
                break;

            case FilterParameterAddressResonance:
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "set resonance: %f", value);
                resonance_ = value;
                break;
        }
    }

    AUValue getParameterValue(AUParameterAddress address) const
    {
        switch (address) {
            case FilterParameterAddressCutoff:
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "get cutoff: %f", cutoff_);
                return cutoff_;

            case FilterParameterAddressResonance:
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "get resonance: %f", resonance_);
                return resonance_;

            default: return 0.0;
        }
    }

    void handleParameterEvent(AUParameterEvent const& event)
    {
        setParameterValue(event.parameterAddress, event.value);
    }

    void handleRendering(std::vector<float const*> ins, std::vector<float*> outs, AUAudioFrameCount frameCount) {
        filter_.calculateParams(cutoff_, resonance_, nyquistPeriod_, ins.size());
        filter_.apply(ins, outs, frameCount);
    }

    void handleMIDIEvent(AUMIDIEvent const& midiEvent) {}

    float nyquistPeriod() const { return nyquistPeriod_; }
    float cutoff() const { return cutoff_; }
    float resonance() const { return resonance_; }

private:
    BiquadFilter filter_;

    float sampleRate_ = 44100.0;
    size_t channelCount_ = 1;
    float nyquistFrequency_ = 0.5 * sampleRate_;
    float nyquistPeriod_ = 1.0 / nyquistFrequency_;

    float cutoff_;
    float resonance_;
};
