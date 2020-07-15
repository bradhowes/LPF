// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AVFoundation

/**
 Delegation protocol for AudioUnitManager class. Communicates to delegate when a runtime parameter changes.
 */
public protocol AudioUnitManagerDelegate: AnyObject {

    /**
     Notification that cutoff value changed.

     - parameter value: new value
     */
    func cutoffValueDidChange(_ value: Float)

    /**
     Notification that resonance value changed.

     - parameter value: new value
     */
    func resonanceValueDidChange(_ value: Float)
}

/**
 Simple hosting container for the FilterAudioUnit when loaded in an application. Sets up a
 Manages the state of a FilterAudioUnit.
 */
public final class AudioUnitManager {

    /// Delegate interested in runtime parameter changes
    public weak var delegate: AudioUnitManagerDelegate? {
        didSet {
            updateCutoff()
            updateResonance()
        }
    }

    /// View controller associated with the AudioUnit
    public private(set) var viewController: FilterViewController!

    /// Runtime parameter for the filter's cutoff
    public var cutoffValue: Float = 0.0 { didSet { cutoffParameter.value = cutoffValue } }

    /// Runtime parameter for the filter's resonance
    public var resonanceValue: Float = 0.0 { didSet { resonanceParameter.value = resonanceValue } }

    /// Collection of current presets for the AudioUnit
    public var presets: [Preset] {
        guard let audioUnitPresets = audioUnit?.factoryPresets else { return [] }
        return audioUnitPresets.map { preset -> Preset in Preset(preset: preset) }
    }

    /// The currently-active preset
    public var currentPreset: Preset? {
        get {
            guard let preset = audioUnit?.currentPreset else { return nil }
            return Preset(preset: preset)
        }
        set {
            audioUnit?.currentPreset = newValue?.audioUnitPreset
        }
    }

    private var audioUnit: FilterAudioUnit!
    private var cutoffParameter: AUParameter!
    private var resonanceParameter: AUParameter!
    private var parameterObserverToken: AUParameterObserverToken!

    private let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: FourCharCode(stringLiteral: "lpas"),
        componentManufacturer: FourCharCode(stringLiteral: "BRay"),
        componentFlags: 0,
        componentFlagsMask: 0
    )

    private let componentName = "B-Ray: Low-pass"
    private let playEngine = SimplePlayEngine()

    /**
     Create a new instance. Instantiates new FilterAudioUnit and its view controller.
     */
    public init() {
        viewController = loadViewController()

        AUAudioUnit.registerSubclass(FilterAudioUnit.self, as: componentDescription, name: componentName,
                                     version: UInt32.max)

        AVAudioUnit.instantiate(with: componentDescription, options: []) { avAudioUnit, error in
            guard error == nil, let avAudioUnit = avAudioUnit else {
                fatalError("Could not instantiate audio unit: \(String(describing: error))")
            }

            self.audioUnit = avAudioUnit.auAudioUnit as? FilterAudioUnit
            self.viewController.audioUnit = self.audioUnit
            self.connectParametersToControls()
            self.playEngine.connectEffect(audioUnit: avAudioUnit)
        }
    }
}

public extension AudioUnitManager {

    /**
     Start/stop audio engine

     - returns: true if playing
     */
    @discardableResult
    func togglePlayback() -> Bool { playEngine.startStop() }

    /**
     The world is being torn apart. Stop any asynchronous eventing from happening in the future.
     */
    func cleanup() {
        playEngine.stop()
        guard let parameterTree = audioUnit?.parameterTree else { return }
        parameterTree.removeParameterObserver(parameterObserverToken)
    }
}

private extension AudioUnitManager {

    private func loadViewController() -> FilterViewController {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("LPF.appex"),
            let appexBundle = Bundle(url: url) else {
                fatalError("Could not find app extension bundle URL.")
        }

        #if os(iOS)
        let storyboard = Storyboard(name: "MainInterface", bundle: appexBundle)
        guard let controller = storyboard.instantiateInitialViewController() as? FilterViewController else {
            fatalError("Unable to instantiate FilterViewController")
        }
        return controller

        #elseif os(macOS)
        return FilterViewController(nibName: "FilterViewController", bundle: appexBundle)
        #endif
    }

    private func connectParametersToControls() {
        guard let audioUnit = audioUnit else {
            fatalError("Couldn't locate FilterAudioUnit")
        }

        viewController.audioUnit = audioUnit
        guard let parameterTree = audioUnit.parameterTree else {
            fatalError("FilterAudioUnit does not define any parameters.")
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
