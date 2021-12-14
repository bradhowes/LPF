// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import Cocoa
import LowPassFilterFramework
import os.log

final class MainViewController: NSViewController {
  private static let log = Logging.logger("MainViewController")
  private var log: OSLog { Self.log }

  private let showedInitialAlert = "showedInitialAlert"

  private let cutoffSliderMinValue: Double = 0.0
  private let cutoffSliderMaxValue: Double = 9.0
  private lazy var cutoffSliderMaxValuePower2Minus1 = Float(pow(2, cutoffSliderMaxValue) - 1)

  private let audioUnitHost = AudioUnitHost(componentDescription: FilterAudioUnit.componentDescription)
  internal var userPresetsManager: UserPresetsManager?

  private var cutoffParameter: AUParameter?
  private var resonanceParameter: AUParameter?

  private var playButton: NSButton!
  private var bypassButton: NSButton!
  private var presetsButton: NSButton!

  private var presetsMenu: NSMenu!
  private var savePresetMenuItem: NSMenuItem!
  private var renamePresetMenuItem: NSMenuItem!
  private var deletePresetMenuItem: NSMenuItem!

  private var playMenuItem: NSMenuItem!
  private var bypassMenuItem: NSMenuItem!

  @IBOutlet var cutoffSlider: NSSlider!
  @IBOutlet var cutoffTextField: NSTextField!
  @IBOutlet var resonanceSlider: NSSlider!
  @IBOutlet var resonanceTextField: NSTextField!
  @IBOutlet var containerView: NSView!
  @IBOutlet weak var instructions: NSView!
  @IBOutlet weak var instructionsButton: NSButton!

  private var filterView: NSView?
  private var allParameterValuesObserverToken: NSKeyValueObservation?
  private var parameterTreeObserverToken: AUParameterObserverToken?
}

// MARK: - View Management

extension MainViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    cutoffSlider.minValue = cutoffSliderMinValue
    cutoffSlider.maxValue = cutoffSliderMaxValue

    // Start out hidden and only show after everything is up and running and we discover that this is the first time
    // for the user to run the application on their device.
    instructions.isHidden = true
    instructions.wantsLayer = true
    instructions.layer?.borderWidth = 4
    instructions.layer?.borderColor = NSColor.systemOrange.lighter.cgColor
    instructions.layer?.cornerRadius = 16
    instructions.backgroundColor = NSColor.black
    instructionsButton.target = self
    instructionsButton.action = #selector(dismissInstructions(_:))
  }

  override func viewWillAppear() {
    super.viewWillAppear()

    guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { fatalError() }
    presetsMenu = appDelegate.presetsMenu
    guard presetsMenu != nil else { fatalError() }
    presetsMenu.autoenablesItems = false

    savePresetMenuItem = appDelegate.savePresetMenuItem
    savePresetMenuItem.target = self
    savePresetMenuItem.action = #selector(handleSavePresetMenuSelected(_:))

    renamePresetMenuItem = appDelegate.renamePresetMenuItem
    renamePresetMenuItem.target = self
    renamePresetMenuItem.action = #selector(handleRenamePresetMenuSelected(_:))

    deletePresetMenuItem = appDelegate.deletePresetMenuItem
    deletePresetMenuItem.target = self
    deletePresetMenuItem.action = #selector(handleDeletePresetMenuSelected(_:))

    playMenuItem = appDelegate.playMenuItem
    bypassMenuItem = appDelegate.bypassMenuItem
    guard playMenuItem != nil, bypassMenuItem != nil else { fatalError() }
    bypassMenuItem.isEnabled = false

    guard let windowController = view.window?.windowController as? MainWindowController else { fatalError() }
    view.window?.delegate = self

    playButton = windowController.playButton
    bypassButton = windowController.bypassButton
    bypassButton.isEnabled = false
    presetsButton = windowController.presetsButton

    guard let savePresetMenuItem = appDelegate.savePresetMenuItem else { fatalError() }
    savePresetMenuItem.target = self
    savePresetMenuItem.action = #selector(handleSavePresetMenuSelected(_:))

    // Keep last
    audioUnitHost.delegate = self
  }

  override func viewDidLayout() {
    super.viewDidLayout()
    filterView?.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: containerView.frame.size)
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    let showedAlertKey = "showedInitialAlert"
    guard UserDefaults.standard.bool(forKey: showedAlertKey) == false else { return }
    UserDefaults.standard.set(true, forKey: showedAlertKey)
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "AUv3 Component Installed"
    alert.informativeText =
      """
      The AUv3 component 'SimplyLowPass' is now available on your device and can be used in other AUv3 host apps such
      as GarageBand and Logic. You can continue to use this app to experiment, but you do not need to have it running
      in order to access the AUv3 component in other apps. If you delete this app from your device, the AUv3 component
      will no longer be available for use in other host applications.
      """
    alert.addButton(withTitle: "OK")
    alert.beginSheetModal(for: view.window!) { _ in }
  }
}

