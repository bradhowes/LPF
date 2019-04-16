# Creating Custom Audio Effects
Add custom audio effect processing to apps like Logic Pro X and GarageBand by creating Audio Unit (AU) plug-ins.

## Overview
This sample app shows you how to create a custom audio effect plug-in using the latest Audio Unit standard (AUv3). The AUv3 standard builds on the [App Extensions][1] model, which means you deliver your plug-in as an extension that’s contained in an app distributed through the App Store or your own store.

The sample audio unit is a low-pass filter that allows frequencies at or below the cutoff frequency to pass through to the output and that attenuates frequencies above this point. The plug-in also lets you change the filter’s resonance, which boosts or attenuates a narrow band of frequencies around the cutoff point. You set these values by moving the draggable point around the plug-in’s user interface as shown in the figure below.

![plug-in User Interface][image-1]

The project has targets for both iOS and macOS. Each platform’s main app target has two supporting targets:  `AUv3FilterExtension`, which contains the plug-in packaged as an audio unit extension, and `AUv3FilterFramework`, which bundles the plug-in’s code and resources.

- Note: See [Incorporating Audio Effects and Instruments][2] for details on how you can use this audio unit extension in a host app.

## Create a Custom Audio Effect Plug-In

The extension itself contains two primary pieces: an audio unit proper and a factory object that creates it.

The sample app's audio unit is `AUv3FilterDemo`. This is a Swift class that subclasses [AUAudioUnit][3] and defines the plug-in’s interface, including key features like its parameters, presets, and I/O busses. A class called `FilterDSPKernel`  provides the plug-in’s digital signal processing (DSP) logic, and is written in C++ to ensure real-time safety. Because Swift can’t talk directly to C++, the sample project also includes an Objective-C++ adapter class called `FilterDSPKernelAdapter` to act as an intermediary.

- Important: To ensure glitch-free performance, your plug-in’s audio processing must occur in a real-time safe context. This means you should not allocate memory, perform file I/O, take locks, or interact with the Swift or Objective-C runtimes when rendering audio.

When a host app requests your Audio Unit extension, you return a new instance of your audio unit subclass in the [createAudioUnit(with:)][4] method of your object adopting the [AUAudioUnitFactory][5] protocol as shown below.

``` swift
extension AUv3FilterDemoViewController: AUAudioUnitFactory {
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try AUv3FilterDemo(componentDescription: componentDescription, options: [])
        return audioUnit!
    }
}
```

## Add Custom Parameters to your Audio Unit
In most audio units, you’ll provide one or more parameters to configure the audio processing. Your audio unit arranges its parameters into a tree structure, provided by an instance of [AUParameterTree][6]. This object represents the root node of the plug-in’s tree of parameters and parameter groupings.

`AUv3FilterDemo` has parameters to control the filter’s cutoff frequency and resonance. You create its parameters using a factory method on `AUParameterTree`.

``` swift
private enum AUv3FilterParam: AUParameterAddress {
    case cutoff, resonance
}

/// Parameter to control the cutoff frequency (12Hz - 20kHz).
var cutoffParam: AUParameter = {
    let parameter =
        AUParameterTree.createParameter(withIdentifier: "cutoff",
                                        name: "Cutoff",
                                        address: AUv3FilterParam.cutoff.rawValue,
                                        min: 12.0,
                                        max: 20_000.0,
                                        unit: .hertz,
                                        unitName: nil,
                                        flags: [.flag_IsReadable,
                                                .flag_IsWritable,
                                                .flag_CanRamp],
                                        valueStrings: nil,
                                        dependentParameters: nil)
    // Set default value
    parameter.value = 0.0

    return parameter
}()

/// Parameter to control the cutoff frequency's resonance (+/-20dB).
var resonanceParam: AUParameter = {
    let parameter =
        AUParameterTree.createParameter(withIdentifier: "resonance",
                                        name: "Resonance",
                                        address: AUv3FilterParam.resonance.rawValue,
                                        min: -20.0,
                                        max: 20.0,
                                        unit: .decibels,
                                        unitName: nil,
                                        flags: [.flag_IsReadable,
                                                .flag_IsWritable,
                                                .flag_CanRamp],
                                        valueStrings: nil,
                                        dependentParameters: nil)
    // Set default value
    parameter.value = 20_000.0

    return parameter
}()
```

