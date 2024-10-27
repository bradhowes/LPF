// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Small Obj-C bridge between Swift and the C++ kernel classes. The `Bridge` package contains the actual adoption of the
 `AUParameterHandler` and `AudioRenderer` protocols.
 */
@interface KernelBridge : NSObject

- (nonnull id)init:(NSString*)appExtensionName;

@end

// These are the functions that satisfy the AudioRenderer protocol
@interface KernelBridge (AudioRenderer)

/**
 Configure the kernel for new format and max frame in preparation to begin rendering

 @param busCount number of busses the kernel must support
 @param inputFormat the current format of the input bus
 @param maxFramesToRender the max frames to expect in a render request
 */
- (void)setRenderingFormat:(NSInteger)busCount format:(AVAudioFormat*)inputFormat
         maxFramesToRender:(AUAudioFrameCount)maxFrames;

/**
 Stop processing, releasing any resources used to support rendering.
 */
- (void)deallocateRenderResources;

/**
 Obtain a block to use for rendering with the kernel.

 @returns AUInternalRenderBlock instance
 */
- (AUInternalRenderBlock)internalRenderBlock;

/**
 Set the bypass state.

 @param state new bypass value
 */
- (void)setBypass:(BOOL)state;

/**
 Request by the ViewController to fetch the frequency responses of the low-pass filter.

 @param frequencies C array of frequencies to use
 @param count the number of frequencies in the C array
 @param output pointer to C array that can hold `count` samples
 */
- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger)count output:(nonnull float*)output;

@end

// These are the functions that satisfy the AUParameterHandler protocol
@interface KernelBridge (AUParameterHandler)

- (AUImplementorValueObserver)parameterValueObserverBlock;

- (AUImplementorValueProvider)parameterValueProviderBlock;

@end

NS_ASSUME_NONNULL_END
