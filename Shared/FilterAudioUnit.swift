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

    /// Runtime parameter defintions for the audio unit
    public lazy var parameterDefinitions: AudioUnitParameters = AudioUnitParameters(parameterHandler: kernelAdapter)

    private let factoryPresetValues:[(name: String, cutoff: AUValue, resonance: AUValue)] = [
        ("Prominent", 2500.0, 5.0),
        ("Bright", 14_000.0, 12.0),
        ("Warm", 384.0, -3.0)
    ]

    private lazy var _factoryPresets = factoryPresetValues.enumerated().map {
        AUAudioUnitPreset(number: $0, name: $1.name)
    }

    private var _currentPreset: AUAudioUnitPreset? {
        didSet {
            os_log(.info, log: log, "* _currentPreset name: %{public}s", _currentPreset.descriptionOrNil)
        }
    }

    lazy private var inputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [kernelAdapter.inputBus])
    }()

    lazy private var outputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [kernelAdapter.outputBus])
    }()

    public override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { outputBusArray }

    public override var fullStateForDocument: [String : Any]? {
        get {
            let dict = super.fullStateForDocument ?? [String : Any]()
            os_log(.info, log: log, "* get fullStateForDocument: %{public}s", dict.description)
            return dict
        }
        set {
            os_log(.info, log: log, "* set fullStateForDocument: %{public}s", newValue.descriptionOrNil)
            super.fullStateForDocument = newValue
        }
    }

    public override var fullState: [String : Any]? {
        get {
            let dict = super.fullState ?? [String : Any]()
            os_log(.info, log: log, "* get fullState: %{public}s", dict.description)
            return dict
        }
        set {
            super.fullState = newValue
            os_log(.info, log: log, "* set fullState: %{public}s", newValue.descriptionOrNil)
            os_log(.info, log: log, "- userPresets.count: %d", userPresets.count)
            for each in userPresets {
                os_log(.info, log: log, "- %{public}s", each.description)
            }
        }
    }

    public override var parameterTree: AUParameterTree? {
        get { parameterDefinitions.parameterTree }
        set { os_log(.error, log: log, "attempted to set new parameterTree") }
    }

    public override var factoryPresets: [AUAudioUnitPreset] { _factoryPresets }

    public override var currentPreset: AUAudioUnitPreset? {
        get {
            os_log(.info, log: log, "* get currentPreset %{public}s", _currentPreset.descriptionOrNil)
            return _currentPreset
        }
        set { setCurrentPreset(newValue) }
    }

    private func setCurrentPreset(_ value: AUAudioUnitPreset?) {
        os_log(.info, log: log, "* setCurrentPreset %{public}s", value.descriptionOrNil)
        guard let preset = value else {
            _currentPreset = nil
            return
        }

        os_log(.info, log: log, "applying preset %{public}s/%d", preset.name, preset.number)
        if preset.number >= 0 {
            setFactoryPreset(preset)
        }
        else {
            setUserPreset(preset)
        }
    }

    private func setFactoryPreset(_ preset: AUAudioUnitPreset) {
        os_log(.info, log: log, "using factory")
        let settings = factoryPresetValues[preset.number]
        parameterDefinitions.setParameterValues(cutoff: settings.cutoff, resonance: settings.resonance)
        _currentPreset = preset
    }

    private func setUserPreset(_ preset: AUAudioUnitPreset) {
        os_log(.info, log: log, "using custom preset")
        if let state = try? presetState(for: preset) {
            fullStateForDocument = state
            _currentPreset = preset
        }
    }

    public override var userPresets: [AUAudioUnitPreset] {
        get {
            let found = localFilePresets()
                .map { $0.lastPathComponent }
                .sorted { $0 < $1 }
                .map { $0.split(separator: ".").first! }
                .enumerated().map { AUAudioUnitPreset(number: -($0 + 1), name: String($1)) }
            os_log(.info, log: log, "found.count: %d", found.count)
            return found
        }
    }

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

    private var userPresetsObserver: NSKeyValueObservation!

    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {
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

    deinit {
        if let userPresetsObserver = self.userPresetsObserver {
            NotificationCenter.default.removeObserver(userPresetsObserver)
        }
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

// MARK: - Presets
extension FilterAudioUnit {

    public override var supportsUserPresets: Bool { true }

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
        if var dict = preset.number >= 0 ? factoryState(index: preset.number) : try? presetState(for: preset) {
            dict["presetInfo"] = (preset.name, preset.number)
            return dict
        }
        return nil
    }

    override public func saveUserPreset(_ userPreset: AUAudioUnitPreset) throws {
        os_log(.info, log: log, "* saveUserPreset - %{public}s/%d", userPreset.name, userPreset.number)
        try super.saveUserPreset(userPreset)
    }

    override public func deleteUserPreset(_ userPreset: AUAudioUnitPreset) throws {
        os_log(.info, log: log, "* deleteUserPreset - %{public}s/%d", userPreset.name, userPreset.number)
        try super.deleteUserPreset(userPreset)
    }

    private func localFilePresets() -> [URL] {
        guard let library = try? FileManager.default.url(for: .allLibrariesDirectory, in: .userDomainMask,
                                                         appropriateFor: nil, create: true) else { return [] }
        let path = "Audio/Presets/" + Self.componentName
            .split(separator: ":")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "/")
        let pluginFolder = library.appendingPathComponent(path, isDirectory: true)
        let found = try? FileManager.default.contentsOfDirectory(at: pluginFolder, includingPropertiesForKeys: nil,
                                                                 options: [.skipsHiddenFiles,
                                                                           .skipsSubdirectoryDescendants,
                                                                           .skipsPackageDescendants])
        return found ?? []
    }
}
