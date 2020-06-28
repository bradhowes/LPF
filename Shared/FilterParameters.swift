// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import Foundation
import os

/**
 Definitions for the runtime parameters of the filter. There are two:

 - cutoff -- the frequency at which the filter starts to roll off and filter out the higher frequencies
 - resonance -- a dB setting that can attenuate the frequencies near the cutoff

 */
public final class FilterParameters: NSObject {

    /// Definition of the cutoff parameter. Range is 12 - 20kHz.
    let cutoffParam: AUParameter = {
        let param = AUParameterTree.createParameter(
            withIdentifier: "cutoff", name: "Cutoff", address: FilterParameterAddress.cutoff.rawValue,
            min: 12.0, max: 20_000.0, unit: .hertz, unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp], valueStrings: nil, dependentParameters: nil)
        param.value = 440.0
        return param
    }()

    /// Definition of the resonance parameter. Range is -20dB - +20dB
    let resonanceParam: AUParameter = {
        let param = AUParameterTree.createParameter(
            withIdentifier: "resonance", name: "Resonance", address: FilterParameterAddress.resonance.rawValue,
            min: -20.0, max: 20.0, unit: .decibels, unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp], valueStrings: nil, dependentParameters: nil)
        param.value = 5.0
        return param
    }()

    let parameterTree: AUParameterTree

    /**
     Create a new AUParameterTree for the filter parameters. Installs two closures in the tree: one for providing values
     and the other for accepting new values from other sources.

     - parameter parameterHandler the object to use to handle the AUParameterTree requests
     */
    init(parameterHandler: RuntimeParameterHandler) {

        // Define a new parameter tree with the parameter defintions
        parameterTree = AUParameterTree.createTree(withChildren: [cutoffParam, resonanceParam])

        // Provide a way for the tree to change values in the AudioUnit
        parameterTree.implementorValueObserver = { param, value in parameterHandler.setParameter(param, value: value) }

        // Provide a way for the tree to obtain the current value of a parameter
        parameterTree.implementorValueProvider = { param in return parameterHandler.value(of: param) }

        // Provide a way to obtain String values for the current settings.
        parameterTree.implementorStringFromValueCallback = { param, value in
            let s: String = {
                switch param.address {
                case FilterParameterAddress.cutoff.rawValue: return String(format: "%.2f", param.value)
                case FilterParameterAddress.resonance.rawValue: return String(format: "%.2f", param.value)
                default: return "?"
                }
            }()
            os_log("parameter %d as string: %d %f %s", param.address, param.value, s)
            return s
        }
    }

    /**
     Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
     AudioUnit.

     - parameter cutoff: the new cutoff value to use
     - parameter resonance: the new resonance value to use
     */
    func setParameterValues(cutoff: AUValue, resonance: AUValue) {
        cutoffParam.value = cutoff
        resonanceParam.value = resonance
    }
}