The cutoff parameter defines a frequency range between 12Hz and 20kHz, and the resonance parameter defines a decibel range between -20dB and 20dB. Each parameter is readable and writeable, and also supports ramping, which means you can modify its value over time.

You arrange the parameters into a tree by creating an `AUParameterTree` instance and setting them as the tree’s children.

``` swift
// Create the audio unit's tree of parameters
parameterTree = AUParameterTree.createTree(withChildren: [cutoffParam,
                                                          resonanceParam])
```

Next, you bind handlers to the parameter tree’s readable and writeable values by installing closures for its  [implementorValueObserver][7], [implementorValueProvider][8], and [implementorStringFromValueCallback][9]  properties. These closures delegate to the filter adapter instance, which in turn communicates with the underlying DSP logic.

``` swift
// Closure observing all externally-generated parameter value changes.
parameterTree.implementorValueObserver = { param, value in
    kernelAdapter.setParameter(param, value: value)
}

// Closure returning state of requested parameter.
parameterTree.implementorValueProvider = { param in
    return kernelAdapter.value(for: param)
}

// Closure returning string representation of requested parameter value.
parameterTree.implementorStringFromValueCallback = { param, value in
    switch param.address {
    case AUv3FilterParam.cutoff.rawValue:
        return String(format: "%.f", value ?? param.value)
    case AUv3FilterParam.resonance.rawValue:
        return String(format: "%.2f", value ?? param.value)
    default:
        return "?"
    }
}
```

## Connect the Parameters to Your User Interface
The sample app’s iOS and macOS targets each provide a platform-specific user interface. You use a shared view controller called `AUv3FilterDemoViewController` to coordinate the communication between the user interface to the audio unit. You connect your user interface to the audio unit’s parameters in the `connectViewToAU()` method as shown below.

``` swift
private func connectViewToAU() {
    guard needsConnection, let paramTree = audioUnit?.parameterTree else { return }

    // Find the cutoff and resonance parameters in the parameter tree.
    guard let cutoff = paramTree.value(forKey: "cutoff") as? AUParameter,
        let resonance = paramTree.value(forKey: "resonance") as? AUParameter else {
            fatalError("Required AU parameters not found.")
    }

    // Set the instance variables.
    cutoffParameter = cutoff
    resonanceParameter = resonance

    // Observe value changes made to the cutoff and resonance parameters.
    parameterObserverToken =
        paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let self = self else { return }

            // This closure is being called by an arbitrary queue. Ensure
            // all UI updates are dispatched back to the main thread.
            if [cutoff.address, resonance.address].contains(address) {
                DispatchQueue.main.async {
                    self.updateUI()
                }
            }
        })

    // Indicate the view and AU are connected
    needsConnection = false

    // Sync UI with parameter state
    updateUI()
}
```

In the `connectViewToAU()` method, you find the audio unit’s parameter tree and retrieve its cutoff and resonance parameters. You also add an observer closure to update the user interface as the plug-in’s parameter values change.

## Add Factory Presets
Most audio plug-ins provide a collection of preset values known as _factory presets_. A factory preset is a preconfigured arrangement of the plug-in’s parameter values that provide a useful starting point for further customization. A host app presents these presets in its user interface so the user can select them.

``` swift
let factoryPresets = [
    AUAudioUnitPreset(number: 0, name: "Prominent"),
    AUAudioUnitPreset(number: 1, name: "Bright"),
    AUAudioUnitPreset(number: 2, name: "Warm")
]

private let factoryPresetValues:[(cutoff: AUValue, resonance: AUValue)] = [
    (2500.0, 5.0),    // "Prominent"
    (14_000.0, 12.0), // "Bright"
    (384.0, -3.0)     // "Warm"
]
```

When a user selects a factory preset,  the `currentPreset` property is updated. In the property’s `didSet` observer, you look up the corresponding values for the preset and pass them to an observer object, which sets the values on the respective parameters.

