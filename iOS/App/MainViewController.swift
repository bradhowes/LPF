// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import LowPassFilterFramework
import os.log
import UIKit

final class MainViewController: UIViewController {
  private static let log = Logging.logger("MainViewController")
  private var log: OSLog { Self.log }

  private let cutoffSliderMinValue: Float = 0.0
  private let cutoffSliderMaxValue: Float = 9.0
  private lazy var cutoffSliderMaxValuePower2Minus1 = Float(pow(2, cutoffSliderMaxValue) - 1)

  private let audioUnitHost = AudioUnitHost(componentDescription: FilterAudioUnit.componentDescription)
  internal var userPresetsManager: UserPresetsManager?

  private var cutoffParameter: AUParameter?
  private var resonanceParameter: AUParameter?

  @IBOutlet var reviewButton: UIButton!
  @IBOutlet var playButton: UIButton!
  @IBOutlet var bypassButton: UIButton!
  @IBOutlet var cutoffSlider: UISlider!
  @IBOutlet var cutoffValue: UILabel!
  @IBOutlet var resonanceSlider: UISlider!
  @IBOutlet var resonanceValue: UILabel!
  @IBOutlet var containerView: UIView!
  @IBOutlet var presetSelection: UISegmentedControl!
  @IBOutlet var userPresetsMenu: UIButton!

  private lazy var renameAction = UIAction(title: "Rename", handler: RenamePresetAction(self).start(_:))
  private lazy var deleteAction = UIAction(title: "Delete", handler: DeletePresetAction(self).start(_:))
  private lazy var saveAction = UIAction(title: "Save", handler: SavePresetAction(self).start(_:))

  private var allParameterValuesObserverToken: NSKeyValueObservation?
  private var parameterTreeObserverToken: AUParameterObserverToken?

  override func viewDidLoad() {
    super.viewDidLoad()
    // audioUnitHost = AudioUnitHost(componentDescription: FilterAudioUnit.componentDescription)
    guard let delegate = UIApplication.shared.delegate as? AppDelegate else { fatalError() }
    delegate.setMainViewController(self)

    let version = Bundle.main.releaseVersionNumber
    reviewButton.setTitle(version, for: .normal)

    cutoffSlider.minimumValue = cutoffSliderMinValue
    cutoffSlider.maximumValue = cutoffSliderMaxValue

    presetSelection.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
    presetSelection.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    playButton.setImage(UIImage(named: "stop"), for: [.highlighted, .selected])
    bypassButton.setImage(UIImage(named: "bypassed"), for: [.highlighted, .selected])

    // Keep last
    audioUnitHost.delegate = self
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    let showedAlertKey = "showedInitialAlert"
    guard UserDefaults.standard.bool(forKey: showedAlertKey) == false else { return }
    UserDefaults.standard.set(true, forKey: showedAlertKey)
    let alert = UIAlertController(title: "AUv3 Component Installed",
                                  message: nil, preferredStyle: .alert)
    alert.message =
      """
      The AUv3 component 'SimplyLowPass' is now available on your device and can be used in other AUv3 host apps such as
      GarageBand and AUM.You can continue to use this app to experiment, but you do not need to have it running in order to
      access the AUv3 component in other apps. If you delete this app from your device, the AUv3 component will no longer be
      available for use in other host applications.
      """
    alert.addAction(
      UIAlertAction(title: "OK", style: .default, handler: { _ in })
    )
    present(alert, animated: true)
  }

  public func stopPlaying() {
    audioUnitHost.cleanup()
  }

  @IBAction private func togglePlay(_ sender: UIButton) {
    let isPlaying = audioUnitHost.togglePlayback()
    sender.isSelected = isPlaying
    sender.tintColor = isPlaying ? .systemYellow : .systemTeal
  }

  @IBAction private func toggleBypass(_ sender: UIButton) {
    let wasBypassed = audioUnitHost.audioUnit?.shouldBypassEffect ?? false
    let isBypassed = !wasBypassed
    audioUnitHost.audioUnit?.shouldBypassEffect = isBypassed
    sender.isSelected = isBypassed
  }

  @IBAction private func cutoffSliderValueChanged(_ sender: UISlider) {
    cutoffParameter?.value = frequencyValueForSliderLocation(sender.value)
    userPresetsManager?.clearCurrentPreset()
  }

  @IBAction private func resonanceSliderValueChanged(_ sender: UISlider) {
    resonanceParameter?.value = sender.value
    userPresetsManager?.clearCurrentPreset()
  }

  @IBAction private func visitAppStore(_ sender: UIButton) {
    let appStoreId = Bundle.main.appStoreId
    guard let url = URL(string: "https://itunes.apple.com/app/id\(appStoreId)") else {
      fatalError("Expected a valid URL")
    }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
  }

