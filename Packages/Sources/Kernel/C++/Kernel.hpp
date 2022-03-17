// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <os/log.h>

#import <algorithm>
#import <string>
#import <AVFoundation/AVFoundation.h>

#import "AcceleratedBiquadFilter.hpp"
#import "DSPHeaders/BusBuffers.hpp"
#import "DSPHeaders/EventProcessor.hpp"
#import "DSPHeaders/RampingParameter.hpp"

/**
 The audio processing kernel that performs low-pass filtering of an audio signal.
 */
struct Kernel : public DSPHeaders::EventProcessor<Kernel> {
  using super = DSPHeaders::EventProcessor<Kernel>;
  friend super;

  /**
   Construct new kernel

   @param name the name to use for logging purposes.
   */
  Kernel(std::string name) : super(name)
  {
    initialize(2, 44100.0);
  }

  /**
   Update kernel and buffers to support the given format and channel count

   @param busCount number of busses to support
   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   */
  void setRenderingFormat(NSInteger busCount, AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) {
    super::setRenderingFormat(busCount, format, maxFramesToRender);
    initialize(format.channelCount, format.sampleRate);
  }

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   */
  void setParameterValue(AUParameterAddress address, AUValue value);

  /**
   Obtain from the kernel the current value of an AU parameter.

   @param address the address of the parameter to return
   @returns current parameter value
   */
  AUValue getParameterValue(AUParameterAddress address) const;

  AUValue cutoff() const { return cutoff_.get(); }

  AUValue resonance() const { return resonance_.get(); }

  float nyquistPeriod() const { return nyquistPeriod_; }

private:

  void initialize(int channelCount, double sampleRate) {
    os_log_info(log_, "initialize BEGIN channelCount: %d sampleRate: %f", channelCount, sampleRate);
    sampleRate_ = sampleRate;
    nyquistFrequency_ = 0.5 * sampleRate;
    nyquistPeriod_ = 1.0 / nyquistFrequency_;
    filter_.calculateParams(cutoff_.get(), resonance_.get(), nyquistPeriod_, channelCount);
  }

  void setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration);

  void setParameterFromEvent(const AUParameterEvent& event) {
    if (event.rampDurationSampleFrames == 0) {
      setParameterValue(event.parameterAddress, event.value);
    } else {
      setRampedParameterValue(event.parameterAddress, event.value, event.rampDurationSampleFrames);
    }
  }

  void doRendering(NSInteger outputBusNumber, DSPHeaders::BusBuffers ins, DSPHeaders::BusBuffers outs,
                   AUAudioFrameCount frameCount) {
    auto cutoff = cutoff_.frameValue();
    auto resonance = resonance_.frameValue();
    filter_.calculateParams(cutoff, resonance, nyquistPeriod_, ins.size());
    filter_.apply(ins, outs, frameCount);
  }

  void doMIDIEvent(const AUMIDIEvent& midiEvent) {}

  AcceleratedBiquadFilter filter_;
  AUValue sampleRate_;
  AUValue nyquistFrequency_;
  AUValue nyquistPeriod_;
  DSPHeaders::Parameters::RampingParameter<AUValue> cutoff_;
  DSPHeaders::Parameters::RampingParameter<AUValue> resonance_;
};
