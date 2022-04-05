import AudioUnit.AUParameters
import AUv3Support

/**
 These are the unique addresses for the runtime parameters used by the audio unit.
 */
@objc public enum ParameterAddress: UInt64, CaseIterable {
  case cutoff = 0
  case resonance
};

public extension ParameterAddress {

  /// Obtain a ParameterDefinition for a parameter address enum.
  var parameterDefinition: ParameterDefinition {
    switch self {
    case .cutoff: return .defFloat("cutoff", localized: "Cutoff", address: ParameterAddress.cutoff,
                                   range: 12.0...20000.0, unit: .hertz, logScale: true)
    case .resonance: return .defFloat("resonance", localized: "Resonance", address: ParameterAddress.resonance,
                                      range: -20...40.0, unit: .decibels, logScale: false)
    }
  }
}

extension AUParameter {
  public var parameterAddress: ParameterAddress? { .init(rawValue: self.address) }
}

/// Allow enum values to serve as AUParameterAddress values.
extension ParameterAddress: ParameterAddressProvider {
  public var parameterAddress: AUParameterAddress { UInt64(self.rawValue) }
}

public extension ParameterAddressHolder {

  func setParameterAddress(_ address: ParameterAddress) { parameterAddress = address.rawValue }

  var parameterAddress: ParameterAddress? {
    let raw: AUParameterAddress = parameterAddress
    return ParameterAddress(rawValue: raw)
  }
}

extension ParameterAddress: CustomStringConvertible {
  public var description: String { "<ParameterAddress: '\(parameterDefinition.identifier)' \(rawValue)>" }
}
