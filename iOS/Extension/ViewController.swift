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

  public func filterViewInteractionStarted(_ view: FilterView) {
    os_log(.debug, log: log, "filterViewInteractionStarted")
    parameters.cutoff.setValue(view.cutoff, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .touch)
    parameters.resonance.setValue(view.resonance, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .touch)
  }

  public func filterViewInteracted(_ view: FilterView, cutoff: Float, resonance: Float) {
    os_log(.debug, log: log, "filterViewInteracted: cutoff: %f resonance: %f", cutoff, resonance)
    parameters.cutoff.setValue(view.cutoff, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .value)
    parameters.resonance.setValue(view.resonance, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .value)
    updateFilterViewFrequencyAndMagnitudes()
    audioUnit?.currentPreset = nil
  }

  public func filterViewInteractionEnded(_ view: FilterView) {
    os_log(.debug, log: log, "filterViewInteractionEnded")
    parameters.cutoff.setValue(view.cutoff, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .release)
    parameters.resonance.setValue(view.resonance, originator: parameterTreeObserverToken, atHostTime: 0, eventType: .release)
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
                                                      viewConfigurationManager: self)
    self.audioUnit = audioUnit
    return audioUnit
  }
}

// MARK: - Private

extension ViewController {

  private func connectViewToAU() {
    os_log(.info, log: log, "connectViewToAU")

    parameterTreeObserverToken = parameters.parameterTree.token(byAddingParameterObserver: { [weak self] address, value in
      guard let self = self else { return }
      os_log(.info, log: self.log, "FilterViewController - parameter tree changed: %d %f", address, value)
      DispatchQueue.main.async { self.updateDisplay() }
    })

    updateDisplay()
  }

  private func updateKernelParameters() {
    filterView.cutoff = parameters[.cutoff].value
    filterView.resonance = parameters[.resonance].value
  }

  private func updateDisplay() {
    updateKernelParameters()
    updateFilterViewFrequencyAndMagnitudes()
  }

  private func updateFilterViewFrequencyAndMagnitudes() {
    filterView.makeFilterResponseCurve(magnitudes(forFrequencies: filterView.responseCurveFrequencies))
    filterView.setNeedsDisplay()
  }

  private func magnitudes(forFrequencies frequencies: [Float]) -> [Float] {
    var output: [Float] = Array(repeating: 0.0, count: frequencies.count)
    kernel.magnitudes(frequencies, count: frequencies.count, output: &output)
    return output
  }
}
