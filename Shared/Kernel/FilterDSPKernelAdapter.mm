// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#include <Accelerate/Accelerate.h>

#import "FilterDSPKernel.hpp"
#import "FilterDSPKernelAdapter.h"

@implementation FilterDSPKernelAdapter {
    os_log_t logger_;
    FilterDSPKernel kernel_;
}

- (instancetype)init {
    if (self = [super init]) {
        logger_ = os_log_create("LPF", "FilterDSPKernelAdapter");
    }
    return self;
}

- (void)startProcessing:(AVAudioFormat*)inputFormat output:(AVAudioFormat*)outputFormat
     maxFramesToRender:(AUAudioFrameCount)maxFramesToRender {
    kernel_.startProcessing(inputFormat, outputFormat.channelCount, maxFramesToRender);
}

- (void)stopProcessing {
    kernel_.stopProcessing();
}

- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger)count output:(nonnull float*)output {

    // Create temporary filter here since the one in the FilterDSPKernel is used by the music render thread and it may
    // not have the most recent filter settings due to ramping or other latencies.
    BiquadFilter filter;
    filter.calculateParams(kernel_.cutoff(), kernel_.resonance(), kernel_.nyquistPeriod(), 1);
    filter.magnitudes(frequencies, count, kernel_.nyquistPeriod(), output);
}

- (void)set:(AUParameter *)parameter value:(AUValue)value { kernel_.setParameterValue(parameter.address, value); }

- (AUValue)get:(AUParameter *)parameter { return kernel_.getParameterValue(parameter.address); }

- (AUAudioUnitStatus) process:(AudioTimeStamp*)timestamp
                   frameCount:(UInt32)frameCount
                       output:(AudioBufferList*)output
                       events:(AURenderEvent*)realtimeEventListHead
               pullInputBlock:(AURenderPullInputBlock)pullInputBlock
{
    os_log_with_type(logger_, OS_LOG_TYPE_DEBUG, "process:frameCount - frameCount: %d", frameCount);
    auto inputBus = 0;
    return kernel_.processAndRender(timestamp, frameCount, inputBus, output, realtimeEventListHead, pullInputBlock);
}

@end
