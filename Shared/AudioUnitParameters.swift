// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import Foundation
import os

/**
 Definitions for the runtime parameters of the filter. There are two:

 - cutoff -- the frequency at which the filter starts to roll off and filter out the higher frequencies
 - resonance -- a dB setting that can attenuate the frequencies near the cutoff

 */
public final class AudioUnitParameters: NSObject {

    private let log = Logging.logger("FilterParameters")

    /// Definition of the cutoff parameter. Range is 12 - 20kHz.
    public let cutoffParam: AUParameter = {
        let param = AUParameterTree.createParameter(
            withIdentifier: "cutoff", name: "Cutoff", address: FilterParameterAddress.cutoff.rawValue,
            min: 12.0, max: 20_000.0, unit: .hertz, unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp], valueStrings: nil, dependentParameters: nil)
        param.value = 440.0
        return param
    }()

    /// Definition of the resonance parameter. Range is -20dB - +40dB
    public let resonanceParam: AUParameter = {
        let param = AUParameterTree.createParameter(
            withIdentifier: "resonance", name: "Resonance", address: FilterParameterAddress.resonance.rawValue,
            min: -20.0, max: 40.0, unit: .decibels, unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp], valueStrings: nil, dependentParameters: nil)
        param.value = 5.0
        return param
    }()

    /// AUParameterTree created with the parameter defintions for the audio unit
    let parameterTree: AUParameterTree

    /**
     Create a new AUParameterTree for the defined filter parameters.

     Installs three closures in the tree:
     - one for providing values
     - one for accepting new values from other sources
     - and one for obtaining formatted string values

     - parameter parameterHandler the object to use to handle the AUParameterTree requests
     */
    init(parameterHandler: AUParameterHandler) {

        // Define a new parameter tree with the parameter defintions
        parameterTree = AUParameterTree.createTree(withChildren: [cutoffParam, resonanceParam])
        super.init()

        // Provide a way for the tree to change values in the AudioUnit
        parameterTree.implementorValueObserver = { param, value in parameterHandler.set(param, value: value) }

        // Provide a way for the tree to obtain the current value of a parameter
        parameterTree.implementorValueProvider = { param in return parameterHandler.get(param) }

        // Provide a way to obtain String values for the current settings.
        parameterTree.implementorStringFromValueCallback = { param, value in
            let formatted: String = {
                switch param.address {
                case self.cutoffParam.address: return String(format: "%.2f", param.value)
                case self.resonanceParam.address: return String(format: "%.2f", param.value)
                default: return "?"
                }
            }()
            os_log(.info, log: self.log, "parameter %d as string: %d %f %{public}s",
                   param.address, param.value, formatted)
            return formatted
        }
    }

    /**
     Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
     AudioUnit.

     - parameter cutoff: the new cutoff value to use
     - parameter resonance: the new resonance value to use
     */
    func setParameterValues(cutoff: AUValue, resonance: AUValue) {
        os_log(.info, log: log, "cutoff: %f resonance: %f", cutoff, resonance)
        cutoffParam.value = cutoff
        resonanceParam.value = resonance
    }
}

extension AudioUnitParameters {

    var state: [String:Float] {
        [cutoffParam.identifier: cutoffParam.value, resonanceParam.identifier: resonanceParam.value]
    }

    func setState(_ state: [String:Any]) {
        guard let cutoff = state[cutoffParam.identifier] as? Float else {
            os_log(.error, log: log, "missing '%s' in state", cutoffParam.identifier)
            return
        }
        cutoffParam.value = cutoff

        guard let resonance = state[resonanceParam.identifier] as? Float else {
            os_log(.error, log: log, "missing '%s' in state", resonanceParam.identifier)
            return
        }
        resonanceParam.value = resonance
    }

    func matches(_ state: [String:Any]) -> Bool {
        for (key, value) in self.state {
            guard let other = state[key] as? Float, other == value else { return false }
        }

        return true
    }
}