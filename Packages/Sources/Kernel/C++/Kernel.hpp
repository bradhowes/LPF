// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <os/log.h>

#import <algorithm>
#import <string>
#import <AVFoundation/AVFoundation.h>

#import "AcceleratedBiquadFilter.hpp"
#import "DSPHeaders/BusBuffers.hpp"
#import "DSPHeaders/EventProcessor.hpp"
#import "DSPHeaders/Parameters/Float.hpp"

@import ParameterAddress;

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
  Kernel(std::string name) noexcept : super(), log_{os_log_create(name.c_str(), "Kernel")}
  {
    registerParameter(cutoff_);
    registerParameter(resonance_);
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

  /// @return the Nyquist period value defined as 1 / (sampleRate / 2)
  AUValue nyquistPeriod() const noexcept { return nyquistPeriod_; }

  /// @return the current filter cutoff setting
  AUValue cutoff() const noexcept { return cutoff_.getPending(); }

  /// @return the current filter resonance setting
  AUValue resonance() const noexcept { return resonance_.getPending(); }

  os_log_t log() const noexcept { return log_; }

private:

  void initialize(int channelCount, double sampleRate) noexcept {
    os_log_info(log_, "initialize BEGIN channelCount: %d sampleRate: %f", channelCount, sampleRate);
    auto nyquistFrequency = 0.5 * sampleRate;
    nyquistPeriod_ = 1.0 / nyquistFrequency;
    filter_.calculateParams(cutoff_.getImmediate(), resonance_.getImmediate(), nyquistPeriod_, channelCount);
  }

  /**
   Perform rendering activity on input samples.

   @param outputBusNumber the bus being written to (ignored)
   @param ins the collection of buffers containing input samples
   @param outs the collection of buffers for writing output samples
   @param frameCount the number of samples to process
   */
  void doRendering(NSInteger outputBusNumber, DSPHeaders::BusBuffers ins, DSPHeaders::BusBuffers outs,
                   AUAudioFrameCount frameCount) noexcept {
    // Normally we would use `frameValue()` instead of `getImmediate` but we are relying on the biquad filter's ability
    // to ramp so we always want to see the final value here.
    auto cutoff = cutoff_.getImmediate();
    auto resonance = resonance_.getImmediate();
    filter_.calculateParams(cutoff, resonance, nyquistPeriod_, ins.size());
    filter_.apply(ins, outs, frameCount);
  }

  AcceleratedBiquadFilter filter_;
  AUValue nyquistPeriod_;

  // NOTE: we do not use ramping in our parameters here because it is done in the biquad filter.
  DSPHeaders::Parameters::Float cutoff_{ParameterAddressCutoff, 0.0, false};
  DSPHeaders::Parameters::Float resonance_{ParameterAddressResonance, 0.0, false};
  std::string name_;
  os_log_t log_;
};
