/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The object managing the filter's cutoff and resonance parameters.
*/

import Foundation

/// Manages the AUv3Filter object's cutoff and resonance parameters.
class AUv3FilterDemoParameters {

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

    let parameterTree: AUParameterTree

    init(kernelAdapter: FilterDSPKernelAdapter) {

        // Create the audio unit's tree of parameters
        parameterTree = AUParameterTree.createTree(withChildren: [cutoffParam,
                                                                  resonanceParam])

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
    }
    
    func setParameterValues(cutoff: AUValue, resonance: AUValue) {
        cutoffParam.value = cutoff
        resonanceParam.value = resonance
    }
}
