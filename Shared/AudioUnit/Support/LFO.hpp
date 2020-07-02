// Copyright © 2020 Apple. All rights reserved.

#pragma once

#include <memory>
#include <vector>

class WaveGenerator {
public:
    WaveGenerator(size_t sampleCount) : sampleCount_{sampleCount} {}

    virtual std::function<float (int)> generator() const = 0;

    size_t sampleCount() const { return sampleCount_; }

protected:
    size_t sampleCount_;
};

class SineWaveGenerator : public WaveGenerator {
public:
    SineWaveGenerator(size_t sampleCount) : WaveGenerator(sampleCount) {}

    std::function<float (int)> generator() const {
        float theta = 2.0 * M_PI / sampleCount_;
        return [theta](int index) { return ::sin(theta * index); };
    }
};

class TriangleWaveGenerator : public WaveGenerator {
public:
    TriangleWaveGenerator(size_t sampleCount) : WaveGenerator(sampleCount) {}

    std::function<float (int)> generator() const {
        auto theta = 2.0 * M_PI / sampleCount();
        return [theta](int index) { return 2.0 / M_PI * asin(sin(theta * index)); };
    }
};

class SquareWaveGenerator : public WaveGenerator {
public:
    static int sgn(float val) { return (0.0 < val) - (val < 0.0); }

    SquareWaveGenerator(size_t sampleCount) : WaveGenerator{sampleCount} {}

    std::function<float (int)> generator() const {
        auto half = sampleCount() / 2.0;
        return [half](int index) { return index < half ? 1.0 : -1.0; };
    }
};

class SawtoothWaveGenerator : public WaveGenerator {
public:
    SawtoothWaveGenerator(size_t sampleCount) : WaveGenerator(sampleCount) {}

    std::function<float (int)> generator() const {
        float limit = sampleCount() / 2.0;
        return [limit](int index) { return index < limit ? index / limit :  index / limit - 2.0; };
    }
};


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
