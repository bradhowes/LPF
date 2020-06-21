/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Adapter object providing a Swift-accessible interface to the filter's underlying DSP code.
*/
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudioKit/AUViewController.h>

#import "AUAudioUnitBusBufferManager.hpp"
#import "FilterDSPKernel.hpp"
#import "FilterDSPKernelAdapter.h"

@implementation FilterDSPKernelAdapter {
    FilterDSPKernel _kernel;
    AUAudioUnitBusInputBufferManager* _inputBus;
}

- (instancetype)init {
    if (self = [super init]) {
        AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
        _kernel.setFormat(format);

        AUAudioUnitBus* bus = [[AUAudioUnitBus alloc] initWithFormat:format error:nil];
        _inputBus = new AUAudioUnitBusInputBufferManager(bus, 8);
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

- (NSArray<NSNumber *> *)magnitudesForFrequencies:(NSArray<NSNumber *> *)frequencies {
    FilterDSPKernel::BiquadCoefficients coefficients;
    coefficients.calculateLopassParams(_kernel.cutoffFilterSetting(), _kernel.resonanceFilterSetting(),
                                       _kernel.channelCount());

    double inverseNyquist = 2.0 / self.outputBus.format.sampleRate;
    NSMutableArray<NSNumber *> *magnitudes = [NSMutableArray arrayWithCapacity:frequencies.count];
    for (NSNumber *number in frequencies) {
        double frequency = [number doubleValue];
        double magnitude = coefficients.magnitudeForFrequency(frequency * inverseNyquist);
        [magnitudes addObject:@(magnitude)];
    }

    return [NSArray arrayWithArray:magnitudes];
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
    FilterDSPKernel& kernel = _kernel;
    AUAudioUnitBusInputBufferManager& inputBus = *_inputBus;

    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* actionFlags, const AudioTimeStamp* timestamp,
                              AVAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList* outputData,
                              const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {

        if (frameCount > kernel.maximumFramesToRender()) return kAudioUnitErr_TooManyFramesToProcess;

        AudioUnitRenderActionFlags pullFlags = 0;
        AUAudioUnitStatus err = inputBus.pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);
        if (err != 0) return err;

        AudioBufferList* inAudioBufferList = inputBus.mutableAudioBufferList();
        AudioBufferList* outAudioBufferList = outputData;
        if (outAudioBufferList->mBuffers[0].mData == nullptr) {

            // Use the input buffers for the output buffers
            for (UInt32 index = 0; index < outAudioBufferList->mNumberBuffers; ++index) {
                outAudioBufferList->mBuffers[index].mData = inAudioBufferList->mBuffers[index].mData;
            }
        }

        kernel.setBuffers(inAudioBufferList, outAudioBufferList);
        kernel.render(timestamp, frameCount, realtimeEventListHead);

        return noErr;
    };
}

@end
