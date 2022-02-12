// Copyright © 2022 Brad Howes. All rights reserved.

#import <CoreAudioKit/CoreAudioKit.h>

#import "C++/BiquadFilter.h"
#import "C++/Kernel.hpp"
#import "Kernel.h"

@implementation KernelBridge {
  Kernel* kernel_;
}

- (instancetype)init:(NSString*)appExtensionName {
  if (self = [super init]) {
    self->kernel_ = new Kernel(std::string(appExtensionName.UTF8String));
  }
  return self;
}

- (void)setRenderingFormat:(AVAudioFormat*)inputFormat maxFramesToRender:(AUAudioFrameCount)maxFrames {
  kernel_->setRenderingFormat(inputFormat, maxFrames);
}

- (void)renderingStopped { kernel_->renderingStopped(); }

- (AUInternalRenderBlock)internalRenderBlock {
  auto& kernel = *kernel_;
  NSInteger bus = 0;
  return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* flags, const AudioTimeStamp* timestamp,
                            AUAudioFrameCount frameCount, NSInteger, AudioBufferList* output,
                            const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
    return kernel.processAndRender(timestamp, frameCount, bus, output, realtimeEventListHead, pullInputBlock);
  };
}

- (void)setBypass:(BOOL)state { kernel_->setBypass(state); }

- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger)count output:(nonnull float*)output {
  BiquadFilter filter;
  filter.calculateParams(kernel_->cutoff(), kernel_->resonance(), kernel_->nyquistPeriod(), 1);
  filter.magnitudes(frequencies, count, kernel_->nyquistPeriod(), output);
}

- (void)set:(AUParameter *)parameter value:(AUValue)value { kernel_->setParameterValue(parameter.address, value); }

- (AUValue)get:(AUParameter *)parameter { return kernel_->getParameterValue(parameter.address); }

@end
