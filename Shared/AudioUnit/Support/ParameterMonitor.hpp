//

#pragma once

#import <atomic>
#import <AudioToolbox/AudioToolbox.h>

#import "NonCopyable.hpp"

template <typename T>
class ParameterMonitor : NonCopyable {
public:

    /**
     Construct new parameter ramp with an initial value.

     @param value the initial value of the parameter
     */
    explicit ParameterMonitor(T value) : value_{value}, changeCounter_{0} {}

    /**
     Reset the parameter to a known counter state.
     */
    void reset() {
        changeCounter_ = 0;
        lastUpdateCounter_ = 0;
    }

    /**
     Set a new value for the parameter.

     @param value the new value to use
     */
    ParameterMonitor<T>& operator =(T value) {
        value_ = value;
        std::atomic_fetch_add(&changeCounter_, 1);
        return *this;
    }

    /**
     Get the last value set for the parameter.

     @return last value set
     */
    operator T() const { return value_; }

    bool wasChanged()
    {
        int32_t changeCounterValue = changeCounter_;
        if (lastUpdateCounter_ == changeCounterValue) return false;
        lastUpdateCounter_ = changeCounterValue;
        return true;
    }

private:
    T value_;
    int32_t lastUpdateCounter_ = 0;
    std::atomic<int32_t> changeCounter_;
};