  @IBAction func useFactoryPreset(_ sender: UISegmentedControl? = nil) {
    userPresetsManager?.makeCurrentPreset(number: presetSelection.selectedSegmentIndex)
  }

  @IBAction private func reviewApp(_ sender: UIButton) {
    AppStore.visitAppStore()
  }
}

extension MainViewController: AudioUnitHostDelegate {
  func connected(audioUnit: AUAudioUnit, viewController: ViewController) {
    userPresetsManager = .init(for: audioUnit)
    connectFilterView(viewController)
    connectParametersToControls(audioUnit)
  }

  func failed(error: AudioUnitHostError) {
    let message = "Unable to load the AUv3 component. \(error.description)"
    let controller = UIAlertController(title: "AUv3 Failure", message: message, preferredStyle: .alert)
    present(controller, animated: true)
  }

  private func connectFilterView(_ viewController: ViewController) {
    let filterView = viewController.view!
    containerView.addSubview(filterView)
    filterView.pinToSuperviewEdges()

    addChild(viewController)
    view.setNeedsLayout()
    containerView.setNeedsLayout()
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

    resonanceSlider.minimumValue = resonanceParameter.minValue
    resonanceSlider.maximumValue = resonanceParameter.maxValue

    audioUnitHost.restore()
    updatePresetMenu()

    cutoffValueDidChange(cutoffParameter.value)
    resonanceValueDidChange(resonanceParameter.value)

    allParameterValuesObserverToken = audioUnit.observe(\.allParameterValues) { _, _ in
      os_log(.info, log: self.log, "allParameterValues changed")
      DispatchQueue.performOnMain { self.updateView() }
    }

    parameterTreeObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, _ in
      guard let self = self else { return }
      os_log(.info, log: self.log, "MainViewController - parameterTree changed - %d", address)
      DispatchQueue.performOnMain { self.updateView() }
    })
  }
}

extension MainViewController {

  private func useUserPreset(name: String) {
    guard let userPresetManager = userPresetsManager else { return }
    userPresetManager.makeCurrentPreset(name: name)
    updatePresetMenu()
  }

  func updatePresetMenu() {
    guard let userPresetsManager = userPresetsManager else { return }
    let active = userPresetsManager.audioUnit.currentPreset?.number ?? Int.max

    os_log(.info, log: log, "updatePresetMenu: active %d", active)
    let presets = userPresetsManager.presetsOrderedByName.map { (preset: AUAudioUnitPreset) -> UIAction in
      os_log(.info, log: log, "preset: %{public}s %d", preset.name, preset.number)
      let action = UIAction(title: preset.name, handler: { _ in self.useUserPreset(name: preset.name) })
      action.state = active == preset.number ? .on : .off
      return action
    }

    let actionsGroup = UIMenu(title: "Actions", options: [],
                              children: active < 0 ? [saveAction, renameAction, deleteAction] : [saveAction])
    let menu = UIMenu(title: "User Presets", options: [], children: presets + [actionsGroup])
    userPresetsMenu.menu = menu
    userPresetsMenu.showsMenuAsPrimaryAction = true
  }

  private func updateView() {
    guard let audioUnit = audioUnitHost.audioUnit,
          let parameterTree = audioUnit.parameterTree,
          let cutoffParameter = parameterTree.parameter(withAddress: .cutoff),
          let resonanceParameter = parameterTree.parameter(withAddress: .resonance)
    else {
      return
    }

    cutoffValueDidChange(cutoffParameter.value)
    resonanceValueDidChange(resonanceParameter.value)

    updatePresetMenu()
    updatePresetSelection(audioUnit)

    audioUnitHost.save()
  }

  private func updatePresetSelection(_ audioUnit: AUAudioUnit) {
    if let presetNumber = audioUnit.currentPreset?.number {
      os_log(.info, log: log, "updatePresetSelection: %d", presetNumber)
      presetSelection.selectedSegmentIndex = presetNumber
    } else {
      presetSelection.selectedSegmentIndex = -1
    }
  }

  private func cutoffValueDidChange(_ value: Float) {
    cutoffSlider.value = sliderLocationForFrequencyValue(value)
    cutoffValue.text = String(format: "%.2f", value)
  }

  private func resonanceValueDidChange(_ value: Float) {
    resonanceSlider.value = value
    resonanceValue.text = String(format: "%.2f", value)
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

extension MainViewController {
  func notify(_ title: String, message: String) {
    let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
    controller.addAction(UIAlertAction(title: "OK", style: .default))
    present(controller, animated: true)
  }

  func yesOrNo(_ title: String, message: String, continuation: @escaping (UIAlertAction) -> Void) {
    let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
    controller.addAction(.init(title: "Continue", style: .default, handler: continuation))
    controller.addAction(.init(title: "Cancel", style: .cancel))
    present(controller, animated: true)
  }
}