// MARK: - AudioUnitHostDelegate

extension MainViewController: AudioUnitHostDelegate {

  func connected(audioUnit: AUAudioUnit, viewController: ViewController) {
    userPresetsManager = .init(for: audioUnit)
    connectFilterView(viewController)
    connectParametersToControls(audioUnit)
    showInstructions()
  }

  func failed(error: AudioUnitHostError) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "AUv3 Failure"
    alert.informativeText = "Unable to load the AUv3 component. \(error.description)"
    alert.addButton(withTitle: "OK")
    alert.beginSheetModal(for: view.window!) { _ in self.view.window?.close() }
  }
}

// MARK: - UI Actions

extension MainViewController {

  @IBAction private func togglePlay(_ sender: NSButton) {
    audioUnitHost.togglePlayback()
    let isPlaying = audioUnitHost.isPlaying

    playButton?.image = isPlaying ? NSImage(named: "stop") : NSImage(named: "play")

    audioUnitHost.audioUnit?.shouldBypassEffect = false
    bypassButton?.image = NSImage(named: "enabled")
    bypassButton?.isEnabled = isPlaying
    bypassMenuItem?.isEnabled = isPlaying
  }

  @IBAction private func toggleBypass(_ sender: NSButton) {
    let wasBypassed = audioUnitHost.audioUnit?.shouldBypassEffect ?? false
    let isBypassed = !wasBypassed
    audioUnitHost.audioUnit?.shouldBypassEffect = isBypassed
    bypassButton?.image = isBypassed ? NSImage(named: "bypassed") : NSImage(named: "enabled")
    bypassMenuItem?.title = isBypassed ? "Resume" : "Bypass"
  }

  @IBAction private func presetsButton(_ sender: NSButton) {
    let location = NSPoint(x: 0, y: sender.frame.height + 5)
    presetsMenu.popUp(positioning: nil, at: location, in: sender)
  }

  @IBAction private func cutoffSliderValueChanged(_ sender: NSSlider) {
    cutoffParameter?.setValue(frequencyValueForSliderLocation(sender.floatValue), originator: parameterTreeObserverToken)
    userPresetsManager?.clearCurrentPreset()
  }

  @IBAction private func resonanceSliderValueChanged(_ sender: NSSlider) {
    resonanceParameter?.setValue(sender.floatValue, originator: parameterTreeObserverToken)
    userPresetsManager?.clearCurrentPreset()
  }

  @objc private func handleSavePresetMenuSelected(_ sender: NSMenuItem) throws {
    SavePresetAction(self, completion: updatePresetMenu).start(sender)
    updatePresetMenu()
  }

  @objc private func handleRenamePresetMenuSelected(_ sender: NSMenuItem) throws {
    RenamePresetAction(self, completion: updatePresetMenu).start(sender)
    updatePresetMenu()
  }

