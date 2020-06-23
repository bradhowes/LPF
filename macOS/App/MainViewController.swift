// Copyright © 2020 Brad Howes. All rights reserved.

import Cocoa
import LowPassFilterFramework

class MainViewController: NSViewController {

    let audioUnitManager = AudioUnitManager()

    @IBOutlet var playButton: NSButton!
    @IBOutlet var toggleButton: NSButton!

    @IBOutlet var cutoffSlider: NSSlider!
    @IBOutlet var cutoffTextField: NSTextField!

    @IBOutlet var resonanceSlider: NSSlider!
    @IBOutlet var resonanceTextField: NSTextField!

    @IBOutlet var containerView: NSView!

    override func viewDidLoad() {
        super.viewDidLoad()
        embedPlugInView()
        populatePresetMenu()
        audioUnitManager.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.delegate = self
    }

    @IBAction private func togglePlay(_ sender: NSButton) { audioUnitManager.togglePlayback() }

    @IBAction private func toggleView(_ sender: NSButton) { audioUnitManager.toggleView() }

    @IBAction private func cutoffSliderValueChanged(_ sender: NSSlider) {
        audioUnitManager.cutoffValue = frequencyValueForSliderLocation(sender.floatValue)
    }

    @IBAction private func resonanceSliderValueChanged(_ sender: NSSlider) {
        audioUnitManager.resonanceValue = sender.floatValue
    }
}

private extension MainViewController {

    private func embedPlugInView() {
        guard let controller = audioUnitManager.viewController else {
            fatalError("Could not load audio unit's view controller.")
        }

        addChild(controller)
        containerView.addSubview(controller.view)
        controller.view.pinToSuperviewEdges()
    }

    private func populatePresetMenu() {
        guard let presetMenu = NSApplication.shared.mainMenu?.item(withTag: 666)?.submenu else { return }
        for preset in audioUnitManager.presets {
            let menuItem = NSMenuItem(title: preset.name,
                                      action: #selector(handleMenuSelection(_:)),
                                      keyEquivalent: "\(preset.number + 1)")
            menuItem.tag = preset.number
            presetMenu.addItem(menuItem)
        }

        if let currentPreset = audioUnitManager.currentPreset {
            presetMenu.item(at: currentPreset.number)?.state = .on
        }
    }

    @objc
    private func handleMenuSelection(_ sender: NSMenuItem) {
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
        audioUnitManager.currentPreset = audioUnitManager.presets[sender.tag]
    }

    private func logValueForNumber(_ number: Float) -> Float { log(number) / log(2) }

    private func frequencyValueForSliderLocation(_ location: Float) -> Float {
        ((pow(2, location) - 1) / 511) * (FilterView.hertzMax - FilterView.hertzMin) + FilterView.hertzMin
    }
}

extension MainViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { audioUnitManager.cleanup() }
}

extension MainViewController: AudioUnitManagerDelegate {

    func cutoffValueDidChange(_ value: Float) {
        let normalizedValue = ((value - FilterView.hertzMin) / (FilterView.hertzMax - FilterView.hertzMin)) * 511.0 + 1.0
        cutoffSlider.floatValue = Float(logValueForNumber(normalizedValue))
        cutoffTextField.text = String(format: "%.f", value)
    }

    func resonanceValueDidChange(_ value: Float) {
        resonanceSlider.floatValue = value
        resonanceTextField.text = String(format: "%.2f", value)
    }
}
