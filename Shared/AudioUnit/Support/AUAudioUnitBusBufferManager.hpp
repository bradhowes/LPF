// Copyright © 2020 Brad Howes. All rights reserved.

#pragma once

#import <algorithm>
#import <AVFoundation/AVFoundation.h>

/**
 Utility classes to manage audio formats and buffers for an audio unit implementation's input and output audio busses.
 Reusable non-ObjC class, accessible from render thread.
 */
class AUAudioUnitBusBufferManager
{
public:

    AUAudioUnitBusBufferManager(AUAudioUnitBus* bus, AVAudioChannelCount maxChannels)
    : bus_{bus}
    {
        bus_.maximumChannelCount = maxChannels;
    }

    void allocateRenderResources(AUAudioFrameCount maxFrames)
    {
        maxFrames_ = maxFrames;
        buffer_ = [[AVAudioPCMBuffer alloc] initWithPCMFormat:bus_.format frameCapacity: maxFrames_];
        mutableAudioBufferList_ = buffer_.mutableAudioBufferList;
    }

    void deallocateRenderResources()
    {
        buffer_ = nullptr;
        mutableAudioBufferList_ = nullptr;
    }

    AUAudioUnitBus* bus() const { return bus_; }
    AudioBufferList* mutableAudioBufferList() const { return mutableAudioBufferList_; }

protected:
    AUAudioUnitBus* bus_ = nullptr;
    AUAudioFrameCount maxFrames_ = 0;
    AVAudioPCMBuffer* buffer_ = nullptr;
    AudioBufferList* mutableAudioBufferList_ = nullptr;
};

/**
 This class provides a prepareOutputBufferList method to copy the internal buffer pointers
 to the output buffer list in case the client passed in null buffer pointers.
 */
class AUAudioUnitBusOutputBufferManager: public AUAudioUnitBusBufferManager
{
public:
    AUAudioUnitBusOutputBufferManager(AUAudioUnitBus* bus, AVAudioChannelCount maxChannels)
    : AUAudioUnitBusBufferManager(bus, maxChannels) {}

    void prepareOutputBufferList(AudioBufferList& outBufferList, AVAudioFrameCount frameCount, bool zeroFill)
    {
        auto originalAudioBufferList = buffer_.audioBufferList;
        UInt32 byteSize = frameCount * sizeof(float);
        for (auto i = 0; i < outBufferList.mNumberBuffers; ++i) {
            auto& buff = outBufferList.mBuffers[i];
            buff.mNumberChannels = originalAudioBufferList->mBuffers[i].mNumberChannels;
            buff.mDataByteSize = byteSize;
            if (buff.mData == nullptr) buff.mData = originalAudioBufferList->mBuffers[i].mData;
            if (zeroFill) memset(buff.mData, 0, byteSize);
        }
    }
};

/**
 This class manages a buffer into which an audio unit with input busses can
 pull its input data.
 */
class AUAudioUnitBusInputBufferManager : public AUAudioUnitBusBufferManager
{
public:
    AUAudioUnitBusInputBufferManager(AUAudioUnitBus* bus, AVAudioChannelCount maxChannels)
    : AUAudioUnitBusBufferManager(bus, maxChannels) {}

    /*
     Gets input data for this input by preparing the input buffer list and pulling
     the pullInputBlock.
     */
    AUAudioUnitStatus pullInput(AudioUnitRenderActionFlags *actionFlags,
                                AudioTimeStamp const* timestamp,
                                AVAudioFrameCount frameCount,
                                NSInteger inputBusNumber,
                                AURenderPullInputBlock pullInputBlock)
    {
        if (pullInputBlock == nullptr) return kAudioUnitErr_NoConnection;
        prepareInputBufferList(frameCount);
        return pullInputBlock(actionFlags, timestamp, frameCount, inputBusNumber, mutableAudioBufferList_);
    }

private:

    /**
     Populate the mutableAudioBufferList with the data pointers from the originalAudioBufferList. The upstream
     audio unit may overwrite these with its own pointers, so each render cycle this function must be called to
     reset them.
     */
    void prepareInputBufferList(UInt32 frameCount)
    {
        auto originalAudioBufferList = buffer_.audioBufferList;
        mutableAudioBufferList_->mNumberBuffers = originalAudioBufferList->mNumberBuffers;

        UInt32 byteSize = std::min(frameCount, maxFrames_) * sizeof(float);
        for (auto i = 0; i < originalAudioBufferList->mNumberBuffers; ++i) {
            auto& buff = mutableAudioBufferList_->mBuffers[i];
            auto& obuf = originalAudioBufferList->mBuffers[i];
            buff.mNumberChannels = obuf.mNumberChannels;
            buff.mData = obuf.mData;
            buff.mDataByteSize = byteSize;
        }
    }
};
