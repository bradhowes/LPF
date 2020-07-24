// Copyright © 2020 Brad Howes. All rights reserved.

import Cocoa
import AVFoundation
import LowPassFilterFramework

final class MainViewController: NSViewController {

    private let cutoffSliderMinValue = 0.0
    private let cutoffSliderMaxValue = 9.0
    private lazy var cutoffSliderMaxValuePower2Minus1 = Float(pow(2, cutoffSliderMaxValue) - 1)

    private let audioUnitManager = AudioUnitManager(componentDescription: FilterAudioUnit.componentDescription)

    private var playButton: NSButton?
    private var playMenuItem: NSMenuItem?

    @IBOutlet var cutoffSlider: NSSlider!
    @IBOutlet var cutoffTextField: NSTextField!

    @IBOutlet var resonanceSlider: NSSlider!
    @IBOutlet var resonanceTextField: NSTextField!

    @IBOutlet var containerView: NSView!
    private var filterView: NSView?

    private var windowController: MainWindowController? { view.window?.windowController as? MainWindowController }
    private var appDelegate: AppDelegate? { NSApplication.shared.delegate as? AppDelegate }

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

private extension MainViewController {

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

    private func sliderLocationForFrequencyValue(_ frequency: Float) -> Float {
        log(((frequency - FilterView.hertzMin) / (FilterView.hertzMax - FilterView.hertzMin)) *
            cutoffSliderMaxValuePower2Minus1 + 1.0) / log(2)
    }

    private func frequencyValueForSliderLocation(_ location: Float) -> Float {
        ((pow(2, location) - 1) / cutoffSliderMaxValuePower2Minus1) * (FilterView.hertzMax - FilterView.hertzMin) +
            FilterView.hertzMin
    }
}

extension MainViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { audioUnitManager.cleanup() }
}

extension MainViewController: AudioUnitManagerDelegate {

    func audioUnitCutoffParameterDeclared(_ parameter: AUParameter) {
    }

    func audioUnitResonanceParameterDeclared(_ parameter: AUParameter) {
        resonanceSlider.minValue = Double(parameter.minValue)
        resonanceSlider.maxValue = Double(parameter.maxValue)
    }

    func audioUnitViewControllerDeclared(_ viewController: NSViewController?) {
        guard let viewController = viewController else { return }
        filterView = viewController.view
        containerView.addSubview(filterView!)
        addChild(viewController)
        view.needsLayout = true
        populatePresetMenu()
    }

    func cutoffValueDidChange(_ value: Float) {
        cutoffSlider.floatValue = sliderLocationForFrequencyValue(value)
        cutoffTextField.text = String(format: "%.f", value)
    }

    func resonanceValueDidChange(_ value: Float) {
        resonanceSlider.floatValue = value
        resonanceTextField.text = String(format: "%.2f", value)
    }
}
