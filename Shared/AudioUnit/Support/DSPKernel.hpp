// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#pragma once

#import <AudioToolbox/AudioToolbox.h>

/**
 Base class for DSP kernels that provides commmon functionality. It properly interleaves render events with parameter
 updates.

 Derived classes must define two methods: `renderFrames` and `handleParameterEvent`.
 */
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

    /**
     Render sample frames. Derived class must define.

     @param frameCount number of frames to render
     @param bufferOffset offset info internal sample buffers for the first sample to render
     */
    virtual void renderFrames(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) = 0;

    /**
     Process one parameter event. Derived class must define.

     @param event the event to process
     */
    virtual void handleParameterEvent(const AUParameterEvent& event) = 0;

    /**
     Process a MIDI event. Default behavior is to ignore them.

     @param midiEvent the event to process
     */
    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) {}

private:

    void renderEvent(AURenderEvent const& event);

    AURenderEvent const* renderEventsUntil(AUEventSampleTime now, AURenderEvent const* events);

    AUAudioFrameCount maxFramesToRender = 512;
};
