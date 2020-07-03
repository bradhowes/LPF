// Copyright © 2020 Apple. All rights reserved.

#pragma once

#include <memory>
#include <vector>

/**
 Base class for a generator of samples.
 */
class WaveGenerator {
public:

    /**
     Create new generator.

     @param sampleCount number of samples to generate for one cycle
     */
    WaveGenerator(size_t sampleCount) : sampleCount_{sampleCount} {}

    /**
     Obtain a generator function that creates the sample values.
     Derived classes must implement.

     @returns function that emits samples
     */
    virtual std::function<float (int)> generator() const = 0;

    /**
     @returns The configured sample count.
     */
    size_t sampleCount() const { return sampleCount_; }

protected:
    size_t sampleCount_;
};

/**
 Generate samples for a sine wave.
 */
class SineWaveGenerator : public WaveGenerator {
public:

    /**
     Construct new generator

     @param sampleCount number of samples to generate for one cycle
     */
    SineWaveGenerator(size_t sampleCount) : WaveGenerator(sampleCount) {}

    /**
     Obtain a generator function that creates the sample values.

     @returns function that emits samples
     */
    std::function<float (int)> generator() const {
        float theta = 2.0 * M_PI / sampleCount_;
        return [theta](int index) { return ::sin(theta * index); };
    }
};

/**
 Generate samples for a triangular waveform.
 */
class TriangleWaveGenerator : public WaveGenerator {
public:

    /**
     Construct new generator

     @param sampleCount number of samples to generate for one cycle
     */
    TriangleWaveGenerator(size_t sampleCount) : WaveGenerator(sampleCount) {}

    /**
     Obtain a generator function that creates the sample values.

     @returns function that emits samples
     */
    std::function<float (int)> generator() const {
        auto theta = 2.0 * M_PI / sampleCount();
        return [theta](int index) { return 2.0 / M_PI * asin(sin(theta * index)); };
    }
};

/**
 Generate samples for a square wave
 */
class SquareWaveGenerator : public WaveGenerator {
public:
    static int sgn(float val) { return (0.0 < val) - (val < 0.0); }

    /**
     Construct new generator

     @param sampleCount number of samples to generate for one cycle
     */
    SquareWaveGenerator(size_t sampleCount) : WaveGenerator{sampleCount} {}

    /**
     Obtain a generator function that creates the sample values.

     @returns function that emits samples
     */
    std::function<float (int)> generator() const {
        auto half = sampleCount() / 2.0;
        return [half](int index) { return index < half ? 1.0 : -1.0; };
    }
};

/**
 Generate samples for a sawtooth wave
 */
class SawtoothWaveGenerator : public WaveGenerator {
public:

    /**
     Construct new generator

     @param sampleCount number of samples to generate for one cycle
     */
    SawtoothWaveGenerator(size_t sampleCount) : WaveGenerator(sampleCount) {}

    /**
     Obtain a generator function that creates the sample values.

     @returns function that emits samples
     */
    std::function<float (int)> generator() const {
        float limit = sampleCount() / 2.0;
        return [limit](int index) { return index < limit ? index / limit :  index / limit - 2.0; };
    }
};
