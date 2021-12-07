// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AVFoundation
import os

/**
 Delegation protocol for AudioUnitHost class.
 */
public protocol AudioUnitHostDelegate: AnyObject {
  
  /**
   Notification that the FilterViewController in the AudioUnitHost has a wired FilterAudioUnit
   */
  func connected()
}

/**
 Simple hosting container for the FilterAudioUnit when used in an application. Loads the view controller for the
 AudioUnit and then instantiates the audio unit itself. Finally, it wires the AudioUnit with SimplePlayEngine to
 send audio samples to the AudioUnit.
 */
public final class AudioUnitHost<VC> {
  private let appExtension: String
  private let lastStateKey = "lastStateKey"
  private let lastPresetIndexKey = "lastPresetIndexKey"
  private let log = Logging.logger("AudioUnitHost")
  private let playEngine = SimplePlayEngine()
  private var isRestoring: Bool = false

  /// AudioUnit controlled by the view controller
  public private(set) var audioUnit: FilterAudioUnit?

  /// View controller for the AudioUnit interface
  public private(set) var viewController: VC?

  /// True if the audio engine is currently playing
  public var isPlaying: Bool { playEngine.isPlaying }
  
  /// Delegate to signal when everything is wired up.
  public weak var delegate: AudioUnitHostDelegate? { didSet { signalConnected() } }

  /**
   Create a new instance. Instantiates new FilterAudioUnit and its view controller.
   */
  public init(componentDescription: AudioComponentDescription, appExtension: String) {
    self.appExtension = appExtension
    self.createAudioUnit(componentDescription: componentDescription)
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
        audioUnit.currentPreset = audioUnit.factoryPresets[presetIndex]
      }
      else {
        audioUnit.currentPreset = audioUnit.userPresets[-presetIndex - 1]
      }
    }
  }
}

extension AudioUnitHost {

  private func createAudioUnit(componentDescription: AudioComponentDescription) {
    os_log(.info, log: log, "createAudioUnit")
    componentDescription.log(log, type: .info)

    // Uff. So for iOS we need to register the AUv3 so we can see it now. But we do NOT want to do so if we are
    // running in macOS
    //
    #if os(iOS)
    let bundle = Bundle(for: AudioUnitHost.self)
    AUAudioUnit.registerSubclass(FilterAudioUnit.self, as: componentDescription, name: bundle.auBaseName,
                                 version: UInt32.max)
    let options = AudioComponentInstantiationOptions()
    #endif

    // If we are running in macOS we must load the AUv3 in-process in order to be able to use it from within the
    // app sandbox.
    //
    #if os(macOS)
    let options: AudioComponentInstantiationOptions = .loadInProcess
    #endif

    // Create AVAudioUnit that holds the AUAudioUnit we wish to use. If all above is correct, this should invoke the
    // FilterViewController.createAudioUnit method.
    AVAudioUnit.instantiate(with: componentDescription, options: options) { avAudioUnit, error in
      guard error == nil, let avAudioUnit = avAudioUnit else {
        fatalError("Could not instantiate audio unit: \(String(describing: error))")
      }

      guard let audioUnit = avAudioUnit.auAudioUnit as? FilterAudioUnit else { fatalError("unexpected auAudioUnit type") }
      self.audioUnit = audioUnit

      self.createViewController(avAudioUnit)
    }
  }

  private func createViewController(_ avAudioUnit: AVAudioUnit) {
    avAudioUnit.auAudioUnit.requestViewController { controller in
#if os(iOS)
      let controller = Self.loadViewController(appExtension: self.appExtension)
      let auAudioUnit = avAudioUnit.auAudioUnit
      guard let audioUnit = auAudioUnit as? FilterAudioUnit else { fatalError() }
      controller.audioUnit = audioUnit
#else
      guard let controller = controller as? VC else { fatalError("nil view controller") }
#endif

      self.wireAudioUnit(avAudioUnit, controller)
    }
  }

  private func wireAudioUnit<T>(_ avAudioUnit: AVAudioUnit, _ viewController: T) {
    guard let viewController = viewController as? VC else { fatalError("unexpected view controller type") }
    self.viewController = viewController

    playEngine.connectEffect(audioUnit: avAudioUnit)
    signalConnected()
  }
  
  private func signalConnected() {
    if viewController != nil {
      DispatchQueue.performOnMain { self.delegate?.connected() }
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

private extension AudioUnitHost {

  private static func loadViewController(appExtension: String) -> FilterViewController {
    guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent(appExtension + ".appex") else {
      fatalError("Could not obtain extension bundle URL")
    }
    guard let extensionBundle = Bundle(url: url) else { fatalError("Could not get app extension bundle") }

#if os(iOS)

    let storyboard = Storyboard(name: "MainInterface", bundle: extensionBundle)
    guard let controller = storyboard.instantiateInitialViewController() as? FilterViewController else {
      fatalError("Unable to instantiate FilterViewController")
    }
    return controller

#elseif os(macOS)

    return FilterViewController(nibName: "FilterViewController", bundle: extensionBundle)

#endif
  }

}
