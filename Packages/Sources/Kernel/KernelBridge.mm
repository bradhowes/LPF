// Copyright © 2022 Brad Howes. All rights reserved.

#import <CoreAudioKit/CoreAudioKit.h>

#import "C++/AcceleratedBiquadFilter.hpp"
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

- (void)setRenderingFormat:(NSInteger)busCount format:(AVAudioFormat*)inputFormat
         maxFramesToRender:(AUAudioFrameCount)maxFrames {
  kernel_->setRenderingFormat(busCount, inputFormat, maxFrames);
}

- (void)deallocateRenderResources { kernel_->deallocateRenderResources(); }

- (AUInternalRenderBlock)internalRenderBlock {
  __block auto kernel = kernel_;
  return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* flags, const AudioTimeStamp* timestamp,
                            AUAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList* output,
                            const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
    return kernel->processAndRender(timestamp, frameCount, outputBusNumber, output, realtimeEventListHead, pullInputBlock);
  };
}

- (void)setBypass:(BOOL)state { kernel_->setBypass(state); }

- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger)count output:(nonnull float*)output {
  AcceleratedBiquadFilter filter;
  filter.calculateParams(kernel_->cutoff(), kernel_->resonance(), kernel_->nyquistPeriod(), 1);
  filter.magnitudes(frequencies, count, kernel_->nyquistPeriod(), output);
}

- (AUImplementorValueObserver)parameterValueObserverBlock {
  return ^(AUParameter* parameter, AUValue value) {
    kernel_->setParameterValue(parameter.address, value, 0);
  };
}

- (AUImplementorValueProvider)parameterValueProviderBlock {
  return ^AUValue(AUParameter* parameter) {
    return kernel_->getParameterValue(parameter.address);
  };
}

@end
