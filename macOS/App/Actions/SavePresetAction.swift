// Copyright © 2021 Brad Howes. All rights reserved.

import AppKit
import LowPassFilterFramework

internal struct PromptForReply {
  public enum Response {
    case ok(value: String)
    case cancel
  }

  static func ask(title: String, message: String) -> Response {
    let alert: NSAlert = NSAlert()

    alert.addButton(withTitle: "Save")
    alert.addButton(withTitle: "Cancel")

    alert.messageText = title
    alert.informativeText = message

    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
    textField.placeholderString = "Preset Name"
    textField.stringValue = ""

    alert.accessoryView = textField
    let response: NSApplication.ModalResponse = alert.runModal()
    if response == NSApplication.ModalResponse.alertFirstButtonReturn {
      return .ok(value: textField.stringValue)
    }
    return .cancel
  }
}

extension MainViewController {

  struct SavePresetAction {
    let viewController: MainViewController
    let userPresetsManager: UserPresetsManager

    init(_ viewController: MainViewController) {
      self.viewController = viewController
      self.userPresetsManager = viewController.userPresetsManager!
    }

    func start(_ action: AnyObject) {
      let response = PromptForReply.ask(title: "Save Preset", message: "")
      if case .ok(let value) = response {
        let name = value.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
          self.checkIsUniquePreset(named: name)
        }
      }
    }

    func checkIsUniquePreset(named name: String) {
      guard let existing = userPresetsManager.find(name: name) else {
        self.save(under: name)
        return
      }

      if viewController.yesOrNo("Existing Preset",
                                message: "Do you wish to change the existing preset to have the current settings?") {
        self.update(preset: existing)
      }
    }

    func save(under name: String) {
      do {
        try userPresetsManager.create(name: name)
      } catch {
        viewController.notify("Save Error", message: error.localizedDescription)
      }
    }

    func update(preset: AUAudioUnitPreset) {
      do {
        try userPresetsManager.update(preset: preset)
      } catch {
        viewController.notify("Update Error", message: error.localizedDescription)
      }
    }
  }

}
