// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#pragma once

#import <AVFoundation/AVFoundation.h>
#import <vector>

#import "BiquadFilter.hpp"
#import "KernelEventProcessor.hpp"
#import "ValueChangeDetector.hpp"

/**
 Applies a low-pass filtering to input samples.
 */
class FilterDSPKernel : public KernelEventProcessor<FilterDSPKernel> {
public:
    FilterDSPKernel();

    void setFormat(AVAudioFormat* format, AVAudioChannelCount channelCount, AUAudioFrameCount maxFramesToRender);

    void reset();

    void setParameterValue(AUParameterAddress address, AUValue value);
    AUValue getParameterValue(AUParameterAddress address) const;

    float sampleRate() const { return sampleRate_; }
    float nyquistFrequency() const { return nyquistFrequency_; }
    float nyquistPeriod() const { return nyquistPeriod_; }
    float cutoff() const { return cutoff_; }
    float resonance() const { return resonance_; }

private:

    void doParameterEvent(AUParameterEvent const& event) { setParameterValue(event.parameterAddress, event.value); }
    void doMIDIEvent(AUMIDIEvent const& midiEvent) {}
    void doRenderFrames(std::vector<float const*> const& ins, std::vector<float*>& outs, AUAudioFrameCount frameCount);

    BiquadFilter filter_;

    float sampleRate_ = 44100.0;
    float nyquistFrequency_ = 0.5 * sampleRate_;
    float nyquistPeriod_ = 1.0 / nyquistFrequency_;

    ValueChangeDetector<float> cutoff_;
    ValueChangeDetector<float> resonance_;

    friend class KernelEventProcessor<FilterDSPKernel>;
};
