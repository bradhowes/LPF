// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

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

- (void)configureInput:(nonnull AVAudioFormat*)inputFormat output:(nonnull AVAudioFormat*)outputFormat
     maxFramesToRender:(AUAudioFrameCount)maxFramesToRender;

- (AUAudioUnitStatus)process:(nonnull AudioTimeStamp*)timeStamp
                  frameCount:(UInt32)frameCount
                    inputBus:(NSInteger)inputBusNumber
                      output:(nonnull AudioBufferList*)output
                      events:(nullable AURenderEvent*)realtimeEventListHead
              pullInputBlock:(nonnull AURenderPullInputBlock)pullInputBlock;

/**
 Request by the FilterViewController to fetch the frequency responses of the low-pass filter.

 @param frequencies C array of frequencies to use
 @param count the number of frequencies in the C array
 @param output pointer to C array that can hold `count` samples
 */
- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger)count output:(nonnull float*)output;

@end
