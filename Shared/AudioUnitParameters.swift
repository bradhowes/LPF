// Copyright © 2020 Brad Howes. All rights reserved.

import Foundation
import os.log

/**
 Definitions for the runtime parameters of the filter. There are two:
 
 - cutoff -- the frequency at which the filter starts to roll off and filter out the higher frequencies
 - resonance -- a dB setting that can attenuate the frequencies near the cutoff
 
 */
public final class AudioUnitParameters: NSObject {
  
  private let log = Logging.logger("FilterParameters")
  
  /// Definition of the cutoff parameter. Range is 12 - 20kHz.
  public let cutoff = AUParameterTree.createParameter(withIdentifier: "cutoff", name: "Cutoff",
                                                      address: FilterParameterAddress.cutoff.rawValue,
                                                      min: 12.0, max: 20_000.0,
                                                      unit: .hertz, unitName: nil,
                                                      flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp,
                                                              .flag_DisplayLogarithmic],
                                                      valueStrings: nil,
                                                      dependentParameters: nil)
  
  /// Definition of the resonance parameter. Range is -20dB - +40dB
  public let resonance = AUParameterTree.createParameter(withIdentifier: "resonance", name: "Resonance",
                                                         address: FilterParameterAddress.resonance.rawValue,
                                                         min: -20.0, max: 40.0,
                                                         unit: .decibels, unitName: nil,
                                                         flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp],
                                                         valueStrings: nil,
                                                         dependentParameters: nil)
  
  /// AUParameterTree created with the parameter definitions for the audio unit
  public let parameterTree: AUParameterTree
  
  /**
   Create a new AUParameterTree for the defined filter parameters.
   
   Installs three closures in the tree:
   - one for providing values
   - one for accepting new values from other sources
   - and one for obtaining formatted string values
   
   - parameter parameterHandler the object to use to handle the AUParameterTree requests
   */
  init(parameterHandler: AUParameterHandler) {
    parameterTree = AUParameterTree.createTree(withChildren: [cutoff, resonance])
    cutoff.value = 440.0
    resonance.value = 5.0
    super.init()
    
    parameterTree.implementorValueObserver = { parameterHandler.set($0, value: $1) }
    parameterTree.implementorValueProvider = { parameterHandler.get($0) }
    parameterTree.implementorStringFromValueCallback = { param, value in
      let formatted: String = {
        switch param.address {
        case self.cutoff.address: return String(format: "%.2f", param.value)
        case self.resonance.address: return String(format: "%.2f", param.value)
        default: return "?"
        }
      }()
      os_log(.debug, log: self.log, "parameter %d as string: %d %f %{public}s",
             param.address, param.value, formatted)
      return formatted
    }
  }
  
  /**
   Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
   AudioUnit.
   
   - parameter cutoffValue: the new cutoff value to use
   - parameter resonanceValue: the new resonance value to use
   */
  public func setValues(cutoff: AUValue, resonance: AUValue) {
    os_log(.info, log: log, "cutoff: %f resonance: %f", cutoff, resonance)
    self.cutoff.setValue(cutoff, originator: nil)
    self.resonance.setValue(resonance, originator: nil)
  }
}
