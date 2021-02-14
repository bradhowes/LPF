// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#import "BiquadFilter.h"
#import "FilterDSPKernel.h"
#import "FilterDSPKernelAdapter.h"

@implementation FilterDSPKernelAdapter {
    FilterDSPKernel* kernel_;
}

- (instancetype)init:(NSString*)appExtensionName {
    if (self = [super init]) {
        self->kernel_ = new FilterDSPKernel(std::string(appExtensionName.UTF8String));
    }
    return self;
}

- (void)startProcessing:(AVAudioFormat*)inputFormat maxFramesToRender:(AUAudioFrameCount)maxFramesToRender {
    kernel_->startProcessing(inputFormat, maxFramesToRender);
}

- (void)stopProcessing {
    kernel_->stopProcessing();
}

- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger)count output:(nonnull float*)output {

    BiquadFilter filter;
    filter.calculateParams(kernel_->cutoff(), kernel_->resonance(), kernel_->nyquistPeriod(), 1);
    filter.magnitudes(frequencies, count, kernel_->nyquistPeriod(), output);
}

- (void)set:(AUParameter *)parameter value:(AUValue)value { kernel_->setParameterValue(parameter.address, value); }

- (AUValue)get:(AUParameter *)parameter { return kernel_->getParameterValue(parameter.address); }

- (AUAudioUnitStatus) process:(AudioTimeStamp*)timestamp
                   frameCount:(UInt32)frameCount
                       output:(AudioBufferList*)output
                       events:(AURenderEvent*)realtimeEventListHead
               pullInputBlock:(AURenderPullInputBlock)pullInputBlock
{
    auto inputBus = 0;
    return kernel_->processAndRender(timestamp, frameCount, inputBus, output, realtimeEventListHead, pullInputBlock);
}

- (void)setBypass:(BOOL)state {
    kernel_->setBypass(state);
}

@end
