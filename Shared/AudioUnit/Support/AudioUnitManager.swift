// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AVFoundation

/**
 Delegation protocol for AudioUnitManager class.
 */
public protocol AudioUnitManagerDelegate: class {

    /**
     Notification that a ViewController for the audio unit has been instantiated

     - parameter viewController the new value
     */
    func audioUnitViewControllerDeclared(_ viewController: ViewController)

    /**
     Notification that the cutoff runtime parameter has been initialized.

     - parameter parameter: the new values
     */
    func audioUnitCutoffParameterDeclared(_ parameter: AUParameter)

    /**
     Notification that the resonance runtime parameter has been initialized.

     - parameter parameter: the new value
     */
    func audioUnitResonanceParameterDeclared(_ parameter: AUParameter)

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

class MyObserver: NSObject {
    @objc var objectToObserve: AUAudioUnitPreset
    var observation: NSKeyValueObservation?

    init(object: AUAudioUnitPreset) {
        objectToObserve = object
        super.init()

        observation = observe(
            \.objectToObserve.number,
            options: [.old, .new]
        ) { object, change in
            print("myDate changed from: \(change.oldValue!), updated to: \(change.newValue!)")
        }
    }
}

/**
 Simple hosting container for the FilterAudioUnit when loaded in an application. Sets up a
 Manages the state of a FilterAudioUnit.
 */
public final class AudioUnitManager<V> where V: ViewController, V: FilterViewAudioUnitLink, V.AudioUnitType: AUAudioUnit {

    public typealias ViewControllerType = V
    public typealias AudioUnitType = V.AudioUnitType

    /// Delegate interested in runtime parameter changes
    public weak var delegate: AudioUnitManagerDelegate? { didSet { createAudioUnit() } }

    /// Runtime parameter for the filter's cutoff
    public var cutoffValue: Float = 0.0 { didSet { cutoffParameter?.value = cutoffValue } }

    /// Runtime parameter for the filter's resonance
    public var resonanceValue: Float = 0.0 { didSet { resonanceParameter?.value = resonanceValue } }

    /// Collection of current presets for the AudioUnit
    public var presets: [AUAudioUnitPreset] = []
    private var presetObservers: [MyObserver] = []

    /// The currently-active preset
    public var currentPreset: AUAudioUnitPreset? {
        get {
            auAudioUnit?.currentPreset
        }
        set {
            auAudioUnit?.currentPreset = newValue
        }
    }

    /// True if the audio engine is currently playing
    public var isPlaying: Bool { playEngine.isPlaying }

    public private(set) var avAudioUnit: AVAudioUnit?
    public private(set) var auAudioUnit: AudioUnitType?

    private let log = Logging.logger("AudioUnitManager")

    private var cutoffParameter: AUParameter? {
        didSet {
            guard let param = cutoffParameter, let delegate = delegate else { return }
            cutoffValue = param.value
            DispatchQueue.main.async { delegate.audioUnitCutoffParameterDeclared(param) }
        }
    }

    private var resonanceParameter: AUParameter? {
        didSet {
            guard let param = resonanceParameter, let delegate = delegate else { return }
            resonanceValue = param.value
            DispatchQueue.main.async { delegate.audioUnitResonanceParameterDeclared(param) }
        }
    }

    private var parameterObserverToken: AUParameterObserverToken!

    private let playEngine = SimplePlayEngine()

    private var observationToken: NSObjectProtocol?

    private let componentDescription: AudioComponentDescription
    private let appExt: String

    /**
     Create a new instance. Instantiates new FilterAudioUnit and its view controller.
     */
    public init(componentDescription: AudioComponentDescription, appExt: String) {
        self.componentDescription = componentDescription
        self.appExt = appExt
    }

    deinit {
        guard let observationToken = self.observationToken else { return }
        NotificationCenter.default.removeObserver(observationToken)
    }
}

extension AudioUnitManager {

