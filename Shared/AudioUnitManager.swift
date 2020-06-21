// Copyright © 2020 Brad Howes. All rights reserved.

import AVFoundation

public protocol AUManagerDelegate: AnyObject {
    func cutoffValueDidChange(_ value: Float)
    func resonanceValueDidChange(_ value: Float)
}

public class AudioUnitManager {
    private var audioUnit: AUv3FilterDemo?

    public weak var delegate: AUManagerDelegate? {
        didSet {
            updateCutoff()
            updateResonance()
        }
    }

    public private(set) var viewController: FilterViewController!
    public var cutoffValue: Float = 0.0 { didSet { cutoffParameter.value = cutoffValue } }
    public var resonanceValue: Float = 0.0 { didSet { resonanceParameter.value = resonanceValue } }

    public var presets: [Preset] {
        guard let audioUnitPresets = audioUnit?.factoryPresets else { return [] }
        return audioUnitPresets.map { preset -> Preset in Preset(preset: preset) }
    }

    public var currentPreset: Preset? {
        get {
            guard let preset = audioUnit?.currentPreset else { return nil }
            return Preset(preset: preset)
        }
        set {
            audioUnit?.currentPreset = newValue?.audioUnitPreset
        }
    }

    private let playEngine = SimplePlayEngine()
    private var cutoffParameter: AUParameter!
    private var resonanceParameter: AUParameter!
    private var parameterObserverToken: AUParameterObserverToken!
    private let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: 0x666c7472,
        componentManufacturer: 0x44656d6f,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    private let componentName = "Demo: AUv3FilterDemo"

    public init() {
        viewController = loadViewController()
        AUAudioUnit.registerSubclass(AUv3FilterDemo.self, as: componentDescription, name: componentName,
                                     version: UInt32.max)

        AVAudioUnit.instantiate(with: componentDescription) { audioUnit, error in
            guard error == nil, let audioUnit = audioUnit else {
                fatalError("Could not instantiate audio unit: \(String(describing: error))")
            }
            self.audioUnit = audioUnit.auAudioUnit as? AUv3FilterDemo
            self.connectParametersToControls()
            self.playEngine.connect(avAudioUnit: audioUnit)
        }
    }
}

// MARK: - API

public extension AudioUnitManager {

    @discardableResult
    func togglePlayback() -> Bool { playEngine.togglePlay() }

    func toggleView() { viewController.toggleViewConfiguration() }

    func cleanup() {
        playEngine.stopPlaying()
        guard let parameterTree = audioUnit?.parameterTree else { return }
        parameterTree.removeParameterObserver(parameterObserverToken)
    }
}

// MARK: - Private

private extension AudioUnitManager {

    private func loadViewController() -> FilterViewController {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("AUv3FilterExtension.appex"),
            let appexBundle = Bundle(url: url) else {
                fatalError("Could not find app extension bundle URL.")
        }

        #if os(iOS)
        let storyboard = Storyboard(name: "MainInterface", bundle: appexBundle)
        guard let controller = storyboard.instantiateInitialViewController() as? AUv3FilterDemoViewController else {
            fatalError("Unable to instantiate AUv3FilterDemoViewController")
        }
        return controller

        #elseif os(macOS)
        return FilterViewController(nibName: "AUv3FilterDemoViewController", bundle: appexBundle)
        #endif
    }

    private func connectParametersToControls() {
        guard let audioUnit = audioUnit else {
            fatalError("Couldn't locate AUv3FilterDemo")
        }

        viewController.audioUnit = audioUnit
        guard let parameterTree = audioUnit.parameterTree else {
            fatalError("AUv3FilterDemo does not define any parameters.")
        }

        cutoffParameter = parameterTree.value(forKey: "cutoff") as? AUParameter
        resonanceParameter = parameterTree.value(forKey: "resonance") as? AUParameter

        parameterObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if address == self.cutoffParameter.address {
                    self.updateCutoff()
                } else if address == self.resonanceParameter.address {
                    self.updateResonance()
                }
            }
        })
    }

    private func updateCutoff() {
        guard let param = cutoffParameter else { return }
        delegate?.cutoffValueDidChange(param.value)
    }

    private func updateResonance() {
        guard let param = resonanceParameter else { return }
        delegate?.resonanceValueDidChange(param.value)
    }
}
