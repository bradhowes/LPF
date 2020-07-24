// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#import <os/log.h>

#include "FilterDSPKernel.hpp"
#include "FilterDSPKernelAdapter.hpp"

void
FilterDSPKernel::setFormat(AVAudioFormat* format)
{
    sampleRate_ = format.sampleRate;
    nyquistFrequency_ = 0.5 * sampleRate_;
    nyquistPeriod_ = 1.0 / nyquistFrequency_;
    channelCount_ = format.channelCount;
    reset();
}

void
FilterDSPKernel::reset() {
    cutoff_.reset();
    resonance_.reset();
}

void
FilterDSPKernel::setParameterValue(AUParameterAddress address, AUValue value)
{
    switch (address) {
        case FilterParameterAddressCutoff:
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "set cutoff: %f", value);
            cutoff_ = value;
            break;

        case FilterParameterAddressResonance:
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "set resonance: %f", value);
            resonance_ = value;
            break;
    }
}

AUValue
FilterDSPKernel::getParameterValue(AUParameterAddress address) const
{
    switch (address) {
        case FilterParameterAddressCutoff:
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "get cutoff: %f", cutoff_.value());
            return cutoff_.value();

        case FilterParameterAddressResonance:
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "get resonance: %f", resonance_.value());
            return resonance_.value();

        default: return 0.0;
    }
}

void
FilterDSPKernel::setBuffers(AudioBufferList* inputs, AudioBufferList* outputs)
{
    if (inputs == inputs_ && outputs_ == outputs) return;
    inputs_ = inputs;
    outputs_ = outputs;
    ins_.clear();
    outs_.clear();
    for (size_t channel = 0; channel < channelCount(); ++channel) {
        ins_.emplace_back(static_cast<float*>(inputs_->mBuffers[channel].mData));
        outs_.emplace_back(static_cast<float*>(outputs_->mBuffers[channel].mData));
    }
}

void
FilterDSPKernel::renderFrames(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset)
{
    if (bypassed) {
        for (size_t channel = 0; channel < channelCount(); ++channel) {
            if (inputs_->mBuffers[channel].mData == outputs_->mBuffers[channel].mData) {
                continue;
            }
            for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                int frameOffset = int(frameIndex + bufferOffset);
                auto in = (float*)inputs_->mBuffers[channel].mData  + frameOffset;
                auto out = (float*)outputs_->mBuffers[channel].mData + frameOffset;
                *out = *in;
            }
        }
        return;
    }

    for (size_t channel = 0; channel < channelCount(); ++channel) {
        ins_[channel] = static_cast<float*>(inputs_->mBuffers[channel].mData) + bufferOffset;
        outs_[channel] = static_cast<float*>(outputs_->mBuffers[channel].mData) + bufferOffset;
    }

    // Rely on the filter doing the right thing and only recalculating when needed.
    filter_.calculateParams(cutoff_, resonance_, nyquistPeriod_, channelCount());

    filter_.apply(ins_, outs_, frameCount);
}
