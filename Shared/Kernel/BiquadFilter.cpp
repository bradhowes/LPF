// Copyright © 2020 Brad Howes. All rights reserved.

#include <Accelerate/../Frameworks/vecLib.framework/Headers/vForce.h>

#include "BiquadFilter.hpp"

void
BiquadFilter::calculateParams(float frequency, float resonance, float nyquistPeriod, size_t numChannels)
{
    if (lastFrequency_ == frequency && lastResonance_ == resonance && numChannels == lastNumChannels_) return;

    const double frequencyRads = M_PI * frequency * nyquistPeriod;
    const double r = ::powf(10.0, 0.05 * -resonance);
    const double k  = 0.5 * r * ::sinf(frequencyRads);
    const double c1 = (1.0 - k) / (1.0 + k);
    const double c2 = (1.0 + c1) * ::cosf(frequencyRads);
    const double c3 = (1.0 + c1 - c2) * 0.25;

    F_.clear();
    F_.reserve(5 * numChannels);

    for (auto channel = 0; channel < numChannels; ++channel) {
        F_.push_back(c3);
        F_.push_back(c3 + c3);
        F_.push_back(c3);
        F_.push_back(-c2);
        F_.push_back(c1);
    }

    // As long as we have the same number of channels, we can use Accelerate's function to update the filter.
    if (setup_ != nullptr && numChannels == lastNumChannels_) {
        vDSP_biquadm_SetTargetsDouble(setup_, F_.data(), updateRate_, threshold_, 0, 0, 1, numChannels);
    }
    else {
        // Otherwise, we need to deallocate and create new storage for the filter definition. NOTE: this should never
        // be done from within the audio render thread.
        if (setup_ != nullptr) vDSP_biquadm_DestroySetup(setup_);
        setup_ = vDSP_biquadm_CreateSetup(F_.data(), 1, numChannels);
    }

    lastFrequency_ = frequency;
    lastResonance_ = resonance;
    lastNumChannels_ = numChannels;
}

/**
 Convert "bad" values (NaNs, very small, and very large values to 1.0. This is not mandatory, but it will remove the
 pesky warnings from CoreGraphics when they appear in the Bezier path. Set CG_NUMERICS_SHOW_BACKTRACE to
 "YES" in the Run scheme to see where they happen.

 - parameter x: value to check
 - returns: filtered value or 1.0
 */
static inline float filterBadValues(float x) { return ::fabs(x) > 1e-15 && ::fabs(x) < 1e15 && x != 0.0 ? x : 1.0; }

static inline float squared(float x) { return x * x; }

void
BiquadFilter::magnitudes(float const* frequencies, size_t count, float inverseNyquist, float* magnitudes) const
{
    float scale = M_PI * inverseNyquist;
    while (count-- > 0) {
        float theta = scale * *frequencies++;
        float zReal = ::cosf(theta);
        float zImag = ::sinf(theta);

        float zReal2 = squared(zReal);
        float zImag2 = squared(zImag);
        float numerReal = F_[B0] * (zReal2 - zImag2) + F_[B1] * zReal + F_[B2];
        float numerImag = 2.0 * F_[B0] * zReal * zImag + F_[B1] * zImag;
        float numerMag = ::sqrt(squared(numerReal) + squared(numerImag));

        float denomReal = zReal2 - zImag2 + F_[A1] * zReal + F_[A2];
        float denomImag = 2.0 * zReal * zImag + F_[A1] * zImag;
        float denomMag = ::sqrt(squared(denomReal) + squared(denomImag));

        float value = numerMag / denomMag;

        *magnitudes++ = 20.0 * ::log10(filterBadValues(value));
    }
}

