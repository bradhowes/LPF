// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#pragma once

#include <Accelerate/Accelerate.h>

#include <cmath>
#include <vector>

/**
 Handles the configuration and use of a bi-quad filter. Uses Accelerate framework for fast vectorized processing of the
 filter on a set of samples.
 */
class BiquadFilter {
public:
    enum Index { B0 = 0, B1, B2, A1, A2 };

    /**
     Calculate the parameters for a low-pass filter with the given frequency and resonance values.

     @param frequency the cutoff frequency for the low-pass filter
     @param resonance the resonance setting for the low-pass filter
     */
    void calculateParams(double frequency, double resonance, size_t numChannels);

    /**
     Calculate the frequency responses for the current filter configuration.

     @param frequencies array of frequency values to calculate on
     @param count the number of frequencies in the array
     @param inverseNyquist equivalent to 1.0 / (0.5 * sampleRate)
     @param magnitudes mutable array of values with the same size as `frequencies` for holding the results
     */
    void magnitudes(float const* frequencies, size_t count, float inverseNyquist, float* magnitudes) const;

    /**
     Apply the filter to a collection of audio samples.

     @param ins the array of samples to process
     @param outs the storage for the filtered results
     @param frameCount the number of samples to process in the sequences
     */
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

