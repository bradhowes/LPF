// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#import "AudioUnitBusBufferManager.hpp"
#import "BiquadFilter.hpp"
#import "FilterDSPKernel.hpp"
#import "FilterDSPKernelAdapter.hpp"

@implementation FilterDSPKernelAdapter {
    FilterDSPKernel _kernel;
    AudioUnitBusInputBufferManager* _inputBus;
}

- (instancetype)init {
    if (self = [super init]) {
        AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
        _kernel.setFormat(format);

        AUAudioUnitBus* bus = [[AUAudioUnitBus alloc] initWithFormat:format error:nil];
        _inputBus = new AudioUnitBusInputBufferManager(bus, 8);
        _outputBus = [[AUAudioUnitBus alloc] initWithFormat:format error:nil];
    }

    return self;
}

- (void)dealloc {
    delete _inputBus;
}

- (AUAudioUnitBus *)inputBus {
    return _inputBus->bus();
}

- (void)magnitudes:(nonnull const float*)frequencies count:(NSInteger)count output:(nonnull float*)output {

    // Create temporary filter here since the one in the FilterDSPKernel is used by the music render thread and it may
    // not have the most recent filter settings due to ramping or other latencies.
    BiquadFilter filter;
    filter.calculateParams(_kernel.cutoff(), _kernel.resonance(), _kernel.nyquistPeriod(), 1);
    filter.magnitudes(frequencies, count, _kernel.nyquistPeriod(), output);
}

- (void)setParameter:(AUParameter *)parameter value:(AUValue)value {
    _kernel.setParameterValue(parameter.address, value);
}

- (AUValue)valueOf:(AUParameter *)parameter {
    return _kernel.getParameterValue(parameter.address);
}

- (AUAudioFrameCount)maximumFramesToRender {
    return _kernel.maximumFramesToRender();
}

- (void)setMaximumFramesToRender:(AUAudioFrameCount)maximumFramesToRender {
    _kernel.setMaximumFramesToRender(maximumFramesToRender);
}

- (void)allocateRenderResources {
    _inputBus->allocateRenderResources(self.maximumFramesToRender);
    _kernel.setFormat(self.outputBus.format);
}

- (void)deallocateRenderResources {
    _inputBus->deallocateRenderResources();
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (AUInternalRenderBlock)internalRenderBlock {

    // References to capture for use within the block.
    FilterDSPKernel& kernel = _kernel;
    AudioUnitBusInputBufferManager& inputBus = *_inputBus;

    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* actionFlags, const AudioTimeStamp* timestamp,
                              AVAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList* outputData,
                              const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
        if (frameCount > kernel.maximumFramesToRender()) return kAudioUnitErr_TooManyFramesToProcess;

        // Fetch samples from upstream
        AudioUnitRenderActionFlags pullFlags = 0;
        AUAudioUnitStatus err = inputBus.pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);
        if (err != 0) return err;

        // Obtain the sample buffers to use for rendering
        AudioBufferList* inAudioBufferList = inputBus.mutableAudioBufferList();
        AudioBufferList* outAudioBufferList = outputData;
        if (outAudioBufferList->mBuffers[0].mData == nullptr) {

            // Use the input buffers for the output buffers
            for (UInt32 index = 0; index < outAudioBufferList->mNumberBuffers; ++index) {
                outAudioBufferList->mBuffers[index].mData = inAudioBufferList->mBuffers[index].mData;
            }
        }

        kernel.setBuffers(inAudioBufferList, outAudioBufferList);

        // Do the rendering
        kernel.render(timestamp, frameCount, realtimeEventListHead);

        return noErr;
    };
}

@end
