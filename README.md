![CI](https://github.com/bradhowes/LPF/workflows/CI/badge.svg?branch=main)
[![Swift 5.5](https://img.shields.io/badge/Swift-5.5-orange.svg?style=flat)](https://swift.org)
[![AUv3](https://img.shields.io/badge/AUv3-green.svg)](https://developer.apple.com/documentation/audiotoolbox/audio_unit_v3_plug-ins)
[![License: MIT](https://img.shields.io/badge/License-MIT-A31F34.svg)](https://opensource.org/licenses/MIT)

![](Shared/Resources/LPF/256px.png)

# About LPF (Low-pass Filter)

This project is an adaptation of Apple's [Creating Custom Audio
Effects](https://developer.apple.com/documentation/audiotoolbox/audio_unit_v3_plug-ins/creating_custom_audio_effects)
project. Much has been retooled for a better experience and code understanding, as well as various bug fixes.
You can find Apple's original README [here](Documentation/APPLE_README.md)

The gist is still the same as in the original:

* use an Objective-C/C++ kernel for audio sample manipulation in the render thread
* provide a tiny Objective-C interface to the kernel for Swift access
* perform all UI and most audio unit work in Swift (usually on the main thread)

Unlike Apple's example, this one uses the [Accelerate](https://developer.apple.com/documentation/accelerate)
framework to perform the filtering (Apple's code clearly shows you what the Biquadratic IIR filter does, just in
a slightly less performant way).

The code was developed in Xcode 11.5 on macOS 10.15.5. I have tested on both macOS and iOS devices primarily in
GarageBand, but also using test hosts on both devices as well as the excellent
[AUM](https://apps.apple.com/us/app/aum-audio-mixer/id1055636344) app on iOS.

Finally, it passes all
[auval](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitProgrammingGuide/AudioUnitDevelopmentFundamentals/AudioUnitDevelopmentFundamentals.html)
tests. (`auval -v aufx lpas BRay`)

If you are interested in making your own AUv3 components, feel free to fork this and adapt to your needs. However a better option might be to check out my
[AUv3Template](https://github.com/bradhowes/AUv3Template) repo which provides the same base functionality in iOS and macOS but allows for easier customization
via the included `build.py` Python script.

## Demo Targets

The macOS and iOS apps are simple AUv3 hosts that demonstrate the functionality of the AUv3 component. In the AUv3 world,
an app serves as a delivery mechanism for an app extension like AUv3. When the app is installed, the operating system will
also install and register any app extensions found in the app.

The `SimplyLowPass` apps attempt to instantiate the AUv3 component and wire it up to an audio file player and the output speaker.
When it runs, you can play the sample file and manipulate the filter settings -- cutoff frequency in the horizontal direction and 
resonance in the vertical. You can control these settings either by touching on the component's view graph and moving 
the point or by using the host sliders to change their associated values. The sliders are somewhat superfluous but they 
act on the AUv3 component via the AUPropertyTree much like an external MIDI controller might do. There are also a 
collection of three "factory" presets that you can choose which will apply canned settings. On macOS these are 
available via the `Presets` menu; on iOS there is a segment control that you can touch to change to a given factory 
preset.

Finally, the AUv3 component supports user-defined presets, and the simple host apps offer a way to create, update, 
rename, and delete them. On macOS, these functions are at the top of the `Presets` menu, followed by the factory
presets, and then any user-defined presets (there is also a button on the window that shows the same menu). The iOS app
offers the same functionality in a pop-up menu to the right of the factory presets segmented control.

## Code Layout

Each OS ([macOS](macOS) and [iOS](iOS)) have the same code layout:

* `App` -- code and configury for the application that hosts the AUv3 app extension. Again, the app serves as a demo host for the AUv3 app
extension.
* `Extension` -- code and configuration for the extension itself
* `Framework` -- code for the framework that contains the shared code by the app and the extension. Note that the framework is
made up of files that are common to both platforms, but these files are found in the `Shared` folder.

The [Shared](Shared) folder holds all of the code that is used by the above products. In it you will find:

* [BiquadFilter](Shared/Kernel/BiquadFilter.hpp) -- the C++ class that manages the filter state.
* [SimplyLowPassKernel](Shared/Kernel/SimplyLowPassKernel.hpp) -- a C++ class that does the rendering of audio samples by sending them
the through the biquad filter.
* [SimplyLowPassKernelAdapter](Shared/Kernel/SimplyLowPassKernelAdapter.hpp) -- an Objective C class that acts as a bridge between the
Swift and the C++ world.
* [FilterAudioUnit](Shared/FilterAudioUnit.swift) -- the actual AUv3 AudioUnit written in Swift. Most of the AUv3 state management is done in
Swift. When it is asked for the render block by Audio Units, it returns a method from the adapter.
* [FilterView](Shared/User%20Interface/FilterView.swift) -- a custom view (UIView and NSView) that draws the frequency response curve for
the current filter settings. It also allows for dynamically changing the filter settings by touch (UIView) or mouse (NSView).
* [FilterViewController](Shared/User%20Interface/FilterViewController.swift) -- a custom `AUViewController` that creates
new `FilterAudioUnit` instances for the host application.

Additional supporting files can be found in [Support](Shared/Support). Notable is the 
[SimplePlayEngine](Shared/Support/Audio/SimplePlayEngine.swift) Swift class that controls an `AVAudioEngine` instance 
for playing an audio file through the AUv3 filter component. This is what the apps use to demonstrate the filter 
component. It is not used by the AUv3 app extensions themselves.

Instantiating the AUv3 component and a view controller for its control plane is the responsibility of the 
[AudioUnitHost](Shared/Support/AudioUnitHost.swift) Swift class.

# Examples

Here is LPF shown running in GarageBand on macOS:

![](Documentation/GarageBand1.png)

For the LPF AUv3 Audio Unit to be available for use in GarageBand or any other Audio Unit "host" application,
the LPF app must be built and (probably) run. The macOS will detect the app extension declared in the app, and
register it for use by any other application that wants to work with AUv3 Audio Unit components.

The same applies to iOS Audio Units. First, build and then run the app on a device (simulators can run the app,
but you won't be able to run GarageBand or AUM there.) Next, fire up your host app, and you should be able to
add LPF as a signal processing effect.

![](Documentation/GarageBand2.jpg)

On GarageBand for iOS, there are three buttons in blue at the bottom of the AudioUnit view. The one on the left
("Warm") shows the current preset, and clicking on it will let you change it or let you save the current
settings to a new one. The two buttons on the right let you show an alternate control view (one provided by
GarageBand itself), and expand the existing view to use the entire height of the display.

![](Documentation/GarageBand3.jpg)
