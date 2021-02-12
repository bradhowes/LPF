// Copyright © 2020 Brad Howes. All rights reserved.

#pragma once

#import <AudioToolbox/AudioToolbox.h>

/**
 Protocol that handles AUParameter get and set operations.
 */
@protocol AUParameterHandler

/**
 Set an AUParameter to a new value
 */
 - (void)set:(nonnull AUParameter *)parameter value:(AUValue)value;

/**
 Get the current value of an AUParameter
 */
 - (AUValue)get:(nonnull AUParameter *)parameter;

@end

/**
 Address definitions for AUParameter settings. Available in Swift as `FilterParameterAddress.*`
 */
typedef NS_ENUM(AUParameterAddress, FilterParameterAddress) {
    FilterParameterAddressCutoff = 1,
    FilterParameterAddressResonance = 2
};

/**
 Small Obj-C wrapper around the FilterDSPKernel C++ class. Handles AUParameter get/set requests by forwarding them to
 the kernel.
 */
@interface FilterDSPKernelAdapter : NSObject <AUParameterHandler>

/**
 Configure the kernel for new format and max frame in preparation to begin rendering

 @param inputFormat the current format of the input bus
 @param maxFramesToRender the max frames to expect in a render request
 */
- (void)startProcessing:(nonnull AVAudioFormat*)inputFormat maxFramesToRender:(AUAudioFrameCount)maxFramesToRender;

/**
 Stop processing, releasing any resources used to support rendering.
 */
- (void)stopProcessing;

/**
 Process upstream input

 @param timestamp the timestamp for the rendering
 @param frameCount the number of frames to render
 @param output the buffer to hold the rendered samples
 @param realtimeEventListHead the first AURenderEvent to process (may be null)
 @param pullInputBlock the closure to invoke to fetch upstream samples
 */
- (AUAudioUnitStatus)process:(nonnull AudioTimeStamp*)timestamp
                  frameCount:(UInt32)frameCount
                      output:(nonnull AudioBufferList*)output
                      events:(nullable AURenderEvent*)realtimeEventListHead
              pullInputBlock:(nonnull AURenderPullInputBlock)pullInputBlock;

// - (nonnull AUInternalRenderBlock)internalRenderBlock;

/**
 Request by the FilterViewController to fetch the frequency responses of the low-pass filter.

 @param frequencies C array of frequencies to use
 @param count the number of frequencies in the C array
 @param output pointer to C array that can hold `count` samples
 */
- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger)count output:(nonnull float*)output;

@end
