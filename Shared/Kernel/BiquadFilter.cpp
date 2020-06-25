// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#include <Accelerate/../Frameworks/vecLib.framework/Headers/vForce.h>

#include "BiquadFilter.hpp"

void
BiquadFilter::calculateParams(double frequency, double resonance, size_t numChannels)
{
    if (lastFrequency_ == frequency && lastResonance_ == resonance && numChannels == lastNumChannels_) return;

    double r = pow(10.0, 0.05 * -resonance);
    double k  = 0.5 * r * sin(M_PI * frequency);
    double c1 = (1.0 - k) / (1.0 + k);
    double c2 = (1.0 + c1) * cos(M_PI * frequency);
    double c3 = (1.0 + c1 - c2) * 0.25;

    F_.clear();
    for (auto channel = 0; channel < numChannels; ++channel) {
        F_.push_back(c3);
        F_.push_back(2.0 * c3);
        F_.push_back(c3);
        F_.push_back(-c2);
        F_.push_back(c1);
    }

    // As long as we have the same number of channels, we can use Accelerate's function to update the filter.
    if (setup_ != nullptr && numChannels == lastNumChannels_) {
        vDSP_biquadm_SetTargetsDouble(setup_, F_.data(), updateRate_, threshold_, 0, 0, 1, numChannels);
    }
    else {
        // Otherwise, we need to deallocate and create new storage for the filter definition.
        if (setup_ != nullptr) vDSP_biquadm_DestroySetup(setup_);
        setup_ = vDSP_biquadm_CreateSetup(F_.data(), 1, numChannels);
    }

    lastFrequency_ = frequency;
    lastResonance_ = resonance;
    lastNumChannels_ = numChannels;
}

/**
 Convert "bad" values (NaNs, very small, and very large values to 1.0. This is not mandatory, but it will get rid
 of the pesky warnings from CoreGraphics when they appear in the Bezier path. Set CG_NUMERICS_SHOW_BACKTRACE to
 "YES" in the Run scheme to see where they happen.

 - parameter x: value to check
 - returns: filtered value or 1.0
 */
static inline float filterBadValues(double x)
{
    float absx = fabs(x);
    if (absx > 1e-15 && absx < 1e15 && x != 0.0) return x;
    return 1.0;
}

void
BiquadFilter::magnitudes(float const* frequencies, size_t count, float inverseNyquist, float* magnitudes) const
{
    double scale = M_PI * inverseNyquist;
    while (count-- > 0) {
        double theta = scale * *frequencies++;
        double zReal = cos(theta);
        double zImag = sin(theta);

        double zReal2 = squared(zReal);
        double zImag2 = squared(zImag);
        double numerReal = F_[B0] * (zReal2 - zImag2) + F_[B1] * zReal + F_[B2];
        double numerImag = 2.0 * F_[B0] * zReal * zImag + F_[B1] * zImag;
        double numerMag = sqrt(squared(numerReal) + squared(numerImag));

        double denomReal = zReal2 - zImag2 + F_[A1] * zReal + F_[A2];
        double denomImag = 2.0 * zReal * zImag + F_[A1] * zImag;
        double denomMag = sqrt(squared(denomReal) + squared(denomImag));

        double value = numerMag / denomMag;

        *magnitudes++ = 20.0 * log10(filterBadValues(value));
    }
}

