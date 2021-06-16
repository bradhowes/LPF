// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import CoreAudioKit
import os

/**
 Controller for the AUv3 filter view.
 */
public final class FilterViewController: AUViewController {
  
  private let log = Logging.logger("FilterViewController")
  
  private var viewConfig: AUAudioUnitViewConfiguration!
  private var cutoffParam: AUParameter!
  private var resonanceParam: AUParameter!
  private var parameterObserverToken: AUParameterObserverToken?
  private var keyValueObserverToken: NSKeyValueObservation?
  
  @IBOutlet private weak var filterView: FilterView!
  
  public var audioUnit: FilterAudioUnit? {
    didSet {
      performOnMain {
        if self.isViewLoaded {
          self.connectViewToAU()
        }
      }
    }
  }
  
  #if os(macOS)
  public override init(nibName: NSNib.Name?, bundle: Bundle?) {
    super.init(nibName: nibName, bundle: Bundle(for: type(of: self)))
  }
  #endif
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    filterView.delegate = self
    guard audioUnit != nil else { return }
    connectViewToAU()
  }
  
  public func selectViewConfiguration(_ viewConfig: AUAudioUnitViewConfiguration) {
    guard self.viewConfig != viewConfig else { return }
    self.viewConfig = viewConfig
  }
}

extension FilterViewController: AUAudioUnitFactory {
  
  /**
   Create a new FilterAudioUnit instance to run in an AVu3 container.
   
   - parameter componentDescription: descriptions of the audio environment it will run in
   - returns: new FilterAudioUnit
   */
  public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    os_log(.info, log: log, "creating new audio unit")
    componentDescription.log(log, type: .debug)
    audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: [.loadOutOfProcess])
    return audioUnit!
  }
}

extension FilterViewController: FilterViewDelegate {
  
  public func filterViewTouchBegan(_ view: FilterView) {
    os_log(.debug, log: log, "touch began")
    cutoffParam.setValue(view.cutoff, originator: parameterObserverToken, atHostTime: 0, eventType: .touch)
    resonanceParam.setValue(view.resonance, originator: parameterObserverToken, atHostTime: 0, eventType: .touch)
  }
  
  public func filterView(_ view: FilterView, didChangeCutoff cutoff: Float, andResonance resonance: Float) {
    os_log(.debug, log: log, "changed cutoff: %f resonance: %f", cutoff, resonance)
    cutoffParam.setValue(cutoff, originator: parameterObserverToken, atHostTime: 0, eventType: .value)
    resonanceParam.setValue(resonance, originator: parameterObserverToken, atHostTime: 0, eventType: .value)
    updateFilterViewFrequencyAndMagnitudes()
  }
  
  public func filterViewTouchEnded(_ view: FilterView) {
    os_log(.debug, log: log, "touch ended")
    cutoffParam.setValue(filterView.cutoff, originator: nil, atHostTime: 0, eventType: .release)
    resonanceParam.setValue(filterView.resonance, originator: nil, atHostTime: 0, eventType: .release)
  }
  
  public func filterViewDataDidChange(_ view: FilterView) {
    os_log(.debug, log: log, "dataDidChange")
    updateFilterViewFrequencyAndMagnitudes()
  }
}

extension FilterViewController {
  
  private func updateFilterViewFrequencyAndMagnitudes() {
    guard let audioUnit = audioUnit else { return }
    filterView.makeFilterResponseCurve(audioUnit.magnitudes(forFrequencies: filterView.responseCurveFrequencies))
    filterView.setNeedsDisplay()
  }
  
  private func connectViewToAU() {
    os_log(.info, log: log, "connectViewToAU")
    
    guard parameterObserverToken == nil else { return }
    
    guard let audioUnit = audioUnit else {
      fatalError("logic error -- nil audioUnit value")
    }
    
    guard let paramTree = audioUnit.parameterTree else {
      fatalError("logic error -- nil parameterTree")
    }
    
    let defs = audioUnit.parameterDefinitions
    guard let cutoffParam = paramTree.value(forKey: defs.cutoff.identifier) as? AUParameter,
          let resonanceParam = paramTree.value(forKey: defs.resonance.identifier) as? AUParameter else {
      fatalError("logic error -- missing parameter(s)")
    }
    
    self.cutoffParam = cutoffParam
    self.resonanceParam = resonanceParam
    
    // Observe major state changes like a user selecting a user preset.
    keyValueObserverToken = audioUnit.observe(\.allParameterValues) { _, _ in
      self.performOnMain { self.updateDisplay() }
    }
    
    parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
      guard let self = self else { return }
      os_log(.info, log: self.log, "- parameter value changed: %d %f", address, value)
      self.performOnMain { self.updateDisplay() }
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
  
  private func performOnMain(_ operation: @escaping () -> Void) {
    (Thread.isMainThread ? operation : { DispatchQueue.main.async { operation() } })()
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
