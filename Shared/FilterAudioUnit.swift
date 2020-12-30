// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AudioToolbox
import CoreAudioKit
import os

/**
 Derivation of AUAudioUnit that provides a Swift container for the C++ FilterDSPKernel (by way of the Obj-C
 FilterDSPKernelAdapter). Also provides for factory presets and preset management. The actual filtering logic
 resides in the FilterDSPKernel class.
 */
public final class FilterAudioUnit: AUAudioUnit {

    private let log = Logging.logger("FilterAudioUnit")

    /// Component description for the AudioUnit. This must match the values found in the Info.plist
    public static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: FourCharCode(stringLiteral: "lpas"),
        componentManufacturer: FourCharCode(stringLiteral: "BRay"),
        componentFlags: 0,
        componentFlagsMask: 0
    )

    /// Name of the component
    public static let componentName = "B-Ray: Low-pass"

    /// Objective-C bridge into the C++ kernel
    private let kernelAdapter = FilterDSPKernelAdapter()

    // The owning view controller
    public weak var viewController: FilterViewController?

    /// Runtime parameter definitions for the audio unit
    public lazy var parameterDefinitions: AudioUnitParameters = AudioUnitParameters(parameterHandler: kernelAdapter)

    private let factoryPresetValues:[(name: String, cutoff: AUValue, resonance: AUValue)] = [
        ("Prominent", 2500.0, 5.0),
        ("Bright", 14_000.0, 12.0),
        ("Warm", 384.0, -3.0)
    ]

    private var _currentPreset: AUAudioUnitPreset? { didSet { os_log(.info, log: log, "* _currentPreset name: %{public}s", _currentPreset.descriptionOrNil) } }

    private lazy var _factoryPresets = factoryPresetValues.enumerated().map { AUAudioUnitPreset(number: $0, name: $1.name) }
    private lazy var _inputBusses: AUAudioUnitBusArray = { AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [kernelAdapter.inputBus]) }()
    private lazy var _outputBusses: AUAudioUnitBusArray = { AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [kernelAdapter.outputBus]) }()

    public override var inputBusses: AUAudioUnitBusArray { _inputBusses }
    public override var outputBusses: AUAudioUnitBusArray { _outputBusses }

    public override var parameterTree: AUParameterTree? {
        get { parameterDefinitions.parameterTree }
        set { fatalError("attempted to set new parameterTree") }
    }

    public override var factoryPresets: [AUAudioUnitPreset] { _factoryPresets }

    public override var supportsUserPresets: Bool { true }

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
                    // parameterDefinitions.setValues(cutoff: parameterDefinitions.cutoff.value, resonance: parameterDefinitions.resonance.value)
                } catch {
                    os_log(.error, log: log, "Unable to restore from preset '%{public}s'", preset.name)
                }
            }
        }
    }

    public override var canProcessInPlace: Bool { true }

    public override var internalRenderBlock: AUInternalRenderBlock { kernelAdapter.internalRenderBlock() }

    public override class func instantiate(with componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = [],
                                           completionHandler: @escaping (AUAudioUnit?, Error?) -> Void) {
        do {
            let auAudioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: options)
            completionHandler(auAudioUnit, nil)
        } catch {
            completionHandler(nil, error)
        }
    }

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)

        let info = ProcessInfo.processInfo
        os_log(.info, log: log, "process name: %{public}s PID: %d", info.processName, info.processIdentifier)
        os_log(.info, log: log, "type: %{public}s, subtype: %{public}s, manufacturer: %{public}s flags: %x",
               componentDescription.componentType.stringValue,
               componentDescription.componentSubType.stringValue,
               componentDescription.componentManufacturer.stringValue,
               componentDescription.componentFlags)

        currentPreset = factoryPresets.first
    }

    public override func parametersForOverview(withCount: Int) -> [NSNumber] {
        Array([parameterDefinitions.cutoff, parameterDefinitions.resonance].map { NSNumber(value: $0.address) }[0..<withCount])
    }

    public override func supportedViewConfigurations(_ availableViewConfigurations: [AUAudioUnitViewConfiguration]) -> IndexSet {
        var indexSet = IndexSet()

        let min = CGSize(width: 400, height: 100)
        let max = CGSize(width: 800, height: 500)

        for (index, config) in availableViewConfigurations.enumerated() {

            let size = CGSize(width: config.width, height: config.height)

            if size.width <= min.width && size.height <= min.height ||
                size.width >= max.width && size.height >= max.height ||
                size == .zero {

                indexSet.insert(index)
            }
        }
        return indexSet
    }

    public override func select(_ viewConfiguration: AUAudioUnitViewConfiguration) {
        viewController?.selectViewConfiguration(viewConfiguration)
    }

    public override var maximumFramesToRender: AUAudioFrameCount {
        get { kernelAdapter.maximumFramesToRender }
        set { if !renderResourcesAllocated { kernelAdapter.maximumFramesToRender = newValue } }
    }

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        if kernelAdapter.outputBus.format.channelCount != kernelAdapter.inputBus.format.channelCount {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization), userInfo: nil)
        }
        kernelAdapter.allocateRenderResources()
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        kernelAdapter.deallocateRenderResources()
    }
}

extension FilterAudioUnit {

    /**
     Obtain the magnitudes at given frequencies (frequency response) for the current filter settings.

     - parameter frequencies: the frequencies to evaluate
     - returns: the filter responses at the given frequencies
     */
    public func magnitudes(forFrequencies frequencies: [Float]) -> [Float] {
        var output: [Float] = Array(repeating: 0.0, count: frequencies.count)
        kernelAdapter.magnitudes(frequencies, count: frequencies.count, output: &output)
        return output
    }
}
