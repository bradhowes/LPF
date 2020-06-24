// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#import <algorithm>

#import "DSPKernel.hpp"

void
DSPKernel::renderEvent(AURenderEvent const& event) {
    switch (event.head.eventType) {
        case AURenderEventParameter:
        case AURenderEventParameterRamp:
            handleParameterEvent(event.parameter);
            break;

        case AURenderEventMIDI:
            handleMIDIEvent(event.MIDI);
            break;

        default:
            break;
    }
}

AURenderEvent const*
DSPKernel::renderEventsUntil(AUEventSampleTime now, AURenderEvent const *event)
{
    while (event != nullptr && event->head.eventSampleTime <= now) {
        renderEvent(*event);
        event = event->head.next;
    }

    return event;
}

void
DSPKernel::render(AudioTimeStamp const* timestamp, AUAudioFrameCount frameCount, AURenderEvent const* events)
{
    auto now = AUEventSampleTime(timestamp->mSampleTime);
    auto framesRemaining = frameCount;

    // Process events and samples together. First process samples up to an event time and then do the event to update
    // render parameters. Continue until all frames (samples) are rendered.
    while (framesRemaining > 0) {
        if (events == nullptr) {
            renderFrames(framesRemaining, frameCount - framesRemaining);
            return;
        }

        auto framesThisSegment = AUAudioFrameCount(std::max(events->head.eventSampleTime - now, AUEventSampleTime(0)));
        if (framesThisSegment > 0) {
            renderFrames(framesThisSegment, frameCount - framesRemaining);
            framesRemaining -= framesThisSegment;
            now += AUEventSampleTime(framesThisSegment);
        }

        events = renderEventsUntil(now, events);
    }
}
