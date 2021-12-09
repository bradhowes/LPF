// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AVFoundation
import os.log

/**
 Delegation protocol for AudioUnitHost class.
 */
public protocol AudioUnitHostDelegate: AnyObject {
  
  /**
   Notification that the UIViewController in the AudioUnitHost has a wired AUAudioUnit
   */
  func connected(audioUnit: AUAudioUnit, viewController: ViewController)
  func failed(error: Error)
}

/**
 Simple hosting container for the FilterAudioUnit when used in an application. Loads the view controller for the
 AudioUnit and then instantiates the audio unit itself. Finally, it wires the AudioUnit with SimplePlayEngine to
 send audio samples to the AudioUnit. Note that this class has no knowledge of any classes other than what Apple
 provides.
 */
public final class AudioUnitHost {
  private let log = Logging.logger("AudioUnitHost")

  private let lastStateKey = "lastStateKey"
  private let lastPresetIndexKey = "lastPresetIndexKey"

  private let playEngine = SimplePlayEngine()
  private var isRestoring: Bool = false
  private let locateQueue = DispatchQueue(label: Bundle.bundleID + ".LocateQueue", qos: .userInitiated)
  private let componentDescription: AudioComponentDescription

  /// AudioUnit controlled by the view controller
  public private(set) var audioUnit: AUAudioUnit?

  /// View controller for the AudioUnit interface
  public private(set) var viewController: ViewController?

  /// True if the audio engine is currently playing
  public var isPlaying: Bool { playEngine.isPlaying }
  
  /// Delegate to signal when everything is wired up.
  public weak var delegate: AudioUnitHostDelegate? { didSet { signalConnected() } }

  private var notificationObserverToken: NSObjectProtocol?
  private var creationError: Error?

  /**
   Create a new instance that will hopefully create a new AUAudioUnit and a view controller for its control view.

   - parameter componentDescription: the definition of the AUAudioUnit to create
   */
  public init(componentDescription: AudioComponentDescription) {
    self.componentDescription = componentDescription
    componentDescription.log(log, type: .info)
    self.locate()
  }

  /**
   Use AVAudioUnitComponentManager to locate the AUv3 component we want. This is done asynchronously in the background.
   If the component we want is not found, start listening for notifications from the AVAudioUnitComponentManager for
   updates and try again.
   */
  private func locate() {
    os_log(.info, log: log, "locate")
    locateQueue.async { [weak self] in
      guard let self = self else { return }

      let components = AVAudioUnitComponentManager.shared().components(matching: self.componentDescription)
      os_log(.info, log: self.log, "locate: found %d", components.count)
      if !components.isEmpty {
        self.createAudioUnit()
      }
      else {
        self.checkAgain()
      }
    }
  }

  /**
   Begin listening for updates from the AVAudioUnitComponentManager. When we get one, stop listening and attempt to
   locate the AUv3 component we want.
   */
  private func checkAgain() {
    os_log(.info, log: log, "checkAgain")
    let center = NotificationCenter.default
    notificationObserverToken = center.addObserver(
      forName: AVAudioUnitComponentManager.registrationsChangedNotification, object: nil, queue: nil) { [weak self] _ in
        guard let self = self else { return }
        os_log(.info, log: self.log, "checkAgain: notification")
        let token = self.notificationObserverToken!
        self.notificationObserverToken = nil
        center.removeObserver(token)
        self.locate()
      }
  }

  /**
   Create the AUv3 component.
   */
  private func createAudioUnit() {
    os_log(.info, log: log, "createAudioUnit")
    guard self.audioUnit == nil else { return }

    let options: AudioComponentInstantiationOptions = .loadOutOfProcess

    AVAudioUnit.instantiate(with: self.componentDescription, options: options) { [weak self] avAudioUnit, error in
      guard let self = self else { return }
      if let error = error {
        os_log(.error, log: self.log, "createAudioUnit: error - %{public}s", error.localizedDescription)
        self.delegate?.failed(error: error)
        return
      }

      guard let avAudioUnit = avAudioUnit else {
        os_log(.error, log: self.log, "createAudioUnit: nil avAudioUnit")
        return
      }

      self.createViewController(avAudioUnit)
    }
  }

  private func createViewController(_ avAudioUnit: AVAudioUnit) {
    os_log(.info, log: log, "createViewController")
    avAudioUnit.auAudioUnit.requestViewController { [weak self] controller in
      guard let self = self else { return }
      guard let controller = controller else { fatalError("view controller is nil") }
      os_log(.info, log: self.log, "view controller type - %{public}s", String(describing: type(of: controller)))
      self.wireAudioUnit(avAudioUnit, controller)
    }
  }

  private func wireAudioUnit(_ avAudioUnit: AVAudioUnit, _ viewController: UIViewController) {
    self.audioUnit = avAudioUnit.auAudioUnit
    self.viewController = viewController

    playEngine.connectEffect(audioUnit: avAudioUnit)
    signalConnected()
  }

  private func signalConnected() {
    if let audioUnit = self.audioUnit, let viewController = self.viewController {
      DispatchQueue.performOnMain { self.delegate?.connected(audioUnit: audioUnit, viewController: viewController) }
    }
    else if let creationError = self.creationError {
      DispatchQueue.performOnMain { self.delegate?.failed(error: creationError) }
    }
  }
}

extension AudioUnitHost {

  private var noCurrentPresetIndex: Int { Int.max }

  /**
   Save the current state of the AudioUnit to UserDefaults for future restoration.
   */
  public func save() {
    guard !isRestoring else { return }

    if let lastState = audioUnit?.fullStateForDocument {
      UserDefaults.standard.set(lastState, forKey: lastStateKey)
    }
    else {
      UserDefaults.standard.removeObject(forKey: lastStateKey)
    }

    let lastPresetIndex = audioUnit?.currentPreset?.number ?? noCurrentPresetIndex
    UserDefaults.standard.set(lastPresetIndex, forKey: lastPresetIndexKey)
  }

  /**
   Restore the state of the AudioUnit using values found in UserDefaults.
   */
  public func restore() {
    guard let audioUnit = self.audioUnit else { fatalError() }
    guard !isRestoring else { fatalError() }

    isRestoring = true
    defer {
      isRestoring = false
    }

    if let lastState = UserDefaults.standard.dictionary(forKey: lastStateKey) {
      audioUnit.fullStateForDocument = lastState
    }

    if let lastPresetIndex = UserDefaults.standard.object(forKey: lastPresetIndexKey) as? NSNumber {
      let presetIndex = lastPresetIndex.intValue
      if presetIndex == noCurrentPresetIndex {
        audioUnit.currentPreset = nil
      }
      else if presetIndex >= 0 {
#if os(iOS)
        audioUnit.currentPreset = audioUnit.factoryPresets?[presetIndex]
#elseif os(macOS)
        audioUnit.currentPreset = audioUnit.factoryPresets[presetIndex]
#endif
      }
      else {
        let index = -presetIndex - 1
        if index > 0 && index < audioUnit.userPresets.count {
          audioUnit.currentPreset = audioUnit.userPresets[index]
        }
        else {
          audioUnit.currentPreset = nil
        }
      }
    }
  }
}

public extension AudioUnitHost {
  
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
