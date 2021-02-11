# Kernel Directory

This directory contains the files involved in filtering.

- `BiquadFilter` -- represents the actual low-pass filter and performs the filtering via the `vDSP_biquadm`
  routine in the Apple's Accelerate framework.

- `FilterDSPKernel` -- holds parameters that define the filter (cutoff and resonance) and applies the filter to
  samples during AudioUnit rendering.

- `FilterDSPKernelAdapter` -- tiny Objective-C wrapper for the `FilterDSPKernel` so that Swift can work with it

- `InputBuffer` -- manages an AVAudioPCMBuffer that holds audio samples from an upstream node for processing by
  the filter.

- `KernelEventProcessor` -- base class for FilterDSPKernel which understands how to properly interleave events
  and sample renderings for sample-accurate events. Uses the "curiously recurring template pattern" to do so
  without need of virtual method calls.
