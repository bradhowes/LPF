// Copyright © 2020 Brad Howes. All rights reserved.

#pragma once

#import <AVFoundation/AVFoundation.h>
#import <vector>

#import "BiquadFilter.hpp"
#import "KernelEventProcessor.hpp"

/**
 Applies a low-pass filtering to input samples.
 */
class FilterDSPKernel : public KernelEventProcessor<FilterDSPKernel> {
public:
    FilterDSPKernel();

    /**
     Update kernel and buffers to support the given format and channel count
     */
    void startProcessing(AVAudioFormat* format, AVAudioChannelCount channelCount, AUAudioFrameCount maxFramesToRender);

    /**
     Reset filter to a known state.
     */
    void reset();

    /**
     Update a filter setting using the AUParameter infrastructure

     @param address the address of the parameter to set
     @param value the new value to set
     */
    void setParameterValue(AUParameterAddress address, AUValue value);

    /**
     Get the current filter setting using the AUParameter infrastructure

     @param address the address of the parameter to get
     */
    AUValue getParameterValue(AUParameterAddress address) const;

    float cutoff() const { return cutoff_; }
    float resonance() const { return resonance_; }
    float sampleRate() const { return sampleRate_; }
    float nyquistPeriod() const { return nyquistPeriod_; }

private:

    /// Process an AUParameter change
    void doParameterEvent(AUParameterEvent const& event);
    /// Process a MIDI event
    void doMIDIEvent(AUMIDIEvent const& midiEvent) {}
    /// Render some samples
    void doRenderFrames(std::vector<float const*> const& ins, std::vector<float*>& outs, AUAudioFrameCount frameCount);

    BiquadFilter filter_;

    float sampleRate_ = 44100.0;
    float nyquistPeriod_ = 2.0 / sampleRate_;
    float cutoff_;
    float resonance_;

    friend class KernelEventProcessor<FilterDSPKernel>;
};
