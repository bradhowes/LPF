// Copyright © 2021 Apple. All rights reserved.

import Foundation
import AudioToolbox

public final class UserPresetsManager: NSObject {

  public let audioUnit: AUAudioUnit
  public var presets: [AUAudioUnitPreset] { audioUnit.userPresets }
  public var presetsOrderedByNumber: [AUAudioUnitPreset] { presets.sorted { $0.number > $1.number } }
  public var presetsOrderedByName: [AUAudioUnitPreset] {
    presets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  public init(for audioUnit: AUAudioUnit) {
    self.audioUnit = audioUnit
  }

  public func find(name: String) -> AUAudioUnitPreset? {
    presets.first(where: { $0.name == name })
  }

  public func makeCurrent(name: String) {
    if let preset = find(name: name) {
      audioUnit.currentPreset = preset
    }
  }
  
  public func create(name: String) throws {
    let preset = AUAudioUnitPreset(number: nextNumber, name: name)
    try audioUnit.saveUserPreset(preset)
    audioUnit.currentPreset = preset
  }

  public func update(preset: AUAudioUnitPreset) throws {
    let preset = AUAudioUnitPreset(number: preset.number, name: preset.name)
    try audioUnit.saveUserPreset(preset)
    audioUnit.currentPreset = preset
  }

  public func renameCurrent(to name: String) throws {
    guard let old = audioUnit.currentPreset else { return }
    let new = AUAudioUnitPreset(number: old.number, name: name)
    try audioUnit.deleteUserPreset(old)
    try audioUnit.saveUserPreset(new)
    audioUnit.currentPreset = new
  }

  public func deleteCurrent() throws {
    guard let preset = audioUnit.currentPreset else { return }
    audioUnit.currentPreset = nil
    try audioUnit.deleteUserPreset(AUAudioUnitPreset(number: preset.number, name: preset.name))
  }

  private var nextNumber: Int {
    let ordered = presetsOrderedByNumber
    var number = ordered.first?.number ?? -1
    for entry in ordered {
      if entry.number != number {
        break
      }
      number -= 1
    }

    return number
  }
}
