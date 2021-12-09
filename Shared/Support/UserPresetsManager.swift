// Copyright © 2021 Apple. All rights reserved.

import Foundation
import AudioToolbox

/**
 Subset of AUAudioUnit functionality that is used by UserPresetsManager.
 */
public protocol AUAudioUnitPresetsFacade: AnyObject {
  var factoryPresetsArray: [AUAudioUnitPreset] {get}
  var userPresets: [AUAudioUnitPreset] {get}
  var currentPreset: AUAudioUnitPreset? {get set}

  func saveUserPreset(_ preset: AUAudioUnitPreset) throws
  func deleteUserPreset(_ preset: AUAudioUnitPreset) throws
}

public class UserPresetsManager {

  public let audioUnit: AUAudioUnitPresetsFacade
  public var presets: [AUAudioUnitPreset] { audioUnit.userPresets }
  public var presetsOrderedByNumber: [AUAudioUnitPreset] { presets.sorted { $0.number > $1.number } }
  public var presetsOrderedByName: [AUAudioUnitPreset] {
    presets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  public init(for audioUnit: AUAudioUnitPresetsFacade) {
    self.audioUnit = audioUnit
  }

  public func find(name: String) -> AUAudioUnitPreset? {
    presets.first(where: { $0.name == name })
  }

  public func clearCurrentPreset() {
    audioUnit.currentPreset = nil
  }

  public func makeCurrentPreset(name: String) {
    audioUnit.currentPreset = find(name: name)
  }

  public func makeCurrentPreset(factoryIndex: Int) {
    audioUnit.currentPreset = audioUnit.factoryPresetsArray[validating: factoryIndex]
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

  public var nextNumber: Int {
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
