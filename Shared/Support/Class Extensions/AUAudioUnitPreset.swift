// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AVFoundation

public extension AUAudioUnitPreset {
  
  /**
   Initialize new instance with given values
   
   - parameter number: the unique number for this preset. Factory presets must be non-negative.
   - parameter name: the display name for the preset.
   */
  convenience init(number: Int, name: String) {
    self.init()
    self.number = number
    self.name = name
  }
}

extension AUAudioUnitPreset {
  override public var description: String { "<AuAudioUnitPreset name: \(name)/\(number)>" }
}

extension AUAudioUnit: AUAudioUnitPresetsFacade {
  public var factoryPresetsArray: [AUAudioUnitPreset] { factoryPresets ?? [] }

}

public extension RandomAccessCollection {

  /// Returns the element at the specified index if it is within bounds, otherwise nil.
  /// - complexity: O(1)
  /// https://stackoverflow.com/a/68453929/629836
  subscript (validating index: Index) -> Element? {
    index >= startIndex && index < endIndex ? self[index] : nil
  }
}