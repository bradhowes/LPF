// Copyright © 2020 Brad Howes. All rights reserved.

import Cocoa
import AVFoundation
import LowPassFilterFramework

final class MainViewController: NSViewController {

    private let cutoffSliderMinValue = 0.0
    private let cutoffSliderMaxValue = 9.0
    private lazy var cutoffSliderMaxValuePower2Minus1 = Float(pow(2, cutoffSliderMaxValue) - 1)

    private let audioUnitManager = AudioUnitManager<FilterViewController>(
        componentDescription: FilterAudioUnit.componentDescription, appExt: "LPF")

    private var playButton: NSButton?
    private var playMenuItem: NSMenuItem?

    private var savePresetMenuItem: NSMenuItem?

    @IBOutlet var cutoffSlider: NSSlider!
    @IBOutlet var cutoffTextField: NSTextField!

    @IBOutlet var resonanceSlider: NSSlider!
    @IBOutlet var resonanceTextField: NSTextField!

    @IBOutlet var containerView: NSView!
    private var filterView: NSView?

    private var windowController: MainWindowController? { view.window?.windowController as? MainWindowController }
    private var appDelegate: AppDelegate? { NSApplication.shared.delegate as? AppDelegate }
}

// MARK: - View Management
extension MainViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        audioUnitManager.delegate = self
        cutoffSlider.minValue = cutoffSliderMinValue
        cutoffSlider.maxValue = cutoffSliderMaxValue
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.delegate = self
        playButton = windowController?.playButton
        playMenuItem = appDelegate?.playMenuItem
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard let filterView = filterView else { return }
        filterView.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: containerView.frame.size)
    }
}

// MARK: - AudioUnitManagerDelegate
extension MainViewController: AudioUnitManagerDelegate {

    func audioUnitCutoffParameterDeclared(_ parameter: AUParameter) {
    }

    func audioUnitResonanceParameterDeclared(_ parameter: AUParameter) {
        resonanceSlider.minValue = Double(parameter.minValue)
        resonanceSlider.maxValue = Double(parameter.maxValue)
    }

    func audioUnitViewControllerDeclared(_ viewController: NSViewController) {
        guard let viewController = viewController as? FilterViewController else {
            fatalError("unexpected view controller type")
        }

        filterView = viewController.view
        containerView.addSubview(filterView!)
        addChild(viewController)
        view.needsLayout = true
        populatePresetMenu()
    }

    func cutoffValueDidChange(_ value: Float) {
        cutoffSlider.floatValue = sliderLocationForFrequencyValue(value)
        cutoffTextField.text = String(format: "%.f", value)
        clearPresetCheck()
    }

    func resonanceValueDidChange(_ value: Float) {
        resonanceSlider.floatValue = value
        resonanceTextField.text = String(format: "%.2f", value)
        clearPresetCheck()
    }
}

// MARK: - UI Actions
extension MainViewController {

    @IBAction private func togglePlay(_ sender: NSButton) {
        audioUnitManager.togglePlayback()
        playButton?.state = audioUnitManager.isPlaying ? .on : .off
        playButton?.title = audioUnitManager.isPlaying ? "Stop" : "Play"
        playMenuItem?.title = audioUnitManager.isPlaying ? "Stop" : "Play"
    }

    @IBAction private func cutoffSliderValueChanged(_ sender: NSSlider) {
        audioUnitManager.cutoffValue = frequencyValueForSliderLocation(sender.floatValue)
    }

    @IBAction private func resonanceSliderValueChanged(_ sender: NSSlider) {
        audioUnitManager.resonanceValue = sender.floatValue
    }
}

// MARK: - Presets
private extension MainViewController {

    private func populatePresetMenu() {
        guard let presetMenu = NSApplication.shared.mainMenu?.item(withTag: 666)?.submenu else { return }

        savePresetMenuItem = presetMenu.items[0]
        savePresetMenuItem?.isEnabled = true
        savePresetMenuItem?.target = self
        savePresetMenuItem?.action = #selector(handleSavePresetMenuSelection(_:))

        for preset in audioUnitManager.factoryPresets ?? [] {
            let keyEquivalent = "\(preset.number + 1)"
            let menuItem = NSMenuItem(title: preset.name,
                                      action: #selector(handlePresetMenuSelection(_:)),
                                      keyEquivalent: keyEquivalent)
            menuItem.tag = preset.number
            print(preset.number)
            presetMenu.addItem(menuItem)
        }

        for preset in audioUnitManager.userPresets ?? [] {
            let keyEquivalent = ""
            let menuItem = NSMenuItem(title: preset.name,
                                      action: #selector(handlePresetMenuSelection(_:)),
                                      keyEquivalent: keyEquivalent)
            menuItem.tag = preset.number
            print(preset.number)
            presetMenu.addItem(menuItem)
        }

        if let currentPreset = audioUnitManager.currentPreset {
            presetMenu.item(at: currentPreset.number + 2)?.state = .on
        }
    }

    @objc
    private func handleSavePresetMenuSelection(_ sender: NSMenuItem) throws {
//        guard let audioUnit = audioUnitManager.auAudioUnit else { return }
//        guard let presetMenu = NSApplication.shared.mainMenu?.item(withTag: 666)?.submenu else { return }
//
//        let preset = AUAudioUnitPreset()
//        let index = audioUnitManager.presets.count
//        preset.name = "Preset \(index + 1)"
//        preset.number = -index
//        try audioUnit.saveUserPreset(preset)
//        let menuItem = NSMenuItem(title: preset.name,
//                                  action: #selector(handlePresetMenuSelection(_:)),
//                                  keyEquivalent: "")
//        menuItem.tag = preset.number
//        presetMenu.addItem(menuItem)
//        audioUnitManager.presets.append(preset)
    }

    @objc
    private func handlePresetMenuSelection(_ sender: NSMenuItem) {
        sender.menu?.items.forEach { $0.state = .off }
        if sender.tag >= 0 {
            audioUnitManager.currentPreset = audioUnitManager.factoryPresets![sender.tag]
        }
        else {
            audioUnitManager.currentPreset = audioUnitManager.userPresets![abs(sender.tag) - 1]
        }
        sender.state = .on
    }
}

// MARK: NSWindowDelegate
extension MainViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { audioUnitManager.cleanup() }
}

// MARK: - Private
extension MainViewController {

    private func sliderLocationForFrequencyValue(_ frequency: Float) -> Float {
        log(((frequency - FilterView.hertzMin) / (FilterView.hertzMax - FilterView.hertzMin)) *
            cutoffSliderMaxValuePower2Minus1 + 1.0) / log(2)
    }

    private func frequencyValueForSliderLocation(_ location: Float) -> Float {
        ((pow(2, location) - 1) / cutoffSliderMaxValuePower2Minus1) * (FilterView.hertzMax - FilterView.hertzMin) +
            FilterView.hertzMin
    }

    private func clearPresetCheck() {
        guard let presetMenu = NSApplication.shared.mainMenu?.item(withTag: 666)?.submenu else { return }
        guard let audioUnit = audioUnitManager.auAudioUnit else { return }
        guard !audioUnit.usingPreset else { return }
        presetMenu.items.forEach { $0.state = .off }
    }
}
