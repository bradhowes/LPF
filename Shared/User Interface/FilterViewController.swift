// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import CoreAudioKit
import os.log

/**
 Controller for the AUv3 filter view. Updates AUParameter values based on activity in the FilterView.
 */
public final class FilterViewController: AUViewController {
  private let log = Logging.logger("FilterViewController")

  private var cutoffParameter: AUParameter!
  private var resonanceParameter: AUParameter!
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

  public func filterViewInteractionStarted(_ view: FilterView) {
    os_log(.debug, log: log, "filterViewInteractionStarted")
    cutoffParameter.setValue(view.cutoff, originator: parameterTreeObserverToken, atHostTime: 0,
                             eventType: .touch)
    resonanceParameter.setValue(view.resonance, originator: parameterTreeObserverToken, atHostTime: 0,
                                eventType: .touch)
  }

  public func filterViewInteracted(_ view: FilterView, cutoff: Float, resonance: Float) {
    os_log(.debug, log: log, "filterViewInteracted: cutoff: %f resonance: %f", cutoff, resonance)
    cutoffParameter.setValue(cutoff, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .value)
    resonanceParameter.setValue(resonance, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .value)
    updateFilterViewFrequencyAndMagnitudes()
    audioUnit?.currentPreset = nil
  }

  public func filterViewInteractionEnded(_ view: FilterView) {
    os_log(.debug, log: log, "filterViewInteractionEnded")
    cutoffParameter.setValue(filterView.cutoff, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .release)
    resonanceParameter.setValue(filterView.resonance, originator: parameterTreeObserverToken, atHostTime: 0,
                            eventType: .release)
  }

  public func filterViewLayoutChanged(_ view: FilterView) {
    os_log(.debug, log: log, "filterViewLayoutChanged")
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

    // Validate parameter tree contents
    guard let cutoffParameter = paramTree.parameter(withAddress: .cutoff),
          let resonanceParameter = paramTree.parameter(withAddress: .resonance)
    else {
      fatalError("logic error -- missing parameter(s)")
    }

    self.cutoffParameter = cutoffParameter
    self.resonanceParameter = resonanceParameter

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
    filterView.cutoff = cutoffParameter.value
    filterView.resonance = resonanceParameter.value
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
