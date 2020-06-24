// Copyright © 2020 Brad Howes. All rights reserved.

#pragma once

#include <Accelerate/Accelerate.h>

#include <cmath>
#include <vector>

class BiquadFilter {
public:
    enum Index { B0 = 0, B1, B2, A1, A2 };

    void calculateParams(double frequency, double resonance, size_t numChannels);

    void magnitudes(float const* frequencies, size_t count, float inverseNyquist, float* magnitudes) const;

    void apply(std::vector<float const*> const& ins, std::vector<float*>& outs, size_t frameCount) const
    {
        vDSP_biquadm(setup_,
                     (float const* __nonnull* __nonnull)ins.data(), vDSP_Stride(1),
                     (float * __nonnull * __nonnull)outs.data(), vDSP_Stride(1),
                     vDSP_Length(frameCount));
    }

private:
    static double squared(double x) { return x * x; }

    std::vector<double> F_;
    vDSP_biquadm_Setup setup_ = nullptr;

    double lastFrequency_ = -1.0;
    double lastResonance_ = 1E10;
    size_t lastNumChannels_ = 0;

    float threshold_ = 0.05;
    float updateRate_ = 0.4;
};

