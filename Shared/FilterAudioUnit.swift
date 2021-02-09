// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AudioToolbox
import AVFoundation
import CoreAudioKit
import os

/**
 Derivation of AUAudioUnit that provides a Swift container for the C++ FilterDSPKernel (by way of the Obj-C
 FilterDSPKernelAdapter). Also provides for factory presets and preset management. The actual filtering logic
 resides in the FilterDSPKernel class.
 */
public final class FilterAudioUnit: AUAudioUnit {
    private static let log = Logging.logger("FilterAudioUnit")
    private var log: OSLog { Self.log }

    public enum Failure: Swift.Error {
        case statusError(OSStatus)
        case unableToInitialize(String)
    }

    /// Component description that matches this AudioUnit. The values must match those found in the Info.plist
    /// Used by the app hosts to load the right component.
    public static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: FourCharCode(stringLiteral: "lpas"),
        componentManufacturer: FourCharCode(stringLiteral: "BRay"),
        componentFlags: 0,
        componentFlagsMask: 0
    )

    /// Name of the component
    public static let componentName = "B-Ray: Low-pass"
    /// The associated view controller for the audio unit that shows the controls
    public weak var viewController: FilterViewController?
    /// Runtime parameter definitions for the audio unit
    public lazy var parameterDefinitions: AudioUnitParameters = AudioUnitParameters(parameterHandler: kernel)
    /// Support one input bus
    public override var inputBusses: AUAudioUnitBusArray { _inputBusses }
    /// Support one output bus
    public override var outputBusses: AUAudioUnitBusArray { _outputBusses }
    /// Parameter tree containing filter parameter values
    public override var parameterTree: AUParameterTree? {
        get { parameterDefinitions.parameterTree }
        set { fatalError("attempted to set new parameterTree") }
    }

    /// Factory presets for the filter
    public override var factoryPresets: [AUAudioUnitPreset] { _factoryPresets }
    /// Announce support for user presets as well
    public override var supportsUserPresets: Bool { true }
    /// Preset get/set
    public override var currentPreset: AUAudioUnitPreset? {
        get { _currentPreset }
        set {
            guard let preset = newValue else {
                _currentPreset = nil
                return
            }

            if preset.number >= 0 {
                let values = factoryPresetValues[preset.number]
                _currentPreset = preset
                parameterDefinitions.setValues(cutoff: values.cutoff, resonance: values.resonance)
            }
            else {
                do {
                    fullStateForDocument = try presetState(for: preset)
                    _currentPreset = preset
                } catch {
                    os_log(.error, log: log, "Unable to restore from preset '%{public}s'", preset.name)
                }
            }
        }
    }

    /// Announce that the filter can work directly on upstream sample buffers
    public override var canProcessInPlace: Bool { true }

    /// Initial sample rate
    private let sampleRate: Double = 44100.0
    /// Maximum number of channels to support
    private let maxNumberOfChannels: UInt32 = 8
    /// Maximum frames to render
    private let maxFramesToRender: UInt32 = 512
    /// Objective-C bridge into the C++ kernel
    private let kernel = FilterDSPKernelAdapter()

    private let factoryPresetValues:[(name: String, cutoff: AUValue, resonance: AUValue)] = [
        ("Prominent", 2500.0, 5.0),
        ("Bright", 14_000.0, 12.0),
        ("Warm", 384.0, -3.0)
    ]

    private var _currentPreset: AUAudioUnitPreset? {
        didSet { os_log(.debug, log: log, "* _currentPreset name: %{public}s", _currentPreset.descriptionOrNil) }
    }

    private lazy var _factoryPresets = factoryPresetValues.enumerated().map {
        AUAudioUnitPreset(number: $0, name: $1.name)
    }

    private var inputBus: AUAudioUnitBus
    private var outputBus: AUAudioUnitBus

    private lazy var _inputBusses: AUAudioUnitBusArray = { AUAudioUnitBusArray(audioUnit: self, busType: .input,
                                                                               busses: [inputBus]) }()
    private lazy var _outputBusses: AUAudioUnitBusArray = { AUAudioUnitBusArray(audioUnit: self, busType: .output,
                                                                                busses: [outputBus]) }()
    /**
     Crete a new audio unit asynchronously.

     - parameter componentDescription: the component to instantiate
     - parameter options: options for instantiation
     - parameter completionHandler: closure to invoke upon creation or error
     */
    public override class func instantiate(with componentDescription: AudioComponentDescription,
                                           options: AudioComponentInstantiationOptions = [],
                                           completionHandler: @escaping (AUAudioUnit?, Error?) -> Void) {
        do {
            let auAudioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: options)
            completionHandler(auAudioUnit, nil)
        } catch {
            completionHandler(nil, error)
        }
    }

    /**
     Construct new instance, throwing exception if there is an error doing so.

     - parameter componentDescription: the component to instantiate
     - parameter options: options for instantiation
     */
    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {

        // Start with the default format. Host or downstream AudioUnit can change the format of the input/output bus
        // objects later between calls to allocateRenderResources().
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            os_log(.error, log: Self.log, "failed to create AVAudioFormat format")
            throw Failure.unableToInitialize(String(describing: AVAudioFormat.self))
        }

        os_log(.debug, log: Self.log, "format: %{public}s", format.description)
        inputBus = try AUAudioUnitBus(format: format)
        inputBus.maximumChannelCount = maxNumberOfChannels

        os_log(.debug, log: Self.log, "creating output bus")
        outputBus = try AUAudioUnitBus(format: format)
        outputBus.maximumChannelCount = maxNumberOfChannels

        try super.init(componentDescription: componentDescription, options: options)

        os_log(.debug, log: log, "type: %{public}s, subtype: %{public}s, manufacturer: %{public}s flags: %x",
               componentDescription.componentType.stringValue,
               componentDescription.componentSubType.stringValue,
               componentDescription.componentManufacturer.stringValue,
               componentDescription.componentFlags)

        maximumFramesToRender = maxFramesToRender
        currentPreset = factoryPresets.first
    }

    /**
     Take notice of input/output bus formats and prepare for rendering. If there are any errors getting things ready,
     routine should `setRenderResourcesAllocated(false)`.
     */
    public override func allocateRenderResources() throws {
        os_log(.info, log: log, "allocateRenderResources")
        os_log(.debug, log: log, "inputBus format: %{public}s", inputBus.format.description)
        os_log(.debug, log: log, "outputBus format: %{public}s", outputBus.format.description)
        os_log(.debug, log: log, "maximumFramesToRender: %d", maximumFramesToRender)

        if outputBus.format.channelCount != inputBus.format.channelCount {
            os_log(.error, log: log, "unequal channel count")
            setRenderResourcesAllocated(false)
            throw Failure.statusError(kAudioUnitErr_FailedInitialization)
        }

        // Communicate to the kernel the new formats being used
        kernel.startProcessing(inputBus.format, output: outputBus.format, maxFramesToRender: maximumFramesToRender)

        try super.allocateRenderResources()
    }

    /**
     Rendering has stopped -- tear down stuff that was supporting it.
     */
    public override func deallocateRenderResources() {
        os_log(.debug, log: log, "before super.deallocateRenderResources")
        kernel.stopProcessing()
        super.deallocateRenderResources()
        os_log(.debug, log: log, "after super.deallocateRenderResources")
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        os_log(.info, log: log, "internalRenderBlock")

        // Local values to capture in the closure that will be returned
        let maximumFramesToRender = self.maximumFramesToRender
        let kernel = self.kernel

        return { _, timestamp, frameCount, outputBusNumber, outputData, events, pullInputBlock in
            os_log(.debug, log: Self.log, "render - frameCount: %d  outputBusNumber: %d", frameCount, outputBusNumber)
            guard outputBusNumber == 0 else { return kAudioUnitErr_InvalidParameterValue }
            guard frameCount <= maximumFramesToRender else { return kAudioUnitErr_TooManyFramesToProcess }
            guard let pullInputBlock = pullInputBlock else { return kAudioUnitErr_NoConnection }
            return kernel.process(UnsafeMutablePointer(mutating: timestamp), frameCount: frameCount, output: outputData,
                                  events: UnsafeMutablePointer(mutating: events), pullInputBlock: pullInputBlock)
        }
    }

    public override func parametersForOverview(withCount: Int) -> [NSNumber] {
        Array([parameterDefinitions.cutoff, parameterDefinitions.resonance].map {
            NSNumber(value: $0.address)
        }[0..<withCount])
    }

    public override func supportedViewConfigurations(_ availableViewConfigurations: [AUAudioUnitViewConfiguration]) ->
    IndexSet {
        IndexSet(integersIn: 0..<availableViewConfigurations.count)
    }

    public override func select(_ viewConfiguration: AUAudioUnitViewConfiguration) {
        viewController?.selectViewConfiguration(viewConfiguration)
    }
}

extension FilterAudioUnit {

    /**
     Obtain the magnitudes at given frequencies (frequency response) for the current filter settings. This just
     forwards the request to the internal kernel.

     - parameter frequencies: the frequencies to evaluate
     - returns: the filter responses at the given frequencies
     */
    public func magnitudes(forFrequencies frequencies: [Float]) -> [Float] {
        var output: [Float] = Array(repeating: 0.0, count: frequencies.count)
        kernel.magnitudes(frequencies, count: frequencies.count, output: &output)
        return output
    }
}
