// Copyright © 2020 Brad Howes. All rights reserved.

#import <AudioToolbox/AudioToolbox.h>

@class AUv3FilterDemoViewController;

@interface FilterDSPKernelAdapter : NSObject

@property (nonatomic) AUAudioFrameCount maximumFramesToRender;
@property (nonnull, nonatomic, readonly) AUAudioUnitBus *inputBus;
@property (nonnull, nonatomic, readonly) AUAudioUnitBus *outputBus;

- (void)setParameter:(nonnull AUParameter *)parameter value:(AUValue)value;
- (AUValue)valueOf:(nonnull AUParameter *)parameter;

- (void)allocateRenderResources;
- (void)deallocateRenderResources;

- (nonnull AUInternalRenderBlock)internalRenderBlock;

- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger) count output:(nonnull float*)output;

@end
