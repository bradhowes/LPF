// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#import <AudioToolbox/AudioToolbox.h>

/**
 Address definitions for AUParameter settings. Available in Swift as `FilterParameterAddress.*`
 */
typedef NS_ENUM(AUParameterAddress, FilterParameterAddress) {
    FilterParameterAddressCutoff = 1,
    FilterParameterAddressResonance = 2
};

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
 Small Obj-C wrapper around the FilterDSPKernel C++ class. Handles AUParameter get/set requests by forwarding them to
 the kernel.
 */
@interface FilterDSPKernelAdapter : NSObject <AUParameterHandler>

/// Maximum number of frames (samples) to handle in a render call.
@property (nonatomic) AUAudioFrameCount maximumFramesToRender;
/// The input bus to use for fetching samples to process
@property (nonnull, nonatomic, readonly) AUAudioUnitBus *inputBus;
/// The output bus to use for sending filtered samples
@property (nonnull, nonatomic, readonly) AUAudioUnitBus *outputBus;

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
