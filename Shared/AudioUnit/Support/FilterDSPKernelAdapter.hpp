// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#import <AudioToolbox/AudioToolbox.h>

@class FilterViewController;

/**
 Address definitions for AUParameter settings. Available in Swift as `FilterParameterAddress.*`
 */
typedef NS_ENUM(AUParameterAddress, FilterParameterAddress) {
    FilterParameterAddressCutoff = 1,
    FilterParameterAddressResonance = 2
};

@protocol RuntimeParameterHandler

- (void)setParameter:(nonnull AUParameter *)parameter value:(AUValue)value;
- (AUValue)valueOf:(nonnull AUParameter *)parameter;

@end

/**
 Small Obj-C wrapper around the FilterDSPKernel C++ class.
 */
@interface FilterDSPKernelAdapter : NSObject <RuntimeParameterHandler>

/// Maximum number of frames (samples) to handle in a render call.
@property (nonatomic) AUAudioFrameCount maximumFramesToRender;
/// The input bus to use for fetching samples to process
@property (nonnull, nonatomic, readonly) AUAudioUnitBus *inputBus;
/// The output bus to use for sending filtered samples
@property (nonnull, nonatomic, readonly) AUAudioUnitBus *outputBus;

/**
 Set a runtime parameter to a new value

 @param parameter which parameter to change
 @param value the new value to assign to it
 */
- (void)setParameter:(nonnull AUParameter *)parameter value:(AUValue)value;

/**
 Obtain the current value of a runtime paramater

 @param parameter which parameter to query
 @returns the parameter's value
 */
- (AUValue)valueOf:(nonnull AUParameter *)parameter;

/**
 Request by the audio framework to allocate all necessary resources to handle audio rendering requests.
 */
- (void)allocateRenderResources;

/**
 Notification by the audio framework that no more rendering requests will be received, thus any allocated resources
 for rendering should be released.
 */
- (void)deallocateRenderResources;

/**
 Request by the audio framework to get a render block for processing samples
 */
- (nonnull AUInternalRenderBlock)internalRenderBlock;

/**
 Request by the FilterViewController to fetch the frequency respones of the low-pass filter.

 @param frequencies C array of frequencies to use
 @param count the number of frequencies in the C array
 @param output pointer to C array that can hold `count` samples
 */
- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger)count output:(nonnull float*)output;

@end
