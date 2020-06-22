// Copyright © 2020 Brad Howes. All rights reserved.

#import <AudioToolbox/AudioToolbox.h>

@class AUv3FilterDemoViewController;

/**
 Address definitions for AUParameter settings. Available in Swift as `FilterParameterAddress.*`
 */
typedef NS_ENUM(AUParameterAddress, FilterParameterAddress) {
    FilterParameterAddressCutoff = 1,
    FilterParameterAddressResonance = 2
};

/**
 Small Obj-C wrapper around the FilterDSPKernel C++ class.
 */
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
