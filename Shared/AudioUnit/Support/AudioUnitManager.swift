// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AVFoundation

/**
 Delegation protocol for AudioUnitManager class.
 */
public protocol AudioUnitManagerDelegate: class {

    /**
     Notification that a ViewController for the audio unit has been instantiated.
     */
    func connected()
}

/**
 Simple hosting container for the FilterAudioUnit when used in an application. Loads the view controller for the
 AudioUnit and then instantiates the audio unit itself. Finally, it wires the AudioUnit with SimmplePlayEngine to
 send audio samples the AudioUnit.
 */
public final class AudioUnitManager<V> where V: ViewController, V: FilterViewAudioUnitLink, V.AudioUnitType: AUAudioUnit {

    public typealias ViewControllerType = V
    public typealias AudioUnitType = V.AudioUnitType

    /// Delegate interested in runtime parameter changes. Note that no AudioUnit will be created until this is set.
    public weak var delegate: AudioUnitManagerDelegate? {
        didSet {
            guard let _ = viewController, let delegate = delegate else { return }
            DispatchQueue.main.async { delegate.connected() }
        }
    }

    /// View controller for the AudioUnit interface
    public private(set) var viewController: ViewControllerType? {
        didSet {
            guard let _ = viewController, let delegate = delegate else { return }
            DispatchQueue.main.async { delegate.connected() }
        }
    }

    /// True if the audio engine is currently playing
    public var isPlaying: Bool { playEngine.isPlaying }

    /// The AVAudioUnit instance that wraps the AudioUnit. Used with other AV components for simple audio processing.
    public private(set) var avAudioUnit: AVAudioUnit?

    /// The AudioUnit being managed.
    public private(set) var auAudioUnit: AudioUnitType?

    private let log = Logging.logger("AudioUnitManager")
    private let playEngine = SimplePlayEngine()
    private let componentDescription: AudioComponentDescription
    private let appExt: String

    /**
     Create a new instance. Instantiates new FilterAudioUnit and its view controller.
     */
    public init(componentDescription: AudioComponentDescription, appExt: String) {
        self.componentDescription = componentDescription
        self.appExt = appExt
        createAudioUnit()
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
        viewController.setAudioUnit(auAudioUnit)
        playEngine.connectEffect(audioUnit: avAudioUnit)

        // Keep this at the end of the initialization -- side-effect is notifying the delegate that all is connected.
        self.viewController = viewController
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
    }
}
