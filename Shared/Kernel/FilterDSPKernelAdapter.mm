// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#import "BiquadFilter.hpp"
#import "FilterDSPKernel.hpp"
#import "FilterDSPKernelAdapter.h"

@implementation FilterDSPKernelAdapter {
    os_log_t logger_;
    FilterDSPKernel kernel_;
}

- (instancetype)init {
    if (self = [super init]) {
        logger_ = os_log_create("LPF", "FilterDSPKernelAdapter");
    }
    return self;
}

- (void)startProcessing:(AVAudioFormat*)inputFormat maxFramesToRender:(AUAudioFrameCount)maxFramesToRender {
    kernel_.startProcessing(inputFormat, maxFramesToRender);
}

- (void)stopProcessing {
    kernel_.stopProcessing();
}

- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger)count output:(nonnull float*)output {

    // Create temporary filter here since the one in the FilterDSPKernel is used by the music render thread and it may
    // not have the most recent filter settings due to ramping or other latencies.
    BiquadFilter filter;
    filter.calculateParams(kernel_.cutoff(), kernel_.resonance(), kernel_.nyquistPeriod(), 1);
    filter.magnitudes(frequencies, count, kernel_.nyquistPeriod(), output);
}

- (void)set:(AUParameter *)parameter value:(AUValue)value { kernel_.setParameterValue(parameter.address, value); }

- (AUValue)get:(AUParameter *)parameter { return kernel_.getParameterValue(parameter.address); }

- (AUAudioUnitStatus) process:(AudioTimeStamp*)timestamp
                   frameCount:(UInt32)frameCount
                       output:(AudioBufferList*)output
                       events:(AURenderEvent*)realtimeEventListHead
               pullInputBlock:(AURenderPullInputBlock)pullInputBlock
{
    os_log_with_type(logger_, OS_LOG_TYPE_DEBUG, "process:frameCount - frameCount: %d", frameCount);
    auto inputBus = 0;
    return kernel_.processAndRender(timestamp, frameCount, inputBus, output, realtimeEventListHead, pullInputBlock);
}

//- (AUInternalRenderBlock)internalRenderBlock {
//
//    // References to capture for use within the block.
//    FilterDSPKernel& kernel = kernel_;
//    InputBuffer& inputBuffer = kernel.inputBuffer();
//    assert(inputBuffer.mutableAudioBufferList() != nullptr);
//
//    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* actionFlags, const AudioTimeStamp* timestamp,
//                              AVAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList* outputData,
//                              const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
////        if (frameCount > kernel.maximumFramesToRender()) return kAudioUnitErr_TooManyFramesToProcess;
//
//        // Fetch samples from upstream
//        AudioUnitRenderActionFlags pullFlags = 0;
//        AUAudioUnitStatus err = inputBuffer.pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);
//        if (err != 0) return err;
//
//        // Obtain the sample buffers to use for rendering
//        AudioBufferList* inAudioBufferList = inputBuffer.mutableAudioBufferList();
//        AudioBufferList* outAudioBufferList = outputData;
//        if (outAudioBufferList->mBuffers[0].mData == nullptr) {
//
//            // Use the input buffers for the output buffers
//            for (UInt32 index = 0; index < outAudioBufferList->mNumberBuffers; ++index) {
//                outAudioBufferList->mBuffers[index].mData = inAudioBufferList->mBuffers[index].mData;
//            }
//        }
//
//        kernel.setBuffers(inAudioBufferList, outAudioBufferList);
//
//        // Do the rendering
//        kernel.render(timestamp, frameCount, realtimeEventListHead);
//
//        return noErr;
//    };
//}

@end
