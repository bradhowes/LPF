// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import LowPassFilterFramework
import os.log
import UIKit

final class MainViewController: UIViewController {
  private static let log = Logging.logger("MainViewController")
  private var log: OSLog { Self.log }

  private let showedInitialAlert = "showedInitialAlert"

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
  @IBOutlet var userPresetsMenuButton: UIButton!
  @IBOutlet weak var instructions: UIView!

  private lazy var renameAction = UIAction(title: "Rename",
                                           handler: RenamePresetAction(self, completion: updatePresetMenu).start(_:))
  private lazy var deleteAction = UIAction(title: "Delete",
                                           handler: DeletePresetAction(self, completion: updatePresetMenu).start(_:))
  private lazy var saveAction = UIAction(title: "Save",
                                         handler: SavePresetAction(self, completion: updatePresetMenu).start(_:))

  private var allParameterValuesObserverToken: NSKeyValueObservation?
  private var parameterTreeObserverToken: AUParameterObserverToken?
}

// MARK: - View Management

extension MainViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    guard let delegate = UIApplication.shared.delegate as? AppDelegate else { fatalError() }
    delegate.setMainViewController(self)

    let version = Bundle.main.releaseVersionNumber
    reviewButton.setTitle(version, for: .normal)

    cutoffSlider.minimumValue = cutoffSliderMinValue
    cutoffSlider.maximumValue = cutoffSliderMaxValue

    presetSelection.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
    presetSelection.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)

    instructions.layer.borderWidth = 4
    instructions.layer.borderColor = UIColor.systemOrange.cgColor
    instructions.layer.cornerRadius = 16
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    playButton.setImage(UIImage(named: "stop"), for: [.highlighted, .selected])
    bypassButton.setImage(UIImage(named: "bypassed"), for: [.highlighted, .selected])

    audioUnitHost.delegate = self
  }

  public func stopPlaying() {
    audioUnitHost.cleanup()
  }
}

// MARK: - Actions

extension MainViewController {

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

  @IBAction func dismissInstructions(_ sender: Any) {
    instructions.isHidden = true
    UserDefaults.standard.set(true, forKey: showedInitialAlert)
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
    let message = "Unable to load the AUv3 component. \(error.description)"
    let controller = UIAlertController(title: "AUv3 Failure", message: message, preferredStyle: .alert)
    present(controller, animated: true)
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

  func connectFilterView(_ viewController: ViewController) {
    let filterView = viewController.view!
    containerView.addSubview(filterView)
    filterView.pinToSuperviewEdges()

    addChild(viewController)
    view.setNeedsLayout()
    containerView.setNeedsLayout()
  }

  func connectParametersToControls(_ audioUnit: AUAudioUnit) {
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

  func usePreset(number: Int) {
    guard let userPresetManager = userPresetsManager else { return }
    userPresetManager.makeCurrentPreset(number: number)
    updatePresetMenu()
  }

  func updatePresetMenu() {
    guard let userPresetsManager = userPresetsManager else { return }
    let active = userPresetsManager.audioUnit.currentPreset?.number ?? Int.max

    let factoryPresets = userPresetsManager.audioUnit.factoryPresetsNonNil.map { (preset: AUAudioUnitPreset) -> UIAction in
      let action = UIAction(title: preset.name, handler: { _ in self.usePreset(number: preset.number) })
      action.state = active == preset.number ? .on : .off
      return action
    }

    let factoryPresetsMenu = UIMenu(title: "Factory", options: .displayInline, children: factoryPresets)

    let userPresets = userPresetsManager.presetsOrderedByName.map { (preset: AUAudioUnitPreset) -> UIAction in
      let action = UIAction(title: preset.name, handler: { _ in self.usePreset(number: preset.number) })
      action.state = active == preset.number ? .on : .off
      return action
    }

    let userPresetsMenu = UIMenu(title: "User", options: .displayInline, children: userPresets)

    let actionsGroup = UIMenu(title: "Actions", options: .displayInline,
                              children: active < 0 ? [saveAction, renameAction, deleteAction] : [saveAction])

    let menu = UIMenu(title: "Presets", options: [], children: [userPresetsMenu, factoryPresetsMenu, actionsGroup])

    userPresetsMenuButton.menu = menu
    userPresetsMenuButton.showsMenuAsPrimaryAction = true
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

    updatePresetMenu()
    updatePresetSelection(audioUnit)

    audioUnitHost.save()
  }

  func updatePresetSelection(_ audioUnit: AUAudioUnit) {
    if let presetNumber = audioUnit.currentPreset?.number {
      os_log(.info, log: log, "updatePresetSelection: %d", presetNumber)
      presetSelection.selectedSegmentIndex = presetNumber
    } else {
      presetSelection.selectedSegmentIndex = -1
    }
  }

  func cutoffValueDidChange(_ value: Float) {
    cutoffSlider.value = sliderLocationForFrequencyValue(value)
    cutoffValue.text = String(format: "%.2f", value)
  }

  func resonanceValueDidChange(_ value: Float) {
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

// MARK: - Alerts and Prompts

extension MainViewController {

  func notify(title: String, message: String) {
    let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
    controller.addAction(UIAlertAction(title: "OK", style: .default))
    present(controller, animated: true)
  }

  func yesOrNo(title: String, message: String, continuation: @escaping (UIAlertAction) -> Void) {
    let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
    controller.addAction(.init(title: "Continue", style: .default, handler: continuation))
    controller.addAction(.init(title: "Cancel", style: .cancel))
    present(controller, animated: true)
  }
}
