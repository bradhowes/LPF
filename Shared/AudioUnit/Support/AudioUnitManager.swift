// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AVFoundation

/**
 Delegation protocol for AudioUnitManager class.
 */
public protocol AudioUnitManagerDelegate: AnyObject {

    func audioUnitViewController(_ viewController: NSViewController?)

    func audioUnitCutoffParameter(_ parameter: AUParameter)

    func audioUnitResonanceParameter(_ parameter: AUParameter)

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
            locateAudioUnitComponent()
            updateCutoff()
            updateResonance()
        }
    }

    /// Runtime parameter for the filter's cutoff
    public var cutoffValue: Float = 0.0 { didSet { cutoffParameter?.value = cutoffValue } }

    /// Runtime parameter for the filter's resonance
    public var resonanceValue: Float = 0.0 { didSet { resonanceParameter?.value = resonanceValue } }

    /// Collection of current presets for the AudioUnit
    public var presets: [Preset] {
        guard let audioUnitPresets = auAudioUnit?.factoryPresets else { return [] }
        return audioUnitPresets.map { preset -> Preset in Preset(preset: preset) }
    }

    /// The currently-active preset
    public var currentPreset: Preset? {
        get {
            guard let preset = auAudioUnit?.currentPreset else { return nil }
            return Preset(preset: preset)
        }
        set {
            auAudioUnit?.currentPreset = newValue?.audioUnitPreset
        }
    }

    private var avAudioUnit: AVAudioUnit?
    private var auAudioUnit: AUAudioUnit?

    private var cutoffParameter: AUParameter? {
        didSet {
            guard let param = cutoffParameter else { return }
            cutoffValue = param.value
            delegate?.audioUnitCutoffParameter(param)
        }
    }

    private var resonanceParameter: AUParameter? {
        didSet {
            guard let param = resonanceParameter else { return }
            resonanceValue = param.value
            delegate?.audioUnitResonanceParameter(param)
        }
    }

    private var parameterObserverToken: AUParameterObserverToken!

    private let playEngine = SimplePlayEngine()
    public var isPlaying: Bool { playEngine.isPlaying }

    private var observationToken: NSObjectProtocol?

    private let componentDescription: AudioComponentDescription

    /**
     Create a new instance. Instantiates new FilterAudioUnit and its view controller.
     */
    public init(componentDescription: AudioComponentDescription) {
        self.componentDescription = componentDescription
    }

    deinit {
        guard let observationToken = self.observationToken else { return }
        NotificationCenter.default.removeObserver(observationToken)
    }
}

extension AudioUnitManager {

    private func locateAudioUnitComponent() {
        DispatchQueue.global(qos: .default).async {
            let found = AVAudioUnitComponentManager.shared().components(matching: self.componentDescription)
            guard let component = found.first else { return }
            self.create(component: component) {}
        }
    }

    private func create(component: AVAudioUnitComponent, closure: @escaping () -> Void) {
        AVAudioUnit.instantiate(with: component.audioComponentDescription, options: []) { avAudioUnit, error in
            guard error == nil, let avAudioUnit = avAudioUnit else {
                fatalError("Could not instantiate audio unit: \(String(describing: error))")
            }

            self.avAudioUnit = avAudioUnit
            self.auAudioUnit = avAudioUnit.auAudioUnit

            self.connectParametersToControls()
            self.playEngine.connectEffect(audioUnit: avAudioUnit)

            DispatchQueue.main.async {
                self.auAudioUnit?.requestViewController { self.delegate?.audioUnitViewController($0) }
            }
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
        guard let parameterTree = auAudioUnit?.parameterTree else { return }
        parameterTree.removeParameterObserver(parameterObserverToken)
    }
}

private extension AudioUnitManager {

    private func connectParametersToControls() {
        guard let auAudioUnit = auAudioUnit else {
            fatalError("Couldn't locate FilterAudioUnit")
        }

        guard let parameterTree = auAudioUnit.parameterTree else {
            fatalError("FilterAudioUnit does not define any parameters.")
        }

        DispatchQueue.main.async {
            self.cutoffParameter = parameterTree.parameter(withAddress: FilterParameterAddress.cutoff.rawValue)
            self.resonanceParameter = parameterTree.parameter(withAddress: FilterParameterAddress.resonance.rawValue)
        }

        parameterObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch address {
                case FilterParameterAddress.cutoff.rawValue: self.updateCutoff()
                case FilterParameterAddress.resonance.rawValue: self.updateResonance()
                default: break
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
