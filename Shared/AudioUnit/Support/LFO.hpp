// Copyright © 2020 Apple. All rights reserved.

#pragma once

#include <memory>
#include <vector>

class WaveGenerator;

/**
 Low-frequency oscillator that uses a simple table lookup of sin values plus linear interpolation to provide output
 samples. Supports sharing of lookup tables via copying and assignment operators, with independent internal phoase
 state.
 */
class LFO
{
public:

    /**
     Create a new LFO that will use a lookup table with the given size.

     @param waveGenerator the source of sample to use to fill the lookup table
     */
    LFO(WaveGenerator const& waveGenerator);

    /**
     Initialize the oscillator to run at a given frequency and to emit samples at a given sample rate.
     */
    void start(float sampleFrequency, float oscillatorFrequency);

    /**
     Obtain the next sample from the oscillator.

     @returns next sample
     */
    float tick();

    /**
     Reset the internal state of the oscillator.
     */
    void reset() { phase_ = 0.0; }

private:
    std::shared_ptr<const std::vector<float>> reference_;
    float const* samples_;
    size_t size_;
    float phase_;
    float increment_;
};
