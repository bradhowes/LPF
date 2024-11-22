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

  AUValue nyquistPeriod() const noexcept { return nyquistPeriod_; }

  AUValue cutoff() const noexcept { return cutoff_.getPending(); }

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
   Set a paramete value from within the render loop.

   @param address the parameter to change
   @param value the new value to use
   @param duration the ramping duration to transition to the new value
   */
  bool doSetImmediateParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept;

  /**
   Set a paramete value from the UI via the parameter tree. Will be recognized and handled in the next render pass.

   @param address the parameter to change
   @param value the new value to use
   */
  bool doSetPendingParameterValue(AUParameterAddress address, AUValue value) noexcept;

  /**
   Get the paramete value last set in the render thread. NOTE: this does not account for any ramping that might be in
   effect.

   @param address the parameter to access
   @returns parameter value
   */
  AUValue doGetImmediateParameterValue(AUParameterAddress address) const noexcept;

  /**
   Get the paramete value last set by the UI / parameter tree. NOTE: this does not account for any ramping that might
   be in effect.

   @param address the parameter to access
   @returns parameter value
   */
  AUValue doGetPendingParameterValue(AUParameterAddress address) const noexcept;

  /**
   Notification that the rendering state has changed (stopped/started).

   @param rendering `true` if rendering has started
   */
  void doRenderingStateChanged(bool rendering) {}

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

  /**
   Process a MIDI (v1) event.

   @param midiEvent the event that was received
   */
  void doMIDIEvent(const AUMIDIEvent& midiEvent) noexcept {}

  AcceleratedBiquadFilter filter_;
  AUValue nyquistPeriod_;
  DSPHeaders::Parameters::Float cutoff_{0.0, false};
  DSPHeaders::Parameters::Float resonance_{0.0, false};
  std::string name_;
  os_log_t log_;
};
