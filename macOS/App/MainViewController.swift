// Copyright © 2020 Brad Howes. All rights reserved.

import Cocoa
import LowPassFilterFramework

final class MainViewController: NSViewController {

    private let cutoffSliderMinValue = 0.0
    private let cutoffSliderMaxValue = 9.0
    private lazy var cutoffSliderMaxValuePower2Minus1 = Float(pow(2, cutoffSliderMaxValue) - 1)

    private let audioUnitManager = AudioUnitManager<FilterViewController>(componentDescription: FilterAudioUnit.componentDescription, appExt: "LPF")
    private var cutoff: AUParameter? { audioUnitManager.auAudioUnit?.parameterDefinitions.cutoff }
    private var resonance: AUParameter? { audioUnitManager.auAudioUnit?.parameterDefinitions.resonance }

    private var playButton: NSButton?
    private var playMenuItem: NSMenuItem?

    private var savePresetMenuItem: NSMenuItem?

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

    func connected() {
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
    }

    @IBAction private func cutoffSliderValueChanged(_ sender: NSSlider) { cutoff?.value = frequencyValueForSliderLocation(sender.floatValue) }

    @IBAction private func resonanceSliderValueChanged(_ sender: NSSlider) { resonance?.value = sender.floatValue }

    @objc private func handleSavePresetMenuSelection(_ sender: NSMenuItem) throws {
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

    @objc private func handlePresetMenuSelection(_ sender: NSMenuItem) {
        guard let audioUnit = audioUnitManager.auAudioUnit else { return }
        sender.menu?.items.forEach { $0.state = .off }
        if sender.tag >= 0 {
            audioUnit.currentPreset = audioUnit.factoryPresets[sender.tag]
        }
        sender.state = .on
    }
}

// MARK: NSWindowDelegate
extension MainViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        audioUnitManager.cleanup()
        guard let parameterTree = audioUnitManager.auAudioUnit?.parameterTree,
            let parameterObserverToken = parameterObserverToken else { return }
        parameterTree.removeParameterObserver(parameterObserverToken)
    }
}

// MARK: - Private
extension MainViewController {

    private func connectFilterView() {
        guard let viewController = audioUnitManager.viewController else { fatalError() }
        filterView = viewController.view
        containerView.addSubview(filterView!)
        filterView?.pinToSuperviewEdges()

        addChild(viewController)
        view.needsLayout = true
        containerView.needsLayout = true
    }

    private func connectParametersToControls() {
        guard let auAudioUnit = audioUnitManager.auAudioUnit else {
            fatalError("Couldn't locate FilterAudioUnit")
        }

        guard let parameterTree = auAudioUnit.parameterTree else {
            fatalError("FilterAudioUnit does not define any parameters.")
        }

        guard let _ = parameterTree.parameter(withAddress: FilterParameterAddress.cutoff.rawValue) else {
            fatalError("Undefined cutoff parameter")
        }

        guard let resonanceParameter = parameterTree.parameter(withAddress: FilterParameterAddress.resonance.rawValue)
            else {
                fatalError("Undefined resonance parameter")
        }

        resonanceSlider.minValue = Double(resonanceParameter.minValue)
        resonanceSlider.maxValue = Double(resonanceParameter.maxValue)

        parameterObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let self = self else { return }
            switch address {
            case FilterParameterAddress.cutoff.rawValue:
                DispatchQueue.main.async { self.cutoffValueDidChange(value) }
            case FilterParameterAddress.resonance.rawValue:
                DispatchQueue.main.async { self.resonanceValueDidChange(value) }
            default: break
            }
        })

        populatePresetMenu(auAudioUnit)
    }

    private func cutoffValueDidChange(_ value: AUValue) {
        cutoffSlider.floatValue = sliderLocationForFrequencyValue(value)
        cutoffTextField.text = String(format: "%.f", value)
        clearPresetCheck()
    }

    private func resonanceValueDidChange(_ value: AUValue) {
        resonanceSlider.floatValue = value
        resonanceTextField.text = String(format: "%.2f", value)
        clearPresetCheck()
    }

    private func populatePresetMenu(_ audioUnit: FilterAudioUnit) {
        guard let presetMenu = NSApplication.shared.mainMenu?.item(withTag: 666)?.submenu else { return }

        savePresetMenuItem = presetMenu.items[0]
        savePresetMenuItem?.isEnabled = true
        savePresetMenuItem?.target = self
        savePresetMenuItem?.action = #selector(handleSavePresetMenuSelection(_:))

        for preset in audioUnit.factoryPresets {
            let keyEquivalent = "\(preset.number + 1)"
            let menuItem = NSMenuItem(title: preset.name,
                                      action: #selector(handlePresetMenuSelection(_:)),
                                      keyEquivalent: keyEquivalent)
            menuItem.tag = preset.number
            print(preset.number)
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

    private func clearPresetCheck() {
        guard let presetMenu = NSApplication.shared.mainMenu?.item(withTag: 666)?.submenu else { return }
        guard let audioUnit = audioUnitManager.auAudioUnit else { return }
        guard !audioUnit.usingPreset else { return }
        presetMenu.items.forEach { $0.state = .off }
    }
}
