//

#pragma once

#import <atomic>
#import <AudioToolbox/AudioToolbox.h>
// #import <libkern/OSAtomic.h>

#import "NonCopyable.hpp"

template <typename T>
class ParameterRamper : NonCopyable {
public:

    /**
     Construct new parameter ramp with an initial value.

     @param value the initial value of the parameter
     */
    ParameterRamper(T value)
    : changeCounter_(0)
    {
        setImmediate(value);
    }

    /**
     Reset the parameter to a known counter state.
     */
    void reset() {
        setImmediate(pendingValue_);
        changeCounter_ = 0;
        lastUpdateCounter_ = 0;
    }

    /**
     Set a new value for the parameter.

     @param value the new value to use
     */
    void setValue(T value) {
        pendingValue_ = value;
        std::atomic_fetch_add(&changeCounter_, 1);
    }

    /**
     Set a new value for the parameter, and begin ramping.

     @param value the new value to use
     @param duration number of samples over which to transition to the new value
     */
    void setValue(T value, AUAudioFrameCount duration) {
        setValue(value);
        startRamping(duration);
    }

    /**
     Get the last value set for the parameter.

     @return last value set
     */
    T getValue() const { return pendingValue_; }

    /**
     Begin ramping values from current value to pending one over the given duration.

     NOTE: this should be run only in the audio thread

     @param duration how many samples to transition to new value
     @returns true if ramping to new value
     */
    bool startRamping(AUAudioFrameCount duration)
    {
        int32_t changeCounterValue = changeCounter_;
        if (lastUpdateCounter_ != changeCounterValue) {
            lastUpdateCounter_ = changeCounterValue;
            startRamp(duration);
        }
        return samplesRemaining_ != 0;
    }

    bool isRamping() const { return samplesRemaining_ != 0; }

    /**
     Move along the ramp.
     */
    void step()
    {
        if (samplesRemaining_ != 0) --samplesRemaining_;
    }

    /**
     Obtain the current ramped value and move along the ramp.

     @return current ramped value
     */
    T getAndStep()
    {
        if (samplesRemaining_ == 0) return pendingValue_;
        T value = getCurrent();
        --samplesRemaining_;
        return value;
    }

    /**
     Move along the ramp multiple times.

     @param frameCount number of times to move
     */
    void stepBy(AUAudioFrameCount frameCount)
    {
        if (frameCount >= samplesRemaining_) {
            samplesRemaining_ = 0;
        }
        else {
            samplesRemaining_ -= frameCount;
        }
    }

    /**
     Get the current 'ramped' value. If no more samples remaining, then this will return the last set value.
     */
    T getCurrent() const { return slope_ * T(samplesRemaining_) + offset_; }

private:

    // T clamp(T value) { return std::min(maxValue_, std::max(minValue_, value)); }

    void setImmediate(T value) {
        offset_ = pendingValue_ = value;
        slope_ = 0.0;
        samplesRemaining_ = 0;
    }

    void startRamp(AUAudioFrameCount duration) {
        if (duration == 0) {
            setImmediate(pendingValue_);
        }
        else {
            slope_ = (getCurrent() - pendingValue_) / T(duration);
            samplesRemaining_ = duration;
            offset_ = pendingValue_;
        }
    }

    T pendingValue_ = 0.0;
    T slope_ = 0.0;
    T offset_ = 0.0;
    AUAudioFrameCount samplesRemaining_ = 0;
    int32_t lastUpdateCounter_ = 0;
    std::atomic<int32_t> changeCounter_;
};
