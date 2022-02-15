// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import KernelBridge
import Kernel
import ParameterAddress
import Parameters
import os.log

/**
 Controller for the AUv3 filter view. Note that this code is used by *both* iOS and macOS platforms. The only
 requirement to use is to invoke `setFilterView(_)` with the `FilterView` instance that was created from the
 storyboard (iOS) or XIB (macOS) file.
 */
@objc open class FilterViewController: AUViewController {

  private var filterView: FilterView!

  // NOTE: this special form sets the subsystem name and must run before any other logger calls.
  private let log = Shared.logger(Bundle.main.auBaseName + "AU", "ViewController")

  private let parameters = AudioUnitParameters()
  private let kernel = KernelBridge(Bundle.main.auBaseName)

  private var viewConfig: AUAudioUnitViewConfiguration!

  private var cutoffObserverToken: AUParameterObserverToken?
  private var resonanceObserverToken: AUParameterObserverToken?
  private var currentPresetObserverToken: NSKeyValueObservation?

  public var audioUnit: FilterAudioUnit? {
    didSet {
      DispatchQueue.main.async {
        if self.isViewLoaded {
          self.connectViewToAU()
        }
      }
    }
  }
}

extension FilterViewController {

  public func setFilterView(_ view: FilterView) {
    filterView = view
  }
  
  open override func viewDidLoad() {
    os_log(.info, log: log, "viewDidLoad BEGIN")
    precondition(filterView != nil, "setFilterView must be called before viewDidLoad")

    super.viewDidLoad()
    filterView.delegate = self

    view.backgroundColor = .black
    if audioUnit != nil {
      connectViewToAU()
    }
  }
}

// MARK: - FilterViewDelegate

extension FilterViewController: FilterViewDelegate {

  public var filterViewRanges: FilterViewRanges {
    .init(frequencyRange: parameters.cutoff.range, gainRange: parameters.resonance.range)
  }

  public func filterViewInteractionStarted(_ view: FilterView, cutoff: Float, resonance: Float) {
    os_log(.debug, log: log, "filterViewInteractionStarted")
    parameters.cutoff.setValue(cutoff, originator: cutoffObserverToken, atHostTime: 0, eventType: .touch)
    parameters.resonance.setValue(resonance, originator: resonanceObserverToken, atHostTime: 0, eventType: .touch)
    updateFilterViewFrequencyAndMagnitudes()
    audioUnit?.clearCurrentPresetIfFactoryPreset()
  }

  public func filterViewInteracted(_ view: FilterView, cutoff: Float, resonance: Float) {
    os_log(.debug, log: log, "filterViewInteracted: cutoff: %f resonance: %f", cutoff, resonance)
    parameters.cutoff.setValue(cutoff, originator: cutoffObserverToken, atHostTime: 0, eventType: .value)
    parameters.resonance.setValue(resonance, originator: resonanceObserverToken, atHostTime: 0, eventType: .value)
    updateFilterViewFrequencyAndMagnitudes()
    audioUnit?.clearCurrentPresetIfFactoryPreset()
  }

  public func filterViewInteractionEnded(_ view: FilterView, cutoff: Float, resonance: Float) {
    os_log(.debug, log: log, "filterViewInteractionEnded")
    parameters.cutoff.setValue(cutoff, originator: cutoffObserverToken, atHostTime: 0, eventType: .release)
    parameters.resonance.setValue(resonance, originator: resonanceObserverToken, atHostTime: 0, eventType: .release)
    updateFilterViewFrequencyAndMagnitudes()
    audioUnit?.clearCurrentPresetIfFactoryPreset()
  }

  public func filterViewLayoutChanged(_ view: FilterView) {
    os_log(.debug, log: log, "filterViewLayoutChanged")
    if audioUnit != nil {
      updateDisplay()
    }
  }
}

// MARK: - AudioUnitViewConfigurationManager

extension FilterViewController: AudioUnitViewConfigurationManager {}

// MARK: - AUAudioUnitFactory

extension FilterViewController: AUAudioUnitFactory {
  @objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    let audioUnit = try FilterAudioUnitFactory.create(componentDescription: componentDescription,
                                                      parameters: parameters, kernel: kernel,
                                                      viewConfigurationManager: self)
    self.audioUnit = audioUnit

    currentPresetObserverToken = audioUnit.observe(\.currentPreset, options: []) { object, change in
      os_log(.error, log: self.log, "currentPreset changed")
      DispatchQueue.main.async {
        self.updateDisplay()
      }
    }

    return audioUnit
  }
}

// MARK: - Private

extension FilterViewController {

  private func connectViewToAU() {
    os_log(.info, log: log, "connectViewToAU")

    cutoffObserverToken = parameters.cutoff.token(byAddingParameterObserver: { [weak self] address, value in
      guard let self = self else { return }
      DispatchQueue.main.async { self.updateDisplay() }
    })

    resonanceObserverToken = parameters.resonance.token(byAddingParameterObserver: { [weak self] address, value in
      guard let self = self else { return }
      DispatchQueue.main.async { self.updateDisplay() }
    })

    updateDisplay()
  }

  private func updateDisplay() {
    os_log(.info, log: log, "updateDisplay BEGIN - cutoff: %f resonance: %f", parameters.cutoff.value,
           parameters.resonance.value)
    filterView.setControlPoint(cutoff: parameters.cutoff.value, resonance: parameters.resonance.value)
    updateFilterViewFrequencyAndMagnitudes()
    os_log(.info, log: log, "updateDisplay END")
  }

  private func updateFilterViewFrequencyAndMagnitudes() {
    filterView.makeFilterResponseCurve(magnitudes(forFrequencies: filterView.responseCurveFrequencies))
    filterView.setNeedsDisplay()
  }

  private func magnitudes(forFrequencies frequencies: [Float]) -> [Float] {
    os_log(.info, log: log, "magnitudes BEGIN - cutoff: %f resonance: %f", parameters.cutoff.value,
           parameters.resonance.value)
    var output: [Float] = Array(repeating: 0.0, count: frequencies.count)
    kernel.magnitudes(frequencies, count: frequencies.count, output: &output)
    return output
  }
}
