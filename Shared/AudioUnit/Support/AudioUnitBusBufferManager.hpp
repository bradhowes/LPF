// Copyright © 2020 Brad Howes. All rights reserved.

#pragma once

#import <algorithm>
#import <AVFoundation/AVFoundation.h>

/**
 Manages the rendering buffers for an AudioUnitBus instance.
 */
class AudioUnitBusBufferManager
{
public:

    /**
     Create new manager for the given AudioUnit bus. The bus will be configured to support maxChannels

     @param bus the AudioUnitBus to work with
     @param maxChannels the maximum number of channels that the bus will support
     */
    explicit AudioUnitBusBufferManager(AUAudioUnitBus* bus, AVAudioChannelCount maxChannels)
    : bus_{bus} { bus_.maximumChannelCount = maxChannels; }

    /**
     Allocate render buffers for the bus.

     @param maxFrames the number of frames (samples) to buffer
     */
    void allocateRenderResources(AUAudioFrameCount maxFrames);

    /**
     Deallocate the render buffers.
     */
    void deallocateRenderResources();

    /**
     Obtain the bus that is being managed

     @returns AudioUnitBus pointer
     */
    AUAudioUnitBus* bus() const { return bus_; }

    /**
     Obtain the collection of mutable buffers for the bus.
     */
    AudioBufferList* mutableAudioBufferList() const { return mutableAudioBufferList_; }

protected:
    AUAudioUnitBus* bus_;
    AUAudioFrameCount maxFrames_ = 0;
    AVAudioPCMBuffer* buffer_ = nullptr;
    AudioBufferList* mutableAudioBufferList_ = nullptr;
};

/**
 Specialization of AudioUnitBusBufferManager for output buffers. Supports the situation where a downstream AudioUnit
 set up our buffer list to use theirs for faster in-place rendering.
 */
class AudioUnitBusOutputBufferManager: public AudioUnitBusBufferManager
{
public:

    AudioUnitBusOutputBufferManager(AUAudioUnitBus* bus, AVAudioChannelCount maxChannels)
    : AudioUnitBusBufferManager(bus, maxChannels) {}

    /**
     Configure the given AudioBufferList to use our internal buffers

     @param outBufferList the AudioBufferList to update
     @param frameCount the number of frames to prepare for
     @param zeroFill if true, fill the buffer(s) with zeros
     */
    void prepareOutputBufferList(AudioBufferList& outBufferList, AVAudioFrameCount frameCount, bool zeroFill);
};

/**
 Specialization of AudioUnitBusBufferManager for input buffers.
 */
class AudioUnitBusInputBufferManager : public AudioUnitBusBufferManager
{
public:

    AudioUnitBusInputBufferManager(AUAudioUnitBus* bus, AVAudioChannelCount maxChannels)
    : AudioUnitBusBufferManager(bus, maxChannels) {}

    /**
     Fetch frames (samples) from a sample provider (via closure), storing the samples in our internal buffers
     */
    AUAudioUnitStatus pullInput(AudioUnitRenderActionFlags *actionFlags, AudioTimeStamp const* timestamp,
                                AVAudioFrameCount frameCount, NSInteger inputBusNumber,
                                AURenderPullInputBlock pullInputBlock);

private:

    /**
     Sets up the internal mutable AudioBufferList to accept samples from the `pullInput` operation.
     */
    void prepareInputBufferList(UInt32 frameCount);
};
