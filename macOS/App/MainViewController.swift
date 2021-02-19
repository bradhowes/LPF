// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import Cocoa
import LowPassFilterFramework
import os

final class MainViewController: NSViewController {

    private let cutoffSliderMinValue: Double = 0.0
    private let cutoffSliderMaxValue: Double = 9.0
    private lazy var cutoffSliderMaxValuePower2Minus1 = Float(pow(2, cutoffSliderMaxValue) - 1)

    private var audioUnitManager: AudioUnitManager!
    private var cutoff: AUParameter? { audioUnitManager?.audioUnit?.parameterDefinitions.cutoff }
    private var resonance: AUParameter? { audioUnitManager?.audioUnit?.parameterDefinitions.resonance }

    private var playButton: NSButton!
    private var bypassButton: NSButton!
    private var playMenuItem: NSMenuItem!
    private var bypassMenuItem: NSMenuItem!
    private var savePresetMenuItem: NSMenuItem!

    @IBOutlet var cutoffSlider: NSSlider!
    @IBOutlet var cutoffTextField: NSTextField!
    @IBOutlet var resonanceSlider: NSSlider!
    @IBOutlet var resonanceTextField: NSTextField!
    @IBOutlet var containerView: NSView!

    private var windowController: MainWindowController? { view.window?.windowController as? MainWindowController }
    private var appDelegate: AppDelegate? { NSApplication.shared.delegate as? AppDelegate }

    private var filterView: NSView?
    private var parameterObserverToken: AUParameterObserverToken?
}

// MARK: - View Management
extension MainViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        audioUnitManager = AudioUnitManager(componentDescription: FilterAudioUnit.componentDescription,
                                            appExtension: Bundle.main.auBaseName)
        audioUnitManager.delegate = self

        cutoffSlider.minValue = cutoffSliderMinValue
        cutoffSlider.maxValue = cutoffSliderMaxValue
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let appDelegate = appDelegate,
              let windowController = windowController else {
            fatalError()
        }

        view.window?.delegate = self
        savePresetMenuItem = appDelegate.savePresetMenuItem
        guard savePresetMenuItem != nil else { fatalError() }

        playButton = windowController.playButton
        playMenuItem = appDelegate.playMenuItem

        bypassButton = windowController.bypassButton
        bypassMenuItem = appDelegate.bypassMenuItem
        bypassButton.isEnabled = false
        bypassMenuItem.isEnabled = false

        savePresetMenuItem.isHidden = true
        savePresetMenuItem.isEnabled = false
        savePresetMenuItem.target = self
        savePresetMenuItem.action = #selector(handleSavePresetMenuSelection(_:))
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
The AUv3 component 'SimplyLowPass' is now available on your system.