  @objc private func handleDeletePresetMenuSelected(_ sender: NSMenuItem) throws {
    DeletePresetAction(self, completion: updatePresetMenu).start(sender)
    updatePresetMenu()
  }

  @objc private func presetMenuItemSelected(_ sender: NSMenuItem) {
    guard let userPresetsManager = userPresetsManager else { return }
    let number = tagToNumber(sender.tag)
    userPresetsManager.makeCurrentPreset(number: number)
    updatePresetMenu()
  }

  @IBAction func dismissInstructions(_ sender: NSButton) {
    UserDefaults.standard.set(true, forKey: showedInitialAlert)
    instructions.isHidden = true
  }
}

// MARK: - NSWindowDelegate

extension MainViewController: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    audioUnitHost.cleanup()
    guard let parameterTree = audioUnitHost.audioUnit?.parameterTree,
          let parameterTreeObserverToken = parameterTreeObserverToken
    else {
      return
    }
    parameterTree.removeParameterObserver(parameterTreeObserverToken)
  }
}

// MARK: - Private

private extension MainViewController {

  func showInstructions() {
#if !Dev
    if UserDefaults.standard.bool(forKey: showedInitialAlert) {
      instructions.isHidden = true
      return
    }
#endif
    instructions.isHidden = false

    // Since this is the first time to run, apply the first factory preset.
    userPresetsManager?.makeCurrentPreset(number: 0)
  }

  private func connectFilterView(_ viewController: NSViewController) {
    guard let viewController = audioUnitHost.viewController else { fatalError() }
    let filterView = viewController.view
    containerView.addSubview(filterView)
    filterView.pinToSuperviewEdges()
    self.filterView = filterView

    addChild(viewController)
    view.needsLayout = true
    containerView.needsLayout = true
  }

