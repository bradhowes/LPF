# Shared Directory

Contains code common to both iOS and macOS AUv3 extensions.

- AudioUnitParameters -- contains the AUParameter definitions for the runtime AU parameters.

- FilterAudioUnit -- the actual AUv3 component, derived from `AUAudioUnit` class. Implements presets and
  configures the audio unit but the actual audio processing is done in `Kernel/FilterDSPKernel`.

- Kernel -- contains the files involved in audio filtering

- User Interface -- controller and graphical view that shows the filter settings and its frequency response
  curve.

- Support -- sundry files used elsewhere
