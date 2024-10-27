// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <os/log.h>

#import <algorithm>
#import <string>
#import <AVFoundation/AVFoundation.h>

#import "AcceleratedBiquadFilter.hpp"
#import "DSPHeaders/BusBuffers.hpp"
#import "DSPHeaders/EventProcessor.hpp"

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
  Kernel(std::string name) noexcept : super(), log_{os_log_create(name_.c_str(), "Kernel")}
  {
    initialize(2, 44100.0);
  }

  /**
   Update kernel and buffers to support the given format and channel count

   @param busCount number of busses to support
   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   */
  void setRenderingFormat(NSInteger busCount, AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) noexcept {
    super::setRenderingFormat(busCount, format, maxFramesToRender);
    initialize(format.channelCount, format.sampleRate);
  }

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   @param duration the number of frames to ramp to the new value
   */
  bool setParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept;

  /**
   Obtain from the kernel the current value of an AU parameter.

   @param address the address of the parameter to return
   @returns current parameter value
   */
  AUValue getParameterValue(AUParameterAddress address) const noexcept;

  AUValue cutoff() const noexcept { return cutoff_.get(); }

  AUValue resonance() const noexcept { return resonance_.get(); }

  float nyquistPeriod() const noexcept { return nyquistPeriod_; }

private:

  void initialize(int channelCount, double sampleRate) noexcept {
    os_log_info(log_, "initialize BEGIN channelCount: %d sampleRate: %f", channelCount, sampleRate);
    sampleRate_ = sampleRate;
    nyquistFrequency_ = 0.5 * sampleRate;
    nyquistPeriod_ = 1.0 / nyquistFrequency_;
    filter_.calculateParams(cutoff_.get(), resonance_.get(), nyquistPeriod_, channelCount);
  }

  void doRenderingStateChanged(bool rendering) {
    if (!rendering) {
      cutoff_.stopRamping();
      resonance_.stopRamping();
    }
  }

  bool doParameterEvent(const AUParameterEvent& event, AUAudioFrameCount rampDuration) noexcept {
    return setParameterValue(event.parameterAddress, event.value, rampDuration);
  }

  void doRendering(NSInteger outputBusNumber, DSPHeaders::BusBuffers ins, DSPHeaders::BusBuffers outs,
                   AUAudioFrameCount frameCount) noexcept {
    auto cutoff = cutoff_.frameValue();
    auto resonance = resonance_.frameValue();
    filter_.calculateParams(cutoff, resonance, nyquistPeriod_, ins.size());
    filter_.apply(ins, outs, frameCount);
  }

  void doMIDIEvent(const AUMIDIEvent& midiEvent) noexcept {}

  AcceleratedBiquadFilter filter_;
  AUValue sampleRate_;
  AUValue nyquistFrequency_;
  AUValue nyquistPeriod_;
  DSPHeaders::Parameters::Float cutoff_;
  DSPHeaders::Parameters::Float resonance_;
  std::string name_;
  os_log_t log_;
};
