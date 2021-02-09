// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#pragma once

#import <algorithm>
#import <AudioToolbox/AudioToolbox.h>

/**
 Base class for DSP kernels that provides common functionality. It properly interleaves render events with parameter
 updates.

 Derived classes must define two methods: `renderFrames` and `handleParameterEvent`.
 */
template <typename T> class KernelEventProcessor {
public:

    /**
     Perform sample rendering. NOTE: the lack of any input/output buffers here. Everything is expected to be managed
     by the injected T class instance. There can be multiple calls to the T::doRenderFrames method from this one
     depending on the presence of any AURenderEvent objects.s

     @param timestamp the times of events being rendered
     @param frameCount the number of frames (samples) to render
     @param events collection of events to process during this render cycle
     */
    void render(AudioTimeStamp const* timestamp, AUAudioFrameCount frameCount, AURenderEvent const* events) {
        auto zero = AUEventSampleTime(0);
        auto now = AUEventSampleTime(timestamp->mSampleTime);
        auto framesRemaining = frameCount;

        // Process events and samples together. First process samples up to an event time and then do the event to
        // update render parameters. Continue until all frames (samples) are rendered.
        while (framesRemaining > 0) {
            if (events == nullptr) {
                injected()->doRenderFrames(framesRemaining, frameCount - framesRemaining);
                return;
            }

            auto framesThisSegment = AUAudioFrameCount(std::max(events->head.eventSampleTime - now, zero));
            if (framesThisSegment > 0) {
                injected()->doRenderFrames(framesThisSegment, frameCount - framesRemaining);
                framesRemaining -= framesThisSegment;
                now += AUEventSampleTime(framesThisSegment);
            }

            events = renderEventsUntil(now, events);
        }
    }

private:

    T* injected() { return static_cast<T*>(this); }

    AURenderEvent const* renderEventsUntil(AUEventSampleTime now, AURenderEvent const* event) {
        while (event != nullptr && event->head.eventSampleTime <= now) {
            switch (event->head.eventType) {
                case AURenderEventParameter:
                case AURenderEventParameterRamp:
                    injected()->doParameterEvent(event->parameter);
                    break;

                case AURenderEventMIDI:
                    injected()->doMIDIEvent(event->MIDI);
                    break;

                default:
                    break;
            }
            event = event->head.next;
        }
        return event;
    }

    AUAudioFrameCount maxFramesToRender = 512;
};
