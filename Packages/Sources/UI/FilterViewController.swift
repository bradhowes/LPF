// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import KernelBridge
import Kernel
import ParameterAddress
import Parameters

/**
 Controller for the AUv3 filter view. Note that this code is used by *both* iOS and macOS platforms. The only
 requirement to use is to invoke `setFilterView(_)` with the `FilterView` instance that was created from the
 storyboard (iOS) or XIB (macOS) file.
 */
@objc open class FilterViewController: AUViewController {
  private let kernelBridge = KernelBridge(Bundle.main.auBaseName + "AU")
  private let parameters = Parameters()

  private var filterView: FilterView!

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
    parameters.cutoff.setValue(cutoff, originator: cutoffObserverToken, atHostTime: 0, eventType: .touch)
    parameters.resonance.setValue(resonance, originator: resonanceObserverToken, atHostTime: 0, eventType: .touch)
    updateFilterViewFrequencyAndMagnitudes()
    audioUnit?.clearCurrentPresetIfFactoryPreset()
  }

  public func filterViewInteracted(_ view: FilterView, cutoff: Float, resonance: Float) {
    parameters.cutoff.setValue(cutoff, originator: cutoffObserverToken, atHostTime: 0, eventType: .value)
    parameters.resonance.setValue(resonance, originator: resonanceObserverToken, atHostTime: 0, eventType: .value)
    updateFilterViewFrequencyAndMagnitudes()
    audioUnit?.clearCurrentPresetIfFactoryPreset()
  }

  public func filterViewInteractionEnded(_ view: FilterView, cutoff: Float, resonance: Float) {
    parameters.cutoff.setValue(cutoff, originator: cutoffObserverToken, atHostTime: 0, eventType: .release)
    parameters.resonance.setValue(resonance, originator: resonanceObserverToken, atHostTime: 0, eventType: .release)
    updateFilterViewFrequencyAndMagnitudes()
    audioUnit?.clearCurrentPresetIfFactoryPreset()
  }

  public func filterViewLayoutChanged(_ view: FilterView) {
    if audioUnit != nil {
      updateDisplay()
    }
  }
}

// MARK: - AudioUnitViewConfigurationManager

extension FilterViewController: AudioUnitViewConfigurationManager {}

// MARK: - AUAudioUnitFactory

extension FilterViewController: AUAudioUnitFactory {

  // Uff. What a mess to get right. AUv3 infrastructure will invoke this on a thread that is probably *not* the main
  // thread. Be sure to create the audio unit on the main thread and then pass it out. No idea what is actually
  // done with it.
  nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    let audioUnit = try DispatchQueue.main.sync {
      let audioUnit = try FilterAudioUnitFactory.create(componentDescription: componentDescription,
                                                        viewConfigurationManager: self)
      self.audioUnit = audioUnit
      return audioUnit
    }
    return audioUnit
  }
}


// MARK: - Private

extension FilterViewController {

  private func connectViewToAU() {
    audioUnit?.configure(parameters: parameters, kernel: kernelBridge)

    // AU callbacks can and will happen on non-main threads. Declare them as non-isolated and then do the work on the
    // main thread.
    cutoffObserverToken = parameters.cutoff.token(byAddingParameterObserver: parameterChanged(address:value:))
    resonanceObserverToken = parameters.resonance.token(byAddingParameterObserver: parameterChanged(address:value:))
    currentPresetObserverToken = audioUnit?.observe(
      \.currentPreset,
       options: [],
       changeHandler: currentPresetChanged(object:change:)
    )

    updateDisplay()
  }

  nonisolated private func parameterChanged(address: AUParameterAddress, value: AUValue) {
    DispatchQueue.main.async { [weak self] in self?.updateDisplay() }
  }

  nonisolated private func currentPresetChanged(object: FilterAudioUnit,
                                                change: NSKeyValueObservedChange<Optional<AUAudioUnitPreset>>) {
    DispatchQueue.main.async { [weak self] in self?.updateDisplay() }
  }

  private func updateDisplay() {
    filterView.setControlPoint(cutoff: parameters.cutoff.value, resonance: parameters.resonance.value)
    updateFilterViewFrequencyAndMagnitudes()
  }

  private func updateFilterViewFrequencyAndMagnitudes() {
    filterView.makeFilterResponseCurve(magnitudes(forFrequencies: filterView.responseCurveFrequencies))
    filterView.setNeedsDisplay()
  }

  private func magnitudes(forFrequencies frequencies: [Float]) -> [Float] {
    var output: [Float] = Array(repeating: 0.0, count: frequencies.count)
    kernelBridge.magnitudes(frequencies, count: frequencies.count, output: &output)
    return output
  }
}
