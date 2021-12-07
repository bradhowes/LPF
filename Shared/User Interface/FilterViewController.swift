// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import CoreAudioKit
import os

/**
 Controller for the AUv3 filter view.
 */
public final class FilterViewController: AUViewController {
  
  private let log = Logging.logger("FilterViewController")

  private var cutoffParam: AUParameter!
  private var resonanceParam: AUParameter!
  private var allParameterValuesObserverToken: NSKeyValueObservation?
  private var parameterTreeObserverToken: AUParameterObserverToken?

  @IBOutlet private weak var filterView: FilterView!

  /// The audio unit being managed by the view controller. This is set during a call to `createAudioUnit` which can
  /// happen on a non-main thread.
  public var audioUnit: FilterAudioUnit? { didSet { DispatchQueue.performOnMain { self.connectViewToAU() } } }
  
#if os(macOS)
  public override init(nibName: NSNib.Name?, bundle: Bundle?) {
    super.init(nibName: nibName, bundle: Bundle(for: type(of: self)))
  }
#endif
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  public override func viewDidLoad() {
    os_log(.info, log: log, "viewDidLoad")
    super.viewDidLoad()
    filterView.delegate = self
    guard audioUnit != nil else {
      os_log(.info, log: log, "viewDidLoad - no audioUnit created yet")
      return
    }
    connectViewToAU()
  }
}

extension FilterViewController: AUAudioUnitFactory {
  
  /**
   Create a new FilterAudioUnit instance to run in an AVu3 container.
   
   - parameter componentDescription: descriptions of the audio environment it will run in
   - returns: new FilterAudioUnit
   */
  public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    os_log(.info, log: log, "createAudioUnit")
    componentDescription.log(log, type: .debug)
    let audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: [.loadOutOfProcess])
    self.audioUnit = audioUnit
    return audioUnit
  }
}

extension FilterViewController: FilterViewDelegate {
  
  public func filterViewTouchBegan(_ view: FilterView) {
    os_log(.debug, log: log, "touch began")
    cutoffParam.setValue(view.cutoff, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .touch)
    resonanceParam.setValue(view.resonance, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .touch)
  }
  
  public func filterView(_ view: FilterView, didChangeCutoff cutoff: Float, andResonance resonance: Float) {
    os_log(.debug, log: log, "changed cutoff: %f resonance: %f", cutoff, resonance)
    cutoffParam.setValue(cutoff, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .value)
    resonanceParam.setValue(resonance, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .value)
    updateFilterViewFrequencyAndMagnitudes()
    audioUnit?.currentPreset = nil
  }
  
  public func filterViewTouchEnded(_ view: FilterView) {
    os_log(.debug, log: log, "touch ended")
    cutoffParam.setValue(filterView.cutoff, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .release)
    resonanceParam.setValue(filterView.resonance, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .release)
  }
  
  public func filterViewDataDidChange(_ view: FilterView) {
    os_log(.debug, log: log, "dataDidChange")
    updateFilterViewFrequencyAndMagnitudes()
  }
}

extension FilterViewController {

  private func connectViewToAU() {
    os_log(.info, log: log, "connectViewToAU")

    // See if we are ready to connect and have not already done so. We do this check here because there are two paths
    // that can lead to this method being invoked:
    //   1. `createAudioUnit` runs after the view controller has been loaded
    //   2. the view controller finished loading after the `createAudioUnit` has been run
    guard isViewLoaded && parameterTreeObserverToken == nil else {
      os_log(.info, log: log, "connectViewToAU - skipping: %d %d", isViewLoaded, parameterTreeObserverToken == nil)
      return
    }

    guard let audioUnit = audioUnit else { fatalError("logic error -- nil audioUnit") }
    guard let paramTree = audioUnit.parameterTree else { fatalError("logic error -- nil parameterTree") }
    let defs = audioUnit.parameterDefinitions

    // Validate parameter tree contents
    guard let cutoffParam = paramTree.value(forKey: defs.cutoff.identifier) as? AUParameter,
          let resonanceParam = paramTree.value(forKey: defs.resonance.identifier) as? AUParameter else {
      fatalError("logic error -- missing parameter(s)")
    }

    self.cutoffParam = cutoffParam
    self.resonanceParam = resonanceParam

    // Observe major state changes like a user selecting a user preset.
    allParameterValuesObserverToken = audioUnit.observe(\.allParameterValues) { _, _ in
      os_log(.info, log: self.log, "FilterViewController - allParameterValues changed")
      DispatchQueue.performOnMain { self.updateDisplay() }
    }

    parameterTreeObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
      guard let self = self else { return }
      os_log(.info, log: self.log, "FilterViewController - parameter tree changed: %d %f", address, value)
      DispatchQueue.performOnMain { self.updateDisplay() }
    })

    updateDisplay()
  }

  private func updateKernelParameters() {
    filterView.cutoff = cutoffParam.value
    filterView.resonance = resonanceParam.value
  }
  
  private func updateDisplay() {
    updateKernelParameters()
    updateFilterViewFrequencyAndMagnitudes()
  }

  private func updateFilterViewFrequencyAndMagnitudes() {
    guard let audioUnit = audioUnit else { return }
    filterView.makeFilterResponseCurve(audioUnit.magnitudes(forFrequencies: filterView.responseCurveFrequencies))
    filterView.setNeedsDisplay()
  }
}

#if os(iOS)
extension FilterViewController: UITextFieldDelegate {
  
  // MARK: UITextFieldDelegate
  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    view.endEditing(true)
    return false
  }
}
#endif
