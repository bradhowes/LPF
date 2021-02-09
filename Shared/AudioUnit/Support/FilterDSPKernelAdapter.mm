// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#include <Accelerate/Accelerate.h>

#import "AudioUnitBusBufferManager.hpp"
#import "BiquadFilter.hpp"
#import "FilterDSPKernel.hpp"
#import "FilterDSPKernelAdapter.hpp"
#import "BufferedAudioBus.hpp"

@implementation FilterDSPKernelAdapter {
    FilterDSPKernel _kernel;
    BufferedInputBus _buffer;
}

- (instancetype)init {
    if (self = [super init]) {
        ;
    }
    return self;
}

- (void) configureInput:(AVAudioFormat*)inputFormat output:(AVAudioFormat*)outputFormat
      maxFramesToRender:(AUAudioFrameCount)maxFramesToRender {
    _kernel.setFormat(inputFormat);
    _buffer.setFormat(inputFormat, outputFormat.channelCount, maxFramesToRender);
}

- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger)count output:(nonnull float*)output {

    // Create temporary filter here since the one in the FilterDSPKernel is used by the music render thread and it may
    // not have the most recent filter settings due to ramping or other latencies.
    BiquadFilter filter;
    filter.calculateParams(_kernel.cutoff(), _kernel.resonance(), _kernel.nyquistPeriod(), 1);
    filter.magnitudes(frequencies, count, _kernel.nyquistPeriod(), output);
}

- (void)set:(AUParameter *)parameter value:(AUValue)value {
    _kernel.setParameterValue(parameter.address, value);
}

- (AUValue)get:(AUParameter *)parameter {
    return _kernel.getParameterValue(parameter.address);
}

- (AUAudioUnitStatus) process:(AudioTimeStamp const*)timestamp
                   frameCount:(UInt32)frameCount
                     inputBus:(NSInteger)inputBusNumber
                       output:(AudioBufferList*)output
                       events:(AURenderEvent*)realtimeEventListHead
               pullInputBlock:(AURenderPullInputBlock)pullInputBlock
{
    // Pull samples from upstream node and place in our internal buffer
    AudioUnitRenderActionFlags actionFlags = 0;
    auto status = _buffer.pullInput(&actionFlags, timestamp, frameCount, inputBusNumber, pullInputBlock);
    if (status != noErr) return status;

    // If performing in-place operation, set output to use input buffers
    auto inPlace = output->mBuffers[0].mData == nullptr;
    if (inPlace) {
        AudioBufferList* input = _buffer.mutableAudioBufferList;
        for (auto i = 0; i < output->mNumberBuffers; ++i) {
            output->mBuffers[i].mData = input->mBuffers[i].mData;
        }
    }

    _kernel.setBuffers(_buffer.originalAudioBufferList, output);
    _kernel.render(timestamp, frameCount, realtimeEventListHead);

    return noErr;
}

@end
