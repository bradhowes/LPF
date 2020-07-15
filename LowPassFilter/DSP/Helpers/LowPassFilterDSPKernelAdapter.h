//
//  LowPassFilterDSPKernelAdapter.h
//  LowPassFilter
//
//  Created by Brad Howes on 7/15/20.
//  Copyright © 2020 Apple. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>

@class AudioUnitViewController;

NS_ASSUME_NONNULL_BEGIN

@interface LowPassFilterDSPKernelAdapter : NSObject

@property (nonatomic) AUAudioFrameCount maximumFramesToRender;
@property (nonatomic, readonly) AUAudioUnitBus *inputBus;
@property (nonatomic, readonly) AUAudioUnitBus *outputBus;

- (void)setParameter:(AUParameter *)parameter value:(AUValue)value;
- (AUValue)valueForParameter:(AUParameter *)parameter;

- (void)allocateRenderResources;
- (void)deallocateRenderResources;
- (AUInternalRenderBlock)internalRenderBlock;

@end

NS_ASSUME_NONNULL_END