``` swift
var currentPreset: AUAudioUnitPreset? {
    didSet {
        guard let preset = currentPreset else { return }

        // Notify the observer of the selection change.
        let values = factoryPresetValues[preset.number]
        presetObserver.didSelectPreset(cutoff: values.cutoff,
                                       resonance: values.resonance)
    }
}
```

## Package Your Plug-In to Run In-Process

Like all App Extensions, AUv3 plug-ins run _out-of-process_ by default , which means the extension runs in a separate process from the host app and all communication between the two occurs over interprocess communication (XPC). This model provides security and stability to the host app because errors that occur in the audio unit can’t adversely impact it. However, the XPC communication adds approximately 40 μs of latency to each render cycle, which may be unacceptable depending on the needs of a given audio session. In macOS only, you can work around this limitation by running your plug-in _in-process_, which eliminates the XPC communication as your audio unit runs as part of the host’s process.

Running a plug-in in-process requires an agreement between the host and the audio unit. The host requests in-process instantiation by passing the [.loadInProcess][10] option during the plug-in’s creation, and your audio unit needs to be packaged as described and shown below.

Your extension’s main binary cannot be dynamically loaded into another app, which means all executable code needs to reside in a separate framework bundle. However, the extension target still needs to contain at least one source file for the extension binary to be created, properly loaded, and linked with the framework bundle. To ensure the extension is created, add some unused placeholder code in your extension target, like that found in `AUv3FilterExtension.swift`.

``` swift
import AUv3FilterFramework

func placeholder() {
    // This placeholder function ensures the extension correctly loads.
}
```

The macOS sample packages all of the audio unit’s code into the `AUv3FilterFramework` target. You indicate that the extension’s code exists in a separate bundle by adding an `AudioComponentBundle` extension attribute to the target’s Info.plist file.

```
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>AudioComponentBundle</key>
        <string>com.example.apple-samplecode.AUv3FilterFramework</string>
        ...
    </dict>
    ...
</dict>
```

If you’re using a xib or Storyboard for your user interface, override your view controller’s [init(nibName:bundle:)][11] initializer and pass the framework bundle to the superclass initializer. This ensures your user interface properly loads when the system requests your audio unit extension.

``` swift
public override init(nibName: NSNib.Name?, bundle: Bundle?) {
    // Pass a reference to the owning framework bundle
    super.init(nibName: nibName, bundle: Bundle(for: type(of: self)))
}
```

Finally, in the extension’s Info.plist file, set the audio unit’s factory object,  `AUv3FilterDemoViewController`, as the extension’s principal class.

```
<key>NSExtension</key>
<dict>
    <key>NSExtensionPrincipalClass</key>
    <string>AUv3FilterFramework.AUv3FilterDemoViewController</string>
    ...
</dict>
```

- Note: See [Incorporating Audio Effects and Instruments][12] for a host app you can use to load your plug-in in-process and out-of-process.



[1]:	https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG
[2]:	https://developer.apple.com/documentation/audiotoolbox/incorporating_audio_effects_and_instruments
[3]:	https://developer.apple.com/documentation/audiotoolbox/auaudiounit
[4]:	https://developer.apple.com/documentation/audiotoolbox/auaudiounitfactory/1440321-createaudiounit
[5]:	https://developer.apple.com/documentation/audiotoolbox/auaudiounitfactory
[6]:	https://developer.apple.com/documentation/audiotoolbox/auparametertree
[7]:	https://developer.apple.com/documentation/audiotoolbox/auparameternode/1439658-implementorvalueobserver
[8]:	https://developer.apple.com/documentation/audiotoolbox/auparameternode/1439942-implementorvalueprovider
[9]:	https://developer.apple.com/documentation/audiotoolbox/auparameternode/1440045-implementorstringfromvaluecallba
[10]:	https://developer.apple.com/documentation/audiotoolbox/audiocomponentinstantiationoptions/1410490-loadinprocess
[11]:	https://developer.apple.com/documentation/appkit/nsviewcontroller/1434481-init
[12]:	https://developer.apple.com/documentation/audiotoolbox/incorporating_audio_effects_and_instruments

[image-1]:	Documentation/graph.png "plug-in User Interface"