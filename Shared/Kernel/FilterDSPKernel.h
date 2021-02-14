// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#pragma once

#import <AVFoundation/AVFoundation.h>

#import "BiquadFilter.h"
#import "FilterDSPKernelAdapter.h"
#import "KernelEventProcessor.h"

class FilterDSPKernel : public KernelEventProcessor<FilterDSPKernel> {
public:
    using super = KernelEventProcessor<FilterDSPKernel>;
    friend super;

    FilterDSPKernel(std::string const& name)
    : super(os_log_create(name.c_str(), "FilterDSPKernel")), cutoff_{float(400.0)}, resonance_{20.0}
    {
        setSampleRate(44100.0);
        filter_.calculateParams(cutoff_, resonance_, nyquistPeriod_, 2);
    }

    /**
     Update kernel and buffers to support the given format and channel count
     */
    void startProcessing(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender)
    {
        super::startProcessing(format, maxFramesToRender);
        setSampleRate(format.sampleRate);
    }

    void stopProcessing() { super::stopProcessing(); }

    void setParameterValue(AUParameterAddress address, AUValue value)
    {
        switch (address) {
            case FilterParameterAddressCutoff:
                os_log_with_type(log_, OS_LOG_TYPE_DEBUG, "set cutoff: %f", value);
                cutoff_ = value;
                break;

            case FilterParameterAddressResonance:
                os_log_with_type(log_, OS_LOG_TYPE_DEBUG, "set resonance: %f", value);
                resonance_ = value;
                break;
        }
    }

    AUValue getParameterValue(AUParameterAddress address) const
    {
        switch (address) {
            case FilterParameterAddressCutoff:
                os_log_with_type(log_, OS_LOG_TYPE_DEBUG, "get cutoff: %f", cutoff_);
                return cutoff_;

            case FilterParameterAddressResonance:
                os_log_with_type(log_, OS_LOG_TYPE_DEBUG, "get resonance: %f", resonance_);
                return resonance_;

            default: return 0.0;
        }
    }

    float nyquistPeriod() const { return nyquistPeriod_; }
    float cutoff() const { return cutoff_; }
    float resonance() const { return resonance_; }

private:

    void doParameterEvent(AUParameterEvent const& event) { setParameterValue(event.parameterAddress, event.value); }

    void doRendering(std::vector<float const*> ins, std::vector<float*> outs, AUAudioFrameCount frameCount) {
        filter_.calculateParams(cutoff_, resonance_, nyquistPeriod_, ins.size());
        filter_.apply(ins, outs, frameCount);
    }

    void doMIDIEvent(AUMIDIEvent const& midiEvent) {}

    void setSampleRate(float value) {
        sampleRate_ = value;
        nyquistFrequency_ = 0.5 * sampleRate_;
        nyquistPeriod_ = 1.0 / nyquistFrequency_;
    }

    BiquadFilter filter_;

    float sampleRate_;
    float nyquistFrequency_;
    float nyquistPeriod_;

    float cutoff_;
    float resonance_;
};
