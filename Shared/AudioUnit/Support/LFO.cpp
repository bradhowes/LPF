// Copyright © 2020 Apple. All rights reserved.

#include <cmath>

#include "LFO.hpp"

LFO::LFO(WaveGenerator const& generator)
: reference_(), samples_(nullptr), size_(generator.sampleCount()), phase_{0.0}, increment_{0.0}
{
    assert(size_ > 0);

    // Fill the table with samples
    auto samples = new std::vector<float>(size_, 0.0);
    auto gen = generator.generator();
    for (int index = 0; index < size_; ++index) (*samples)[index] = gen(index);

    // We keep a reference to the vector and make it available for sharing. We also keep a pointer to the first element
    // and the size so we don't have to dereference the shared pointer in the audio thread. This is safe as long as
    // we treat the samples vector as read-only.
    reference_.reset(samples);
    samples_ = samples->data();
}

void LFO::start(float sampleFrequency, float oscillatorFrequency)
{
    assert(sampleFrequency > 0.0 && oscillatorFrequency > 0.0);
    increment_ = size_ * oscillatorFrequency / sampleFrequency;
}

float LFO::tick()
{
    auto index1 = int(::floor(phase_));
    auto index2 = index1 + 1;
    if (index2 == size_) index2 = 0;

    auto weight = phase_ - index1;
    phase_ += increment_;
    if (phase_ >= size_) phase_ -= size_;

    return (1.0 - weight) * samples_[index1] + weight * samples_[index2];
}
