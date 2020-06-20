/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Adapter object providing a Swift-accessible interface to the filter's underlying DSP code.
*/

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

// - (NSArray<NSNumber *> *)magnitudesForFrequencies:(NSArray<NSNumber *> *)frequencies;

@end
