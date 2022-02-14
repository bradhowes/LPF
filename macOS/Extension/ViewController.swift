// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import KernelBridge
import Kernel
import ParameterAddress
import Parameters
import UI
import os.log

/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc open class ViewController: AUViewController {

  // NOTE: this special form sets the subsystem name and must run before any other logger calls.
  private let log = Shared.logger(Bundle.main.auBaseName + "AU", "ViewController")

  private let parameters = AudioUnitParameters()
  private let kernel = KernelBridge(Bundle.main.auBaseName)

  private var viewConfig: AUAudioUnitViewConfiguration!

  @IBOutlet weak var filterView: FilterView!

  private var parameterTreeObserverToken: AUParameterObserverToken?
  private var cutoffObserverToken: AUParameterObserverToken?
  private var resonanceObserverToken: AUParameterObserverToken?

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

public extension ViewController {

  override func viewDidLoad() {
    os_log(.info, log: log, "viewDidLoad BEGIN")
    super.viewDidLoad()

    filterView.delegate = self

    view.backgroundColor = .black
    if audioUnit != nil {
      connectViewToAU()
    }
  }
}

// MARK: - FilterViewDelegate

extension ViewController: FilterViewDelegate {

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
    updateFilterViewFrequencyAndMagnitudes()
  }
}

// MARK: - AudioUnitViewConfigurationManager

extension ViewController: AudioUnitViewConfigurationManager {}

// MARK: - AUAudioUnitFactory

extension ViewController: AUAudioUnitFactory {
  @objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    let audioUnit = try FilterAudioUnitFactory.create(componentDescription: componentDescription,
                                                      parameters: parameters, kernel: kernel,
                                                      currentPresetMonitor: self,
                                                      viewConfigurationManager: self)
    self.audioUnit = audioUnit
    return audioUnit
  }
}

extension ViewController: CurrentPresetMonitor {
  public func currentPresetChanged(_ value: AUAudioUnitPreset?) {
    DispatchQueue.main.async { self.updateDisplay() }
  }
}

// MARK: - Private

extension ViewController {

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
