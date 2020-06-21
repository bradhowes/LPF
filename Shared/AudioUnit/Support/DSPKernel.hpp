// Copyright © 2020 Brad Howes. All rights reserved.

#pragma once

#import <AudioToolbox/AudioToolbox.h>

class DSPKernel {
public:

    /**
     Perform sample rendering

     @param timestamp the times of events being rendered
     @param frameCount the number of frames (samples) to render
     @param events collection of events to process during this render cycle
     */
    void render(AudioTimeStamp const* timestamp, AUAudioFrameCount frameCount, AURenderEvent const* events);

    /**
     Obtain the maximum number of frame to render.
     @returns max frames to render
     */
    AUAudioFrameCount maximumFramesToRender() const { return maxFramesToRender; }

    /**
     Set the maximum frames to render
     @parameter maxFrames the new vaue to use
     */
    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) { maxFramesToRender = maxFrames; }

protected:

    virtual void renderFrames(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) = 0;

    virtual void handleParameterEvent(const AUParameterEvent& event) = 0;

    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) {}

private:
    void renderEvent(AURenderEvent const& event);

    AURenderEvent const* renderEventsUntil(AUEventSampleTime now, AURenderEvent const* events);

    AUAudioFrameCount maxFramesToRender = 512;
};
