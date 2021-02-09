#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

/**
 Maintains a buffer of PCM samples which is used to save samples from an upstream node.
 */
struct InputBuffer {

    /**
     Set the format of the buffer to use.

     @param format the format of the samples
     @param channelCount the number of channels in the upstream output
     @param maxFrames the maximum number of frames to be found in the upstream output
     */
    void setFormat(AVAudioFormat* format, AVAudioChannelCount channelCount, AUAudioFrameCount maxFrames) {
        maxFramesToRender_ = maxFrames;
        buffer_ = [[AVAudioPCMBuffer alloc] initWithPCMFormat: format frameCapacity: maxFrames];
        audioBufferList_ = buffer_.audioBufferList;
        mutableAudioBufferList_ = buffer_.mutableAudioBufferList;
        assert(buffer_.frameCapacity == maxFrames);
    }

    /**
     Forget any allocated buffer.
     */
    void reset() {
        buffer_ = nullptr;
        audioBufferList_ = nullptr;
        mutableAudioBufferList_ = nullptr;
    }

    /**
     Obtain samples from an upstream node. Output is stored in internal buffer.

     @param actionFlags render flags from the host
     @param timestamp the current transport time of the samples
     @param frameCount the number of frames to process
     @param inputBusNumber the bus to pull from
     @param pullInputBlock the function to call to do the pulling
     */
    AUAudioUnitStatus pullInput(AudioUnitRenderActionFlags* actionFlags, AudioTimeStamp const* timestamp,
                                AVAudioFrameCount frameCount, NSInteger inputBusNumber,
                                AURenderPullInputBlock pullInputBlock) {
        if (pullInputBlock == nullptr) {
            os_log_with_type(logger_, OS_LOG_TYPE_ERROR, "null pullInputBlock");
            return kAudioUnitErr_NoConnection;
        }

        prepareInputBufferList(frameCount);
        auto status = pullInputBlock(actionFlags, timestamp, frameCount, inputBusNumber, mutableAudioBufferList_);
        buffer_.frameLength = (status == noErr) ? frameCount : 0;
        return status;
    }

    /**
     Update the input buffer to reflect current format.

     @param frameCount the number of frames to expect to place in the buffer
     */
    void prepareInputBufferList(AVAudioFrameCount frameCount) {
        UInt32 byteSize = frameCount * sizeof(float);
        mutableAudioBufferList_->mNumberBuffers = audioBufferList_->mNumberBuffers;
        for (UInt32 i = 0; i < audioBufferList_->mNumberBuffers; ++i) {
            mutableAudioBufferList_->mBuffers[i].mNumberChannels = audioBufferList_->mBuffers[i].mNumberChannels;
            mutableAudioBufferList_->mBuffers[i].mData = audioBufferList_->mBuffers[i].mData;
            mutableAudioBufferList_->mBuffers[i].mDataByteSize = byteSize;
        }
    }

    AudioBufferList const* audioBufferList() const { return audioBufferList_; }
    AudioBufferList* mutableAudioBufferList() const { return mutableAudioBufferList_; }

private:
    os_log_t logger_ = os_log_create("LPF", "BufferedInputBus");
    AUAudioFrameCount maxFramesToRender_ = 0;
    AVAudioPCMBuffer* buffer_ = nullptr;
    AudioBufferList const* audioBufferList_ = nullptr;
    AudioBufferList* mutableAudioBufferList_ = nullptr;
};
