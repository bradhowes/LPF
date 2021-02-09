// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#pragma once

#import <algorithm>
#import <AudioToolbox/AudioToolbox.h>

#include "InputBuffer.hpp"

/**
 Base template class for DSP kernels that provides common functionality. It properly interleaves render events with
 parameter updates. It is expected that the template parameter defines the following methods which this class will
 invoke at the appropriate times but without any virtual dispatching.

 - doParameterEvent
 - doMIDIEvent
 - doRenderFrames

 */
template <typename T> class KernelEventProcessor {
public:

    KernelEventProcessor(os_log_t logger) : logger_{logger} {}

    void setFormat(AVAudioFormat* format, AVAudioChannelCount channelCount, AUAudioFrameCount maxFramesToRender) {
        inputBuffer_.setFormat(format, channelCount, maxFramesToRender);
    }

    void setBypass(bool bypass) { bypassed_ = bypass; }

    bool isBypassed() { return bypassed_; }

    AUAudioUnitStatus processAndRender(AudioTimeStamp* timestamp, UInt32 frameCount, NSInteger inputBusNumber,
                                       AudioBufferList* output, AURenderEvent* realtimeEventListHead,
                                       AURenderPullInputBlock pullInputBlock) {
        // Pull samples from upstream node and place in our internal buffer
        AudioUnitRenderActionFlags actionFlags = 0;
        auto status = inputBuffer_.pullInput(&actionFlags, timestamp, frameCount, inputBusNumber, pullInputBlock);
        if (status != noErr) {
            os_log_with_type(logger_, OS_LOG_TYPE_ERROR, "failed pullInput - %d", status);
            return status;
        }

        // If performing in-place operation, set output to use input buffers
        auto inPlace = output->mBuffers[0].mData == nullptr;
        if (inPlace) {
            AudioBufferList* input = inputBuffer_.mutableAudioBufferList();
            for (auto i = 0; i < output->mNumberBuffers; ++i) {
                output->mBuffers[i].mData = input->mBuffers[i].mData;
            }
        }

        setBuffers(inputBuffer_.audioBufferList(), output);
        render(timestamp, frameCount, realtimeEventListHead);

        return noErr;
    }
    
    bool isProcessingInPlace() const {
        return inputs_ && outputs_ && inputs_->mBuffers[0].mData == outputs_->mBuffers[0].mData;
    }

    /**
     Perform sample rendering. NOTE: the lack of any input/output buffers here. Everything is expected to be managed
     by the injected T class instance. There can be multiple calls to the T::doRenderFrames method from this one
     depending on the presence of any AURenderEvent objects.s

     @param timestamp the times of events being rendered
     @param frameCount the number of frames (samples) to render
     @param events collection of events to process during this render cycle
     */
    void render(AudioTimeStamp const* timestamp, AUAudioFrameCount frameCount, AURenderEvent const* events) {
        os_log_with_type(logger_, OS_LOG_TYPE_INFO, "render - frameCount: %d", frameCount);

        auto zero = AUEventSampleTime(0);
        auto now = AUEventSampleTime(timestamp->mSampleTime);
        auto framesRemaining = frameCount;

        // Process events and samples together. First process samples up to an event time and then do the event to
        // update render parameters. Continue until all frames (samples) are rendered.
        while (framesRemaining > 0) {
            if (events == nullptr) {
                renderFrames(framesRemaining, frameCount - framesRemaining);
                return;
            }

            auto framesThisSegment = AUAudioFrameCount(std::max(events->head.eventSampleTime - now, zero));
            if (framesThisSegment > 0) {
                renderFrames(framesThisSegment, frameCount - framesRemaining);
                framesRemaining -= framesThisSegment;
                now += AUEventSampleTime(framesThisSegment);
            }

            events = renderEventsUntil(now, events);
        }
    }

protected:
    os_log_t logger_;

private:

    T* injected() { return static_cast<T*>(this); }

    void setBuffers(AudioBufferList const* inputs, AudioBufferList* outputs) {
        os_log_with_type(logger_, OS_LOG_TYPE_INFO, "setBuffers");
        assert(inputs->mNumberBuffers == outputs->mNumberBuffers);
        if (inputs == inputs_ && outputs_ == outputs) return;
        inputs_ = inputs;
        outputs_ = outputs;
        ins_.clear();
        outs_.clear();
        for (size_t channel = 0; channel < inputs_->mNumberBuffers; ++channel) {
            ins_.emplace_back(static_cast<float*>(inputs_->mBuffers[channel].mData));
            outs_.emplace_back(static_cast<float*>(outputs_->mBuffers[channel].mData));
        }
    }

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

    void renderFrames(AUAudioFrameCount frameCount, AUAudioFrameCount processedFrameCount) {
        os_log_with_type(logger_, OS_LOG_TYPE_INFO, "renderFrames - frameCount: %d processed: %d", frameCount,
                         processedFrameCount);
        if (isBypassed()) {
            for (size_t channel = 0; channel < inputs_->mNumberBuffers; ++channel) {
                if (inputs_->mBuffers[channel].mData == outputs_->mBuffers[channel].mData) {
                    continue;
                }

                auto in = (float*)inputs_->mBuffers[channel].mData + processedFrameCount;
                auto out = (float*)outputs_->mBuffers[channel].mData + processedFrameCount;
                memcpy(out, in, frameCount);
                outputs_->mBuffers[channel].mDataByteSize = sizeof(float) * (processedFrameCount + frameCount);
            }
            return;
        }

        for (size_t channel = 0; channel < inputs_->mNumberBuffers; ++channel) {
            ins_[channel] = static_cast<float*>(inputs_->mBuffers[channel].mData) + processedFrameCount;
            outs_[channel] = static_cast<float*>(outputs_->mBuffers[channel].mData) + processedFrameCount;
            outputs_->mBuffers[channel].mDataByteSize = sizeof(float) * (processedFrameCount + frameCount);
        }

        injected()->doRenderFrames(ins_, outs_, frameCount);
    }

    InputBuffer inputBuffer_;

    AudioBufferList const* inputs_ = nullptr;
    AudioBufferList* outputs_ = nullptr;

    std::vector<float const*> ins_;
    std::vector<float*> outs_;

    bool bypassed_ = false;
};
