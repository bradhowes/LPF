#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

struct BufferedAudioBus {
    AUAudioUnitBus* bus = nullptr;
    AUAudioFrameCount maxFramesToRender = 0;
    AVAudioPCMBuffer* buffer = nullptr;
    AudioBufferList const* originalAudioBufferList = nullptr;
    AudioBufferList* mutableAudioBufferList = nullptr;

    void setFormat(AVAudioFormat* format, AVAudioChannelCount channelCount, AUAudioFrameCount maxFrames) {
        maxFramesToRender = maxFrames;
        bus = [[AUAudioUnitBus alloc] initWithFormat: format error: nil];
        bus.maximumChannelCount = channelCount;
        buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat: format frameCapacity: maxFrames];
        originalAudioBufferList = buffer.audioBufferList;
        mutableAudioBufferList = buffer.mutableAudioBufferList;
    }

    void deallocateRenderResources() {
        buffer = nullptr;
        originalAudioBufferList = nullptr;
        mutableAudioBufferList = nullptr;
    }
};

struct BufferedInputBus : BufferedAudioBus {

    AUAudioUnitStatus pullInput(AudioUnitRenderActionFlags* actionFlags, AudioTimeStamp const* timestamp,
                                AVAudioFrameCount frameCount, NSInteger inputBusNumber,
                                AURenderPullInputBlock pullInputBlock) {
        if (pullInputBlock == nullptr) return kAudioUnitErr_NoConnection;
        prepareInputBufferList();
        return pullInputBlock(actionFlags, timestamp, frameCount, inputBusNumber, mutableAudioBufferList);
    }

    void prepareInputBufferList() {
        UInt32 byteSize = maxFramesToRender * sizeof(float);
        mutableAudioBufferList->mNumberBuffers = originalAudioBufferList->mNumberBuffers;
        for (UInt32 i = 0; i < originalAudioBufferList->mNumberBuffers; ++i) {
            mutableAudioBufferList->mBuffers[i].mNumberChannels = originalAudioBufferList->mBuffers[i].mNumberChannels;
            mutableAudioBufferList->mBuffers[i].mData = originalAudioBufferList->mBuffers[i].mData;
            mutableAudioBufferList->mBuffers[i].mDataByteSize = byteSize;
        }
    }
};
