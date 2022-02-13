// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import Foundation
import ParameterAddress
import os.log

private extension Array where Element == AUParameter {
  subscript(index: ParameterAddress) -> AUParameter { self[Int(index.rawValue)] }
}

/**
 Definitions for the runtime parameters of the filter.
 */
public final class AudioUnitParameters: NSObject, ParameterSource {

  private let log = Shared.logger("AudioUnitParameters")

  /// Array of AUParameter entities created from ParameterAddress value definitions.
  public let parameters: [AUParameter] = ParameterAddress.allCases.map { $0.parameterDefinition.parameter }

  /// Array of 2-tuple values that pair a factory preset name and its definition
  public let factoryPresetValues: [(name: String, preset: FilterPreset)] = [
    ("Prominent", .init(cutoff: 2500.0, resonance: 5.0)),
    ("Bright", .init(cutoff: 14000.0, resonance: 12.0)),
    ("Warm", .init(cutoff: 384.0, resonance: -3.0))
  ]

  /// Array of `AUAudioUnitPreset` for the factory presets.
  public var factoryPresets: [AUAudioUnitPreset] {
    factoryPresetValues.enumerated().map { .init(number: $0.0, name: $0.1.name ) }
  }

  /// AUParameterTree created with the parameter definitions for the audio unit
  public let parameterTree: AUParameterTree
  public var cutoff: AUParameter { parameters[.cutoff] }
  public var resonance: AUParameter { parameters[.resonance] }

  /**
   Create a new AUParameterTree for the defined filter parameters.
   */
  override public init() {
    parameterTree = AUParameterTree.createTree(withChildren: parameters)
    super.init()
    installParameterValueFormatter()
  }
}

extension AudioUnitParameters {

  private var missingParameter: AUParameter { fatalError() }

  /// Apply a factory preset -- user preset changes are handled by changing AUParameter values through the audio unit's
  /// `fullState` attribute.
  public func useFactoryPreset(_ preset: AUAudioUnitPreset) {
    if preset.number >= 0 {
      setValues(factoryPresetValues[preset.number].preset)
    }
  }

  public func storeParameters(into dict: inout [String : Any]) {
    for parameter in parameters {
      dict[parameter.identifier] = parameter.value
    }
  }

  public subscript(address: ParameterAddress) -> AUParameter {
    parameterTree.parameter(withAddress: address.parameterAddress) ?? missingParameter
  }

  public func valueFormatter(_ address: ParameterAddress) -> (AUValue) -> String {
    self[address].valueFormatter
  }

  private func installParameterValueFormatter() {
    parameterTree.implementorStringFromValueCallback = { param, valuePtr in
      let value: AUValue
      if let valuePtr = valuePtr {
        value = valuePtr.pointee
      } else {
        value = param.value
      }
      return String(format: param.stringFormatForValue, value) + param.suffix
    }
  }

  /**
   Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
   AudioUnit.
   */
  public func setValues(_ preset: FilterPreset) {
    cutoff.value = preset.cutoff
    resonance.value = preset.resonance
  }
}

extension AUParameter {

  /// Obtain string to use to separate a formatted value from its units name
  var unitSeparator: String { " " }
  /// Obtain the suffix to apply to a formatted value
  var suffix: String { unitSeparator + (unitName ?? "") }
  /// Obtain the format to use in String(format:value) when formatting a values
  var stringFormatForValue: String { "%.2f" }
  /// Obtain a closure that will format parameter values into a string
  var valueFormatter: (AUValue) -> String {
    { value in String(format: self.stringFormatForValue, value) + self.suffix }
  }
}

