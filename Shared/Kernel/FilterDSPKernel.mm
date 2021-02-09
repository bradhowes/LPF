// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#import <os/log.h>

#include "FilterDSPKernel.hpp"
#include "FilterDSPKernelAdapter.hpp"

FilterDSPKernel::FilterDSPKernel()
: KernelEventProcessor(os_log_create("LPF", "FilterDSPKernel")), cutoff_{float(400.0)}, resonance_{20.0}
{
    filter_.calculateParams(cutoff_.value(), resonance_.value(), nyquistPeriod_, 2);
}

void
FilterDSPKernel::setFormat(AVAudioFormat* format, AVAudioChannelCount channelCount,
                           AUAudioFrameCount maxFramesToRender)
{
    os_log_with_type(logger_, OS_LOG_TYPE_INFO, "setFormat: sampleRate: %f channelCount: %d", format.sampleRate,
                     format.channelCount);
    KernelEventProcessor::setFormat(format, channelCount, maxFramesToRender);
    
    sampleRate_ = format.sampleRate;
    nyquistFrequency_ = 0.5 * sampleRate_;
    nyquistPeriod_ = 1.0 / nyquistFrequency_;
    reset();
}

void
FilterDSPKernel::reset() {
    cutoff_.reset();
    resonance_.reset();
    filter_.calculateParams(cutoff_.value(), resonance_.value(), nyquistPeriod_, 2);
}

void
FilterDSPKernel::setParameterValue(AUParameterAddress address, AUValue value)
{
    switch (address) {
        case FilterParameterAddressCutoff:
            os_log_with_type(logger_, OS_LOG_TYPE_INFO, "set cutoff: %f", value);
            cutoff_ = value;
            break;

        case FilterParameterAddressResonance:
            os_log_with_type(logger_, OS_LOG_TYPE_INFO, "set resonance: %f", value);
            resonance_ = value;
            break;
    }
}

AUValue
FilterDSPKernel::getParameterValue(AUParameterAddress address) const
{
    switch (address) {
        case FilterParameterAddressCutoff:
            os_log_with_type(logger_, OS_LOG_TYPE_INFO, "get cutoff: %f", cutoff_.value());
            return cutoff_.value();

        case FilterParameterAddressResonance:
            os_log_with_type(logger_, OS_LOG_TYPE_INFO, "get resonance: %f", resonance_.value());
            return resonance_.value();

        default: return 0.0;
    }
}

void
FilterDSPKernel::doRenderFrames(std::vector<float const*> const& ins, std::vector<float*>& outs,
                                AUAudioFrameCount frameCount)
{
    assert(ins.size() == outs.size() && ins.size() > 0);
    os_log_with_type(logger_, OS_LOG_TYPE_INFO, "doRenderFrames: %d", frameCount);
    filter_.calculateParams(cutoff_, resonance_, nyquistPeriod_, ins.size());
    filter_.apply(ins, outs, frameCount);
}
