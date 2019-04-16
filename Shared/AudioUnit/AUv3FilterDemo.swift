/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An AUAudioUnit subclass implementing a low-pass filter with resonance.
*/

import Foundation
import AudioToolbox
import AVFoundation
import CoreAudioKit

public class AUv3FilterDemo: AUAudioUnit {

    private let presets: AUv3FilterDemoPresets
    private let parameters: AUv3FilterDemoParameters
    private let kernelAdapter: FilterDSPKernelAdapter

    lazy private var inputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self,
                            busType: .input,
                            busses: [kernelAdapter.inputBus])
    }()

    lazy private var outputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self,
                            busType: .output,
                            busses: [kernelAdapter.outputBus])
    }()

    // The owning view controller
    weak var viewController: AUv3FilterDemoViewController?

    /// The filter's input busses
    public override var inputBusses: AUAudioUnitBusArray {
        return inputBusArray
    }

    /// The filter's output busses
    public override var outputBusses: AUAudioUnitBusArray {
        return outputBusArray
    }

    /// The tree of parameters provided by this AU.
    public override var parameterTree: AUParameterTree? {
        return parameters.parameterTree
    }

    /// The default, immutable presets provided by this AU.
    public override var factoryPresets: [AUAudioUnitPreset] {
        return presets.factoryPresets
    }

    /// The currently selected preset.
    public override var currentPreset: AUAudioUnitPreset? {
        get { return presets.currentPreset }
        set {
            if let preset = newValue, factoryPresets.contains(preset) {
                presets.currentPreset = preset
            } else {
                presets.currentPreset = factoryPresets[0]
            }
        }
    }

    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {

        // Create adapter to communicate to underlying C++ DSP code
        kernelAdapter = FilterDSPKernelAdapter()

        // Create parameters object to control cutoff frequency and resonance
        parameters = AUv3FilterDemoParameters(kernelAdapter: kernelAdapter)

        // Create factory presets
        presets = AUv3FilterDemoPresets(presetObserver: parameters)

        // Init super class
        try super.init(componentDescription: componentDescription, options: options)

        // Activate default preset
        presets.activateDefault()

        // Log component description values
        log(componentDescription)
    }

    private func log(_ acd: AudioComponentDescription) {

        let info = ProcessInfo.processInfo
        print("\nProcess Name: \(info.processName) PID: \(info.processIdentifier)\n")

        let message = """
        AUv3FilterDemo (
                  type: \(acd.componentType.stringValue)
               subtype: \(acd.componentSubType.stringValue)
          manufacturer: \(acd.componentManufacturer.stringValue)
                 flags: \(String(format: "%#010x", acd.componentFlags))
        )
        """
        print(message)
    }

    // Gets the magnitudes corresponding to the specified frequencies.
    func magnitudes(forFrequencies frequencies: [Double]) -> [Double] {
        return kernelAdapter.magnitudes(forFrequencies: frequencies as [NSNumber]).map { $0.doubleValue }
    }

    public override var maximumFramesToRender: AUAudioFrameCount {
        get {
            return kernelAdapter.maximumFramesToRender
        }
        set {
            if !renderResourcesAllocated {
                kernelAdapter.maximumFramesToRender = newValue
            }
        }
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

    public override var internalRenderBlock: AUInternalRenderBlock {
        return kernelAdapter.internalRenderBlock()
    }

    // Boolean indicating that this AU can process the input audio in-place
    // in the input buffer, without requiring a separate output buffer.
    public override var canProcessInPlace: Bool {
        return true
    }

    // MARK: View Configurations
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
}

extension FourCharCode {
    var stringValue: String {
        let value = CFSwapInt32BigToHost(self)
        let bytes = [0, 8, 16, 24].map { UInt8(value >> $0 & 0x000000FF) }
        guard let result = String(bytes: bytes, encoding: .utf8) else {
            return "fail"
        }
        return result
    }
}