This app uses the component to demonstrate how it works and sounds.
"""
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: view.window!){ _ in }
    }
}

extension MainViewController: AudioUnitManagerDelegate {

    func connected() {
        guard filterView == nil else { return }
        connectFilterView()
        connectParametersToControls()
    }
}

// MARK: - UI Actions
extension MainViewController {

    @IBAction private func togglePlay(_ sender: NSButton) {
        audioUnitManager.togglePlayback()
        playButton?.state = audioUnitManager.isPlaying ? .on : .off
        playButton?.title = audioUnitManager.isPlaying ? "Stop" : "Play"
        playMenuItem?.title = audioUnitManager.isPlaying ? "Stop" : "Play"
        bypassButton?.isEnabled = audioUnitManager.isPlaying
        bypassMenuItem?.isEnabled = audioUnitManager.isPlaying
    }

    @IBAction private func toggleBypass(_ sender: NSButton) {
        let wasBypassed = audioUnitManager.audioUnit?.shouldBypassEffect ?? false
        let isBypassed = !wasBypassed
        audioUnitManager.audioUnit?.shouldBypassEffect = isBypassed
        bypassButton?.state = isBypassed ? .on : .off
        bypassButton?.title = isBypassed ? "Resume" : "Bypass"
        bypassMenuItem?.title = isBypassed ? "Resume" : "Bypass"
    }

    @IBAction private func cutoffSliderValueChanged(_ sender: NSSlider) {
        cutoff?.value = frequencyValueForSliderLocation(sender.floatValue)
    }

    @IBAction private func resonanceSliderValueChanged(_ sender: NSSlider) {
        resonance?.value = sender.floatValue
    }

    @objc private func handleSavePresetMenuSelection(_ sender: NSMenuItem) throws {
        guard let audioUnit = audioUnitManager.viewController.audioUnit else { return }
        guard let presetMenu = NSApplication.shared.mainMenu?.item(withTag: 666)?.submenu else { return }

        let preset = AUAudioUnitPreset()
        let index = audioUnit.userPresets.count + 1
        preset.name = "Preset \(index)"
        preset.number = -index

        do {
            try audioUnit.saveUserPreset(preset)
        } catch {
            print(error.localizedDescription)
        }

        let menuItem = NSMenuItem(title: preset.name,
                                  action: #selector(handlePresetMenuSelection(_:)),
                                  keyEquivalent: "")
        menuItem.tag = preset.number
        presetMenu.addItem(menuItem)
    }

    @objc private func handlePresetMenuSelection(_ sender: NSMenuItem) {
        guard let audioUnit = audioUnitManager.viewController.audioUnit else { return }
        sender.menu?.items.forEach { $0.state = .off }
        if sender.tag >= 0 {
            audioUnit.currentPreset = audioUnit.factoryPresets[sender.tag]
        }
        else {
            audioUnit.currentPreset = audioUnit.userPresets[sender.tag]
        }

        sender.state = .on
    }
}

extension MainViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        audioUnitManager.cleanup()
        guard let parameterTree = audioUnitManager.viewController.audioUnit?.parameterTree,
            let parameterObserverToken = parameterObserverToken else { return }
        parameterTree.removeParameterObserver(parameterObserverToken)
    }
}

extension MainViewController {

    private func connectFilterView() {
        let viewController = audioUnitManager.viewController
        let filterView = viewController.view
        containerView.addSubview(filterView)
        filterView.pinToSuperviewEdges()
        self.filterView = filterView

        addChild(viewController)
        view.needsLayout = true
        containerView.needsLayout = true
    }

    private func connectParametersToControls() {
        guard let auAudioUnit = audioUnitManager.viewController.audioUnit else {
            fatalError("Couldn't locate FilterAudioUnit")
        }
        guard let parameterTree = auAudioUnit.parameterTree else {
            fatalError("FilterAudioUnit does not define any parameters.")
        }
        guard let _ = parameterTree.parameter(withAddress: .cutoff) else {
            fatalError("Undefined cutoff parameter")
        }
        guard let resonanceParameter = parameterTree.parameter(withAddress: .resonance) else {
            fatalError("Undefined resonance parameter")
        }

        resonanceSlider.minValue = Double(resonanceParameter.minValue)
        resonanceSlider.maxValue = Double(resonanceParameter.maxValue)

        parameterObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let self = self else { return }
            switch address.filterParameter {
            case .cutoff: DispatchQueue.main.async { self.cutoffValueDidChange(value) }
            case .resonance: DispatchQueue.main.async { self.resonanceValueDidChange(value) }
            default: break
            }
        })

        populatePresetMenu(auAudioUnit)
    }

    public func cutoffValueDidChange(_ value: AUValue) {
        cutoffSlider.floatValue = sliderLocationForFrequencyValue(value)
        cutoffTextField.stringValue = String(format: "%.f", value)
    }

    public func resonanceValueDidChange(_ value: AUValue) {
        resonanceSlider.floatValue = value
        resonanceTextField.stringValue = String(format: "%.2f", value)
    }

    private func populatePresetMenu(_ audioUnit: FilterAudioUnit) {
        guard let presetMenu = NSApplication.shared.mainMenu?.item(withTag: 666)?.submenu else { return }
        for preset in audioUnit.factoryPresets {
            let keyEquivalent = "\(preset.number + 1)"
            let menuItem = NSMenuItem(title: preset.name, action: #selector(handlePresetMenuSelection(_:)),
                                      keyEquivalent: keyEquivalent)
            menuItem.tag = preset.number
            presetMenu.addItem(menuItem)
        }

        if let currentPreset = audioUnit.currentPreset {
            presetMenu.item(at: currentPreset.number + 2)?.state = .on
        }
    }

    private func sliderLocationForFrequencyValue(_ frequency: Float) -> Float {
        log(((frequency - FilterView.hertzMin) / (FilterView.hertzMax - FilterView.hertzMin)) *
            cutoffSliderMaxValuePower2Minus1 + 1.0) / log(2)
    }

    private func frequencyValueForSliderLocation(_ location: Float) -> Float {
        ((pow(2, location) - 1) / cutoffSliderMaxValuePower2Minus1) * (FilterView.hertzMax - FilterView.hertzMin) +
            FilterView.hertzMin
    }
}
