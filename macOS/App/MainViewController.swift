// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import Cocoa
import LowPassFilterFramework
import os.log

final class MainViewController: NSViewController {
  private static let log = Logging.logger("MainViewController")
  private var log: OSLog { Self.log }

  private let cutoffSliderMinValue: Double = 0.0
  private let cutoffSliderMaxValue: Double = 9.0
  private lazy var cutoffSliderMaxValuePower2Minus1 = Float(pow(2, cutoffSliderMaxValue) - 1)
  
  private let audioUnitHost = AudioUnitHost(componentDescription: FilterAudioUnit.componentDescription)
  internal var userPresetsManager: UserPresetsManager?

  private var cutoffParameter: AUParameter?
  private var resonanceParameter: AUParameter?
  
  private var playButton: NSButton!
  private var bypassButton: NSButton!
  private var presetsMenu: NSMenu!
  private var playMenuItem: NSMenuItem!
  private var bypassMenuItem: NSMenuItem!

  @IBOutlet var cutoffSlider: NSSlider!
  @IBOutlet var cutoffTextField: NSTextField!
  @IBOutlet var resonanceSlider: NSSlider!
  @IBOutlet var resonanceTextField: NSTextField!
  @IBOutlet var containerView: NSView!
  
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
  }

  override func viewWillAppear() {
    super.viewWillAppear()

    guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { fatalError() }
    presetsMenu = appDelegate.presetsMenu
    guard presetsMenu != nil else { fatalError() }

    playMenuItem = appDelegate.playMenuItem
    bypassMenuItem = appDelegate.bypassMenuItem
    guard playMenuItem != nil, bypassMenuItem != nil else { fatalError() }
    bypassMenuItem.isEnabled = false

    guard let windowController = view.window?.windowController as? MainWindowController else { fatalError() }
    view.window?.delegate = self

    playButton = windowController.playButton
    bypassButton = windowController.bypassButton
    bypassButton.isEnabled = false

    guard let savePresetMenuItem = appDelegate.savePresetMenuItem else { fatalError() }
    savePresetMenuItem.target = self
    savePresetMenuItem.action = #selector(handleSavePresetMenuSelection(_:))

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
The AUv3 component 'SimplyLowPass' is now available on your device and can be used in other AUv3 host apps such as GarageBand and Logic.

You can continue to use this app to experiment, but you do not need to have it running in order to access the AUv3 component in other apps.

If you delete this app from your device, the AUv3 component will no longer be available for use in other host applications.
"""
    alert.addButton(withTitle: "OK")
    alert.beginSheetModal(for: view.window!){ _ in }
  }
}

extension MainViewController: AudioUnitHostDelegate {
  
  func connected(audioUnit: AUAudioUnit, viewController: ViewController) {
    userPresetsManager = .init(for: audioUnit)
    connectFilterView(viewController)
    connectParametersToControls(audioUnit)
  }

  func failed(error: AudioUnitHostError) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "AUv3 Failure"
    alert.informativeText = "Unable to load the AUv3 component. \(error.description)"
    alert.addButton(withTitle: "OK")
    alert.beginSheetModal(for: view.window!){ _ in self.view.window?.close() }
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

    populatePresetMenu(audioUnit)

    // Observe major state changes like a user selecting a user preset.
    allParameterValuesObserverToken = audioUnit.observe(\.allParameterValues) { _, _ in
      os_log(.info, log: self.log, "MainViewController - allParameterValues changed")
      DispatchQueue.performOnMain { self.updateView() }
    }

    parameterTreeObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, value in
      guard let self = self else { return }
      os_log(.info, log: self.log, "MainViewController - parameterTree changed - %d", address)
      DispatchQueue.performOnMain { self.updateView() }
    })
  }

}

// MARK: - UI Actions

extension MainViewController {
  
  @IBAction private func togglePlay(_ sender: NSButton) {
    audioUnitHost.togglePlayback()
    playButton?.state = audioUnitHost.isPlaying ? .on : .off
    playButton?.title = audioUnitHost.isPlaying ? "Stop" : "Play"
    playMenuItem?.title = audioUnitHost.isPlaying ? "Stop" : "Play"
    bypassButton?.isEnabled = audioUnitHost.isPlaying
    bypassMenuItem?.isEnabled = audioUnitHost.isPlaying

    if !audioUnitHost.isPlaying && (audioUnitHost.audioUnit?.shouldBypassEffect ?? false) {
      toggleBypass(sender)
    }
  }
  
  @IBAction private func toggleBypass(_ sender: NSButton) {
    let wasBypassed = audioUnitHost.audioUnit?.shouldBypassEffect ?? false
    let isBypassed = !wasBypassed
    audioUnitHost.audioUnit?.shouldBypassEffect = isBypassed
    bypassButton?.state = isBypassed ? .on : .off
    bypassButton?.title = isBypassed ? "Resume" : "Bypass"
    bypassMenuItem?.title = isBypassed ? "Resume" : "Bypass"
  }
  
  @IBAction private func cutoffSliderValueChanged(_ sender: NSSlider) {
    cutoffParameter?.setValue(frequencyValueForSliderLocation(sender.floatValue), originator: parameterTreeObserverToken)
    userPresetsManager?.clearCurrentPreset()
  }
  
  @IBAction private func resonanceSliderValueChanged(_ sender: NSSlider) {
    resonanceParameter?.setValue(sender.floatValue, originator: parameterTreeObserverToken)
    userPresetsManager?.clearCurrentPreset()
  }
  
  @objc private func handleSavePresetMenuSelection(_ sender: NSMenuItem) throws {
    guard let audioUnit = audioUnitHost.audioUnit else { return }

    let preset = AUAudioUnitPreset()
    let index = audioUnit.userPresets.count + 1
    preset.name = "User Preset \(index)"
    preset.number = -index

    do {
      try audioUnit.saveUserPreset(preset)
    } catch {
      print(error.localizedDescription)
      return
    }

    let menuItem = NSMenuItem(title: preset.name, action: #selector(presetMenuSelection(_:)), keyEquivalent: "")
    menuItem.tag = preset.number
    presetsMenu.addItem(menuItem)
  }

  @objc private func presetMenuSelection(_ sender: NSMenuItem) {
    guard let audioUnit = audioUnitHost.audioUnit else { return }
    sender.menu?.items.forEach { $0.state = .off }
    if sender.tag >= 0 {
      audioUnit.currentPreset = audioUnit.factoryPresetsArray[sender.tag]
    }
    else {
      audioUnit.currentPreset = audioUnit.userPresets.reversed()[-sender.tag - 1]
    }

    updatePresetMenu()
  }
}

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

extension MainViewController {
  
  public func updateView() {
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

  public func cutoffValueDidChange(_ value: AUValue) {
    cutoffSlider.floatValue = sliderLocationForFrequencyValue(value)
    cutoffTextField.stringValue = String(format: "%.f", value)
  }

  public func resonanceValueDidChange(_ value: AUValue) {
    resonanceSlider.floatValue = value
    resonanceTextField.stringValue = String(format: "%.2f", value)
  }

  private func saveState() {
    updatePresetMenu()
    audioUnitHost.save()
  }

  private func populatePresetMenu(_ audioUnit: AUAudioUnit) {
    os_log(.info, log: self.log, "populatePresetMenu")

    os_log(.info, log: self.log, "adding %d factory presets", audioUnit.factoryPresetsArray.count)
    for preset in audioUnit.factoryPresetsArray {
      let key = "\(preset.number + 1)"
      let menuItem = NSMenuItem(title: preset.name, action: #selector(presetMenuSelection(_:)), keyEquivalent: key)
      menuItem.tag = preset.number
      os_log(.info, log: self.log, "adding %d %{public}s", menuItem.tag, preset.name)
      presetsMenu.addItem(menuItem)
    }

    if audioUnit.userPresets.isEmpty {
      return
    }

    presetsMenu.addItem(.separator())

    os_log(.info, log: self.log, "adding %d user presets", audioUnit.userPresets.count)
    for preset in audioUnit.userPresets.reversed() {
      let key = ""
      let menuItem = NSMenuItem(title: preset.name, action: #selector(presetMenuSelection(_:)), keyEquivalent: key)
      menuItem.tag = preset.number
      os_log(.info, log: self.log, "adding %d %{public}s", menuItem.tag, preset.name)
      presetsMenu.addItem(menuItem)
    }

    updatePresetMenu()
  }

  private func updatePresetMenu() {
    guard let audioUnit = audioUnitHost.audioUnit else { return }
    presetsMenu.items.forEach { $0.state = .off }
    if let presetNumber = audioUnit.currentPreset?.number {
      os_log(.info, log: self.log, "updatePresetMenu: %d", presetNumber)
      let index = presetNumber >= 0 ? (presetNumber + 2) : audioUnit.factoryPresetsArray.count + 2 - presetNumber
      presetsMenu.item(at: index)?.state = .on
    }
  }

  private func sliderLocationForFrequencyValue(_ frequency: Float) -> Float {
    Foundation.log(((frequency - FilterView.hertzMin) / (FilterView.hertzMax - FilterView.hertzMin)) *
                   cutoffSliderMaxValuePower2Minus1 + 1.0) / Foundation.log(2)
  }
  
  private func frequencyValueForSliderLocation(_ location: Float) -> Float {
    ((pow(2, location) - 1) / cutoffSliderMaxValuePower2Minus1) * (FilterView.hertzMax - FilterView.hertzMin) +
    FilterView.hertzMin
  }
}