    private func loadViewController() -> ViewControllerType {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent(appExt + ".appex") else {
            fatalError("Could not obtain extension bundle URL")
        }

        guard let appexBundle = Bundle(url: url) else {
            fatalError("Could not get app extension bundle")
        }

        #if os(iOS)
        let storyboard = Storyboard(name: "MainInterface", bundle: appexBundle)
        guard let controller = storyboard.instantiateInitialViewController() as? ViewControllerType else {
            fatalError("Unable to instantiate FilterViewController")
        }
        return controller
        #elseif os(macOS)
        return ViewControllerType(nibName: "FilterViewController", bundle: appexBundle)
        #endif
    }

    private func createAudioUnit() {

        // Obtain audio unit view controller from the app extension
        let viewController = loadViewController()

        // But instantiate audio unit from AVAudioUnit.instantiate so that we have an AVAudioUnit entity to work with.
        AUAudioUnit.registerSubclass(AudioUnitType.self, as: componentDescription, name: "Demo", version: UInt32.max)
        AVAudioUnit.instantiate(with: componentDescription) { audioUnit, error in
            guard error == nil, let audioUnit = audioUnit else {
                fatalError("Could not instantiate audio unit: \(String(describing: error))")
            }

            self.wireAudioUnit(audioUnit, viewController: viewController)
        }
    }

    private func wireAudioUnit(_ avAudioUnit: AVAudioUnit, viewController: ViewControllerType) {
        self.avAudioUnit = avAudioUnit
        guard let auAudioUnit = avAudioUnit.auAudioUnit as? AudioUnitType else {
            fatalError("avAudioUnit.auAudioUnit is nil or wrong type")
        }

        self.auAudioUnit = auAudioUnit

        for each in auAudioUnit.factoryPresets ?? [] {
            self.presets.append(each)
            self.presetObservers.append(MyObserver(object: each))
        }

        viewController.setAudioUnit(auAudioUnit)

        updateCutoff()
        updateResonance()
        connectParametersToControls()
        playEngine.connectEffect(audioUnit: avAudioUnit)

        DispatchQueue.main.async {
            self.delegate?.audioUnitViewControllerDeclared(viewController)
        }
    }

//    private func locateAudioUnitComponent() {
//        DispatchQueue.global(qos: .default).async {
//            let found = AVAudioUnitComponentManager.shared().components(matching: self.componentDescription)
//            guard let component = found.first else { return }
//            self.create(component: component) {}
//        }
//    }

//    private func create(component: AVAudioUnitComponent, closure: @escaping () -> Void) {
//        AVAudioUnitEffect.instantiate(with: component.audioComponentDescription, options: []) { avAudioUnit, error in
//            guard error == nil, let avAudioUnit = avAudioUnit else {
//                fatalError("Could not instantiate audio unit: \(String(describing: error))")
//            }
//
//            self.avAudioUnit = avAudioUnit as? AVAudioUnitEffect
//            self.auAudioUnit = avAudioUnit.auAudioUnit as? FilterAudioUnit
//            self.presets = self.auAudioUnit?.factoryPresets ?? []
//
//            self.connectParametersToControls()
//            self.playEngine.connectEffect(audioUnit: avAudioUnit)
//
//            DispatchQueue.main.async {
//                self.auAudioUnit?.requestViewController { self.delegate?.audioUnitViewControllerDeclared($0) }
//            }
//        }
//    }

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

        cutoffParameter = parameterTree.parameter(withAddress: FilterParameterAddress.cutoff.rawValue)
        resonanceParameter = parameterTree.parameter(withAddress: FilterParameterAddress.resonance.rawValue)

        parameterObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, _ in
            guard let self = self else { return }
            switch address {
            case FilterParameterAddress.cutoff.rawValue: self.updateCutoff()
            case FilterParameterAddress.resonance.rawValue: self.updateResonance()
            default: break
            }
        })
    }

    private func updateCutoff() {
        guard let param = cutoffParameter, let delegate = delegate else { return }
        DispatchQueue.main.async { delegate.cutoffValueDidChange(param.value) }
    }

    private func updateResonance() {
        guard let param = resonanceParameter, let delegate = delegate else { return }
        DispatchQueue.main.async { delegate.resonanceValueDidChange(param.value) }
    }
}
