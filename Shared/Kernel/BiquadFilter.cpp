// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

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

    if (setup_ != nullptr && numChannels == lastNumChannels_) {
        vDSP_biquadm_SetTargetsDouble(setup_, F_.data(), updateRate_, threshold_, 0, 0, 1, numChannels);
    }
    else {
        if (setup_ != nullptr) vDSP_biquadm_DestroySetup(setup_);
        setup_ = vDSP_biquadm_CreateSetup(F_.data(), 1, numChannels);
    }

    lastFrequency_ = frequency;
    lastResonance_ = resonance;
    lastNumChannels_ = numChannels;
}

void
BiquadFilter::magnitudes(float const* frequencies, size_t count, float inverseNyquist, float* magnitudes) const
{
    while (count-- > 0) {
        double theta = M_PI * *frequencies++ * inverseNyquist;
        double zReal = cos(theta);
        double zImaginary = sin(theta);

        double numeratorReal = F_[B0] * (squared(zReal) - squared(zImaginary)) + F_[B1] * zReal + F_[B2];
        double numeratorImaginary = 2.0 * F_[B0] * zReal * zImaginary + F_[B1] * zImaginary;
        double numeratorMagnitude = sqrt(squared(numeratorReal) + squared(numeratorImaginary));

        double denominatorReal = squared(zReal) - squared(zImaginary) + F_[A1] * zReal + F_[A2];
        double denominatorImaginary = 2.0 * zReal * zImaginary + F_[A1] * zImaginary;

        double denominatorMagnitude = sqrt(squared(denominatorReal) + squared(denominatorImaginary));

        *magnitudes++ = numeratorMagnitude / denominatorMagnitude;
    }
}
