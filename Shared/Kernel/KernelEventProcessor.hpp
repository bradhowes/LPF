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

    /**
     Construct new instance.

     @param logger the log identifier to use for our logging statements
     */
    KernelEventProcessor(os_log_t logger) : logger_{logger} {}

    /**
     Begin processing with the given format and channel count.

     @param format the sample format to expect
     @param channelCount the number of channels to expect on input
     @param maxFramesToRender the maximum number of frames to expect on input
     */
    void startProcessing(AVAudioFormat* format, AVAudioChannelCount channelCount, AUAudioFrameCount maxFramesToRender) {
        inputBuffer_.setFormat(format, channelCount, maxFramesToRender);
    }

    /**
     Stop processing. Free up any resources that were used during rendering.
     */
    void stopProcessing() { inputBuffer_.reset(); }

    /**
     Set the bypass mode

     @param bypass if true disable filter processing and just copy samples from input to output
     */
    void setBypass(bool bypass) { bypassed_ = bypass; }

    /**
     Get current bypass mode
     */
    bool isBypassed() { return bypassed_; }

    /**
     Process events and render a given number of frames. Events and rendering are interleaved if necessary so that
     event times align with samples.

     @param timestamp the timestamp of the first sample or the first event
     @param frameCount the number of frames to process
     @param inputBusNumber the bus to pull samples from
     @param output the buffer to hold the rendered samples
     @param realtimeEventListHead pointer to the first AURenderEvent (may be null)
     @param pullInputBlock the closure to call to obtain upstream samples
     */
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
        clearBuffers();

        return noErr;
    }

    /**
     Perform sample rendering using samples found in the internal input buffer.

     @param timestamp the times of events being rendered
     @param frameCount the number of frames (samples) to render
     @param events collection of events to process during this render cycle
     */
    void render(AudioTimeStamp const* timestamp, AUAudioFrameCount frameCount, AURenderEvent const* events) {
        os_log_with_type(logger_, OS_LOG_TYPE_INFO, "render - frameCount: %d", frameCount);

        auto zero = AUEventSampleTime(0);
        auto now = AUEventSampleTime(timestamp->mSampleTime);
        auto framesRemaining = frameCount;

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

    void clearBuffers() {
        inputs_ = nullptr;
        outputs_ = nullptr;
        ins_.clear();
        outs_.clear();
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
