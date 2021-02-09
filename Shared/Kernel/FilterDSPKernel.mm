// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#import <os/log.h>

#include "FilterDSPKernel.hpp"
#include "FilterDSPKernelAdapter.hpp"

FilterDSPKernel::FilterDSPKernel()
: KernelEventProcessor(os_log_create("LPF", "FilterDSPKernel")), cutoff_{float(400.0)}, resonance_{20.0}
{
    filter_.calculateParams(cutoff_, resonance_, nyquistPeriod_, 2);
}

void
FilterDSPKernel::startProcessing(AVAudioFormat* format, AVAudioChannelCount channelCount,
                                 AUAudioFrameCount maxFramesToRender)
{
    os_log_with_type(logger_, OS_LOG_TYPE_INFO, "setFormat: sampleRate: %f channelCount: %d", format.sampleRate,
                     format.channelCount);
    KernelEventProcessor::startProcessing(format, channelCount, maxFramesToRender);
    
    sampleRate_ = format.sampleRate;
    nyquistPeriod_ = 2.0 / sampleRate_;
    reset();
}

void
FilterDSPKernel::reset() {
    filter_.calculateParams(cutoff_, resonance_, nyquistPeriod_, 2);
}

void
FilterDSPKernel::doParameterEvent(AUParameterEvent const& event)
{
    setParameterValue(event.parameterAddress, event.value);
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
            os_log_with_type(logger_, OS_LOG_TYPE_INFO, "get cutoff: %f", cutoff_);
            return cutoff_;

        case FilterParameterAddressResonance:
            os_log_with_type(logger_, OS_LOG_TYPE_INFO, "get resonance: %f", resonance_);
            return resonance_;

        default: return 0.0;
    }
}

void
FilterDSPKernel::doRenderFrames(std::vector<float const*> const& ins, std::vector<float*>& outs,
                                AUAudioFrameCount frameCount)
{
    assert(ins.size() == outs.size() && ins.size() > 0);
    os_log_with_type(logger_, OS_LOG_TYPE_DEBUG, "doRenderFrames: %d", frameCount);
    filter_.calculateParams(cutoff_, resonance_, nyquistPeriod_, ins.size());
    filter_.apply(ins, outs, frameCount);
}
