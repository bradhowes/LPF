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

    public static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: FourCharCode(stringLiteral: "lpas"),
        componentManufacturer: FourCharCode(stringLiteral: "BRay"),
        componentFlags: 0,
        componentFlagsMask: 0
    )

    public static let componentName = "B-Ray: Low-pass"

    // public weak var viewController: FilterViewController?

    public let parameterDefinitions: AudioUnitParameters
    private let kernelAdapter: FilterDSPKernelAdapter

    private let factoryPresetValues:[(name: String, cutoff: AUValue, resonance: AUValue)] = [
        ("Prominent", 2500.0, 5.0),
        ("Bright", 14_000.0, 12.0),
        ("Warm", 384.0, -3.0)
    ]

    private lazy var _factoryPresets = factoryPresetValues.enumerated().map {
        AUAudioUnitPreset(number: $0, name: $1.name)
    }

    private var _currentPreset: AUAudioUnitPreset?

    lazy private var inputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [kernelAdapter.inputBus])
    }()

    lazy private var outputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [kernelAdapter.outputBus])
    }()

    public override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { outputBusArray }

    public override var fullState: [String : Any]? {
        get {
            (super.fullState ?? [String:Any]()).merging(parameterDefinitions.state) { $1 }
        }
        set {
            if let state = newValue {
                parameterDefinitions.setState(state)
            }
            super.fullState = newValue
        }
    }

    public override var parameterTree: AUParameterTree? {
        get { parameterDefinitions.parameterTree }
        set {
            os_log(.error, log: log, "attempted to set new parameterTree")
        }
    }

    public override var factoryPresets: [AUAudioUnitPreset] { _factoryPresets }

    public override var currentPreset: AUAudioUnitPreset? {
        get {
            _currentPreset
        }
        set {
            guard let preset = newValue else {
                _currentPreset = nil
                return
            }

            os_log(.info, log: log, "applying preset %{public}s/%d", preset.name, preset.number)
            if preset.number >= 0 {
                os_log(.info, log: log, "using factory")
                let settings = factoryPresetValues[preset.number]
                parameterDefinitions.setParameterValues(cutoff: settings.cutoff, resonance: settings.resonance)
                _currentPreset = preset
            }
            else {
                os_log(.info, log: log, "using custom preset")
                do {
                    fullState = try presetState(for: preset)
                } catch {
                    os_log(.error, log: log, "unable to restore settings for preset %d", preset.number)
                }
                _currentPreset = preset
            }
        }
    }

    public override var supportsUserPresets: Bool { true }
    public override var canProcessInPlace: Bool { true }

    public override var internalRenderBlock: AUInternalRenderBlock { kernelAdapter.internalRenderBlock() }

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

    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {
        kernelAdapter = FilterDSPKernelAdapter()
        parameterDefinitions = AudioUnitParameters(parameterHandler: kernelAdapter)
        try super.init(componentDescription: componentDescription, options: [.loadOutOfProcess])

        let info = ProcessInfo.processInfo
        os_log(.info, log: log, "process name: %{public}s PID: %d", info.processName, info.processIdentifier)
        os_log(.info, log: log, "type: %{public}s, subtype: %{public}s, manufacturer: %{public}s flags: %x",
               componentDescription.componentType.stringValue,
               componentDescription.componentSubType.stringValue,
               componentDescription.componentManufacturer.stringValue,
               componentDescription.componentFlags)

        currentPreset = factoryPresets.first
    }

    public override func parametersForOverview(withCount: Int) -> [NSNumber] { [0, 1] }

    public override func supportedViewConfigurations(_ configs: [AUAudioUnitViewConfiguration]) -> IndexSet {
        os_log(.error, log: log, "supportedViewConfigurations %d", configs.count)
        for config in configs {
            os_log(.error, log: log, "config: %f x %f", config.width, config.height)
        }
        return IndexSet(0..<configs.count)
    }

    public override func select(_ viewConfiguration: AUAudioUnitViewConfiguration) {
        os_log(.error, log: log, "select(viewConfiguration) %f x %f", viewConfiguration.width, viewConfiguration.height)
        super.select(viewConfiguration)
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

extension FilterAudioUnit {

    public var usingPreset: Bool {
        guard let preset = currentPreset else { return false }
        guard let state = anyPresetState(preset: preset) else { return false }
        return parameterDefinitions.matches(state)
    }

    private func factoryState(index: Int) -> [String:Float] {
        let preset = factoryPresetValues[index]
        return [parameterDefinitions.cutoffParam.identifier: preset.cutoff,
                parameterDefinitions.resonanceParam.identifier: preset.resonance]
    }

    private func anyPresetState(preset: AUAudioUnitPreset) -> [String:Any]? {
        preset.number >= 0 ? factoryState(index: preset.number) : try? presetState(for: preset)
    }

}
