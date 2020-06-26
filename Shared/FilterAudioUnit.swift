// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AudioToolbox

/**
 Derivation of AUAudioUnit that provides a Swift container for the C++ FilterDSPKernel (by way of the Obj-C
 FilterDSPKernelAdapter). Also provides for factory presets and preset management. The actual filtering logic
 resides in the FilterDSPKernel class.
 */
public final class FilterAudioUnit: AUAudioUnit {

    private let parameterDefinitions: FilterParameters
    private let kernelAdapter: FilterDSPKernelAdapter

    lazy private var inputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [kernelAdapter.inputBus])
    }()

    lazy private var outputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [kernelAdapter.outputBus])
    }()

    public weak var viewController: FilterViewController?

    public override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { outputBusArray }
    
    public override var parameterTree: AUParameterTree? {
        get { return parameterDefinitions.parameterTree }
        set { /* The sample doesn't allow this property to be modified. */ }
    }

    public override var factoryPresets: [AUAudioUnitPreset] {
        return [
            AUAudioUnitPreset(number: 0, name: "Prominent"),
            AUAudioUnitPreset(number: 1, name: "Bright"),
            AUAudioUnitPreset(number: 2, name: "Warm")
        ]
    }

    private let factoryPresetValues:[(cutoff: AUValue, resonance: AUValue)] = [
        (2500.0, 5.0),    // "Prominent"
        (14_000.0, 12.0), // "Bright"
        (384.0, -3.0)     // "Warm"
    ]

    private var _currentPreset: AUAudioUnitPreset?
    
    public override var currentPreset: AUAudioUnitPreset? {
        get { return _currentPreset }
        set {
            guard let preset = newValue else {
                _currentPreset = nil
                return
            }
            
            if preset.number >= 0 {
                let values = factoryPresetValues[preset.number]
                parameterDefinitions.setParameterValues(cutoff: values.cutoff, resonance: values.resonance)
                _currentPreset = preset
            }
            else {
                do {
                    fullStateForDocument = try presetState(for: preset)
                    _currentPreset = preset
                } catch {
                    print("Unable to restore set for preset \(preset.name)")
                }
            }
        }
    }
    
    public override var supportsUserPresets: Bool { true }
    public override var internalRenderBlock: AUInternalRenderBlock { kernelAdapter.internalRenderBlock() }
    public override var canProcessInPlace: Bool { true }

    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {
        kernelAdapter = FilterDSPKernelAdapter()
        parameterDefinitions = FilterParameters(parameterHandler: kernelAdapter)
        try super.init(componentDescription: componentDescription, options: options)
        log(componentDescription)
        currentPreset = factoryPresets.first
    }

    public func magnitudes(forFrequencies frequencies: [Float]) -> [Float] {
        var output: [Float] = Array(repeating: 0.0, count: frequencies.count)
        kernelAdapter.magnitudes(frequencies, count: frequencies.count, output: &output)
        return output
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

    private func log(_ acd: AudioComponentDescription) {

        let info = ProcessInfo.processInfo
        print("\nProcess Name: \(info.processName) PID: \(info.processIdentifier)\n")

        let message = """
        FilterAudioUnit (
        type: \(acd.componentType.stringValue)
        subtype: \(acd.componentSubType.stringValue)
        manufacturer: \(acd.componentManufacturer.stringValue)
        flags: \(String(format: "%#010x", acd.componentFlags))
        )
        """
        print(message)
    }
}
