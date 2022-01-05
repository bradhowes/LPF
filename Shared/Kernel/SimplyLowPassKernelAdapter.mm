// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#import "BiquadFilter.h"
#import "SimplyLowPassKernel.h"
#import "SimplyLowPassKernelAdapter.h"

@implementation SimplyLowPassKernelAdapter {
  SimplyLowPassKernel* kernel_;
  AUAudioFrameCount _maxFramesToRender;
}

- (instancetype)init:(NSString*)appExtensionName {
  if (self = [super init]) {
    self->kernel_ = new SimplyLowPassKernel(std::string(appExtensionName.UTF8String));
  }
  return self;
}

- (void)startProcessing:(AVAudioFormat*)inputFormat maxFramesToRender:(AUAudioFrameCount)maxFramesToRender {
  _maxFramesToRender = maxFramesToRender;
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

- (void)setBypass:(BOOL)state {
  kernel_->setBypass(state);
}

- (AUInternalRenderBlock)internalRenderBlock {

  // Some code I've seen uses `__block` attributes for values copied to the block/stack. I don't see the need for them
  // when the values are read-only.
  //
  auto& kernel{*kernel_};
  AUAudioFrameCount maxFramesToRender = _maxFramesToRender;

  return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* actionFlags, const AudioTimeStamp* timestamp,
                            AUAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList* outputData,
                            const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {

    if (outputBusNumber != 0) return kAudioUnitErr_InvalidPropertyValue;
    if (frameCount > maxFramesToRender) return kAudioUnitErr_TooManyFramesToProcess;
    if (pullInputBlock == nullptr) return kAudioUnitErr_NoConnection;

    auto inputBus = 0;
    return kernel.processAndRender(timestamp, frameCount, inputBus, outputData, realtimeEventListHead, pullInputBlock);
  };
}

@end
