// Copyright © 2020 Brad Howes. All rights reserved.

#pragma once

#import <AudioToolbox/AudioToolbox.h>

class DSPKernel {
public:

    virtual void setFormat(AVAudioFormat* format) {}

    void render(AudioTimeStamp const* timestamp, AUAudioFrameCount frameCount, AURenderEvent const* events);

    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) {}

    AUAudioFrameCount maximumFramesToRender() const {
        return maxFramesToRender;
    }

    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) {
        maxFramesToRender = maxFrames;
    }

    virtual void setBuffers(AudioBufferList* inBufferList, AudioBufferList* outBufferList) {}

    virtual void setParameterValue(AUParameterAddress address, AUValue value) {}

    virtual AUValue getParameterValue(AUParameterAddress address) { return 0.0; }

protected:
    virtual void renderFrames(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) = 0;

    virtual void handleParameterEvent(const AUParameterEvent& event) = 0;

private:
    void renderEvent(AURenderEvent const& event);

    AURenderEvent const* renderEventsUntil(AUEventSampleTime now, AURenderEvent const* events);
    AUAudioFrameCount maxFramesToRender = 512;
};