  private func connectParametersToControls(_ audioUnit: AUAudioUnit) {
    guard let parameterTree = audioUnit.parameterTree else {
      fatalError("FilterAudioUnit does not define any parameters.")
    }
    guard let cutoffParameter = parameterTree.parameter(withAddress: .cutoff) else {
      fatalError("Undefined cutoff parameter")
    }
    guard let resonanceParameter = parameterTree.parameter(withAddress: .resonance) else {
      fatalError("Undefined resonance parameter")
    }

    self.cutoffParameter = cutoffParameter
    self.resonanceParameter = resonanceParameter

    audioUnitHost.restore()

    resonanceSlider.minValue = Double(resonanceParameter.minValue)
    resonanceSlider.maxValue = Double(resonanceParameter.maxValue)

    cutoffValueDidChange(cutoffParameter.value)
    resonanceValueDidChange(resonanceParameter.value)

    populatePresetMenu()

    // Observe major state changes like a user selecting a user preset.
    allParameterValuesObserverToken = audioUnit.observe(\.allParameterValues) { _, _ in
      os_log(.info, log: self.log, "MainViewController - allParameterValues changed")
      DispatchQueue.performOnMain { self.updateView() }
    }

    parameterTreeObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, _ in
      guard let self = self else { return }
      os_log(.info, log: self.log, "MainViewController - parameterTree changed - %d", address)
      DispatchQueue.performOnMain { self.updateView() }
    })
  }

  func cutoffValueDidChange(_ value: AUValue) {
    cutoffSlider.floatValue = sliderLocationForFrequencyValue(value)
    cutoffTextField.stringValue = String(format: "%.f", value)
  }

  func resonanceValueDidChange(_ value: AUValue) {
    resonanceSlider.floatValue = value
    resonanceTextField.stringValue = String(format: "%.2f", value)
  }

  func saveState() {
    updatePresetMenu()
    audioUnitHost.save()
  }

  func numberToTag(_ number: Int) -> Int {
    number >= 0 ? (number + 10000) : number
  }

  func tagToNumber(_ tag: Int) -> Int {
    tag >= 10000 ? (tag - 10000) : tag
  }

  func populatePresetMenu() {
    guard let userPresetsManager = userPresetsManager else { return }
    let audioUnit = userPresetsManager.audioUnit

    os_log(.info, log: log, "populatePresetMenu")
    os_log(.info, log: log, "adding %d factory presets", audioUnit.factoryPresetsNonNil.count)

    for preset in audioUnit.factoryPresetsNonNil {
      let key = "\(preset.number + 1)"
      let menuItem = NSMenuItem(title: preset.name, action: #selector(presetMenuItemSelected(_:)), keyEquivalent: key)
      menuItem.tag = numberToTag(preset.number)
      os_log(.info, log: log, "adding %d %{public}s", menuItem.tag, preset.name)
      presetsMenu.addItem(menuItem)
    }

    updatePresetMenu()
  }

  func updatePresetMenu() {
    guard let userPresetsManager = userPresetsManager else { return }
    let active = userPresetsManager.audioUnit.currentPreset?.number ?? Int.max
    os_log(.info, log: log, "updatePresetMenu: active %d", active)

    savePresetMenuItem.isEnabled = true
    renamePresetMenuItem.isEnabled = active < 0
    deletePresetMenuItem.isEnabled = active < 0

    // Determine number of items to keep: 3 commands + divider + # of factory items
    let factoryCount = userPresetsManager.audioUnit.factoryPresetsNonNil.count
    let stockCount = 3 + 1 + factoryCount
    presetsMenu.items = presetsMenu.items.dropLast(presetsMenu.items.count - stockCount)

    if factoryCount > 0, !userPresetsManager.presets.isEmpty {
      presetsMenu.addItem(.separator())
    }

    // Recreate the user presets
    os_log(.info, log: log, "adding %d user presets", userPresetsManager.presets.count)

    for preset in userPresetsManager.presetsOrderedByName {
      let key = ""
      let menuItem = NSMenuItem(title: preset.name, action: #selector(presetMenuItemSelected(_:)), keyEquivalent: key)
      menuItem.tag = numberToTag(preset.number)
      os_log(.info, log: log, "adding %d %{public}s", menuItem.tag, preset.name)
      presetsMenu.addItem(menuItem)
    }

    // Finally checkmark any item that matches the current preset
    for (index, item) in presetsMenu.items.enumerated() {
      item.state = (index > 3 && tagToNumber(item.tag) == active) ? .on : .off
    }
  }

  func updateView() {
    guard let audioUnit = audioUnitHost.audioUnit,
          let parameterTree = audioUnit.parameterTree,
          let cutoffParameter = parameterTree.parameter(withAddress: .cutoff),
          let resonanceParameter = parameterTree.parameter(withAddress: .resonance)
    else {
      return
    }

    cutoffValueDidChange(cutoffParameter.value)
    resonanceValueDidChange(resonanceParameter.value)
    saveState()
  }

  func sliderLocationForFrequencyValue(_ frequency: Float) -> Float {
    Foundation.log(((frequency - FilterView.hertzMin) / (FilterView.hertzMax - FilterView.hertzMin)) *
      cutoffSliderMaxValuePower2Minus1 + 1.0) / Foundation.log(2)
  }

  func frequencyValueForSliderLocation(_ location: Float) -> Float {
    ((pow(2, location) - 1) / cutoffSliderMaxValuePower2Minus1) * (FilterView.hertzMax - FilterView.hertzMin) +
      FilterView.hertzMin
  }
}

// MARK: - Alert / Prompt

extension MainViewController {

  func notify(title: String, message: String) {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = title
    alert.informativeText = message

    alert.addButton(withTitle: "OK")
    alert.beginSheetModal(for: view.window!) { _ in }
    alert.runModal()
  }

  func yesOrNo(title: String, message: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    return alert.runModal() == .alertFirstButtonReturn
  }
}
