// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AVFoundation

internal extension AUAudioUnitPreset {
  
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
