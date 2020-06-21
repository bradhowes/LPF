// Copyright © 2020 Brad Howes. All rights reserved.

import Foundation

class FilterParameters {

    private enum AUv3FilterParam: AUParameterAddress {
        case cutoff, resonance
    }

    let cutoffParam: AUParameter = {
        let param = AUParameterTree.createParameter(withIdentifier: "cutoff", name: "Cutoff",
                                                    address: AUv3FilterParam.cutoff.rawValue,
                                                    min: 12.0, max: 20_000.0, unit: .hertz, unitName: nil,
                                                    flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
                                                    valueStrings: nil, dependentParameters: nil)
        param.value = 440.0
        return param
    }()

    let resonanceParam: AUParameter = {
        let param = AUParameterTree.createParameter(withIdentifier: "resonance", name: "Resonance",
                                                    address: AUv3FilterParam.resonance.rawValue,
                                                    min: -20.0, max: 20.0, unit: .decibels, unitName: nil,
                                                    flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
                                                    valueStrings: nil, dependentParameters: nil)
        param.value = 5.0
        return param
    }()

    let parameterTree: AUParameterTree

    init(kernelAdapter: FilterDSPKernelAdapter) {
        parameterTree = AUParameterTree.createTree(withChildren: [cutoffParam, resonanceParam])
        parameterTree.implementorValueObserver = { param, value in kernelAdapter.setParameter(param, value: value) }
        parameterTree.implementorValueProvider = { param in return kernelAdapter.value(of: param) }
        parameterTree.implementorStringFromValueCallback = { param, value in
            switch param.address {
            case AUv3FilterParam.cutoff.rawValue: return String(format: "%.f", value ?? param.value)
            case AUv3FilterParam.resonance.rawValue: return String(format: "%.2f", value ?? param.value)
            default: return "?"
            }
        }
    }

    func setParameterValues(cutoff: AUValue, resonance: AUValue) {
        cutoffParam.value = cutoff
        resonanceParam.value = resonance
    }
}
