// Copyright © 2020 Brad Howes. All rights reserved.

#pragma once

#import <algorithm>
#import <AVFoundation/AVFoundation.h>

class AudioUnitBusBufferManager
{
public:

    AudioUnitBusBufferManager(AUAudioUnitBus* bus, AVAudioChannelCount maxChannels)
    : bus_{bus} { bus_.maximumChannelCount = maxChannels; }

    void allocateRenderResources(AUAudioFrameCount maxFrames);

    void deallocateRenderResources();

    AUAudioUnitBus* bus() const { return bus_; }
    AudioBufferList* mutableAudioBufferList() const { return mutableAudioBufferList_; }

protected:
    AUAudioUnitBus* bus_ = nullptr;
    AUAudioFrameCount maxFrames_ = 0;
    AVAudioPCMBuffer* buffer_ = nullptr;
    AudioBufferList* mutableAudioBufferList_ = nullptr;
};

class AudioUnitBusOutputBufferManager: public AudioUnitBusBufferManager
{
public:

    AudioUnitBusOutputBufferManager(AUAudioUnitBus* bus, AVAudioChannelCount maxChannels)
    : AudioUnitBusBufferManager(bus, maxChannels) {}

    void prepareOutputBufferList(AudioBufferList& outBufferList, AVAudioFrameCount frameCount, bool zeroFill);
};

class AudioUnitBusInputBufferManager : public AudioUnitBusBufferManager
{
public:

    AudioUnitBusInputBufferManager(AUAudioUnitBus* bus, AVAudioChannelCount maxChannels)
    : AudioUnitBusBufferManager(bus, maxChannels) {}

    AUAudioUnitStatus pullInput(AudioUnitRenderActionFlags *actionFlags, AudioTimeStamp const* timestamp,
                                AVAudioFrameCount frameCount, NSInteger inputBusNumber,
                                AURenderPullInputBlock pullInputBlock);

private:

    void prepareInputBufferList(UInt32 frameCount);
};
