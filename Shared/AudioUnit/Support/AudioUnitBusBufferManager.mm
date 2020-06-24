// Copyright © 2020 Brad Howes. All rights reserved.

#include "AudioUnitBusBufferManager.hpp"

void
AudioUnitBusBufferManager::allocateRenderResources(AUAudioFrameCount maxFrames)
{
    maxFrames_ = maxFrames;
    buffer_ = [[AVAudioPCMBuffer alloc] initWithPCMFormat:bus_.format frameCapacity: maxFrames_];
    mutableAudioBufferList_ = buffer_.mutableAudioBufferList;
}

void
AudioUnitBusBufferManager::deallocateRenderResources()
{
    buffer_ = nullptr;
    mutableAudioBufferList_ = nullptr;
}

void
AudioUnitBusOutputBufferManager::prepareOutputBufferList(AudioBufferList& outBufferList, AVAudioFrameCount frameCount,
                                                         bool zeroFill)
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

AUAudioUnitStatus
AudioUnitBusInputBufferManager::pullInput(AudioUnitRenderActionFlags *actionFlags,
                                          AudioTimeStamp const* timestamp,
                                          AVAudioFrameCount frameCount,
                                          NSInteger inputBusNumber,
                                          AURenderPullInputBlock pullInputBlock)
{
    if (pullInputBlock == nullptr) return kAudioUnitErr_NoConnection;
    prepareInputBufferList(frameCount);
    return pullInputBlock(actionFlags, timestamp, frameCount, inputBusNumber, mutableAudioBufferList_);
}

void
AudioUnitBusInputBufferManager::prepareInputBufferList(UInt32 frameCount)
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
