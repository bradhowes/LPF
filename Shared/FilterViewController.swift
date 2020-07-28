// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import CoreAudioKit
import os

public protocol FilterViewAudioUnitLink {
    associatedtype AudioUnitType

    func setAudioUnit(_ audioUnit: AudioUnitType)
}

/**
 Controller for the AUv3 filter view.
 */
public final class FilterViewController: AUViewController {

    private let log = Logging.logger("FilterViewController")

    private var cutoffParam: AUParameter!
    private var resonanceParam: AUParameter!
    private var paramObserverToken: AUParameterObserverToken?

    @IBOutlet private weak var filterView: FilterView!

    private var observer: NSKeyValueObservation?

    public private(set) var audioUnit: FilterAudioUnit? {
        didSet {
            os_log(.debug, log: log, "connection audioUnit")
            performOnMain { if self.isViewLoaded { self.connectViewToAU() } }
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
}

extension FilterViewController: FilterViewAudioUnitLink {
    public typealias AudioUnitType = FilterAudioUnit

    public func setAudioUnit(_ audioUnit: FilterAudioUnit) {
        self.audioUnit = audioUnit
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
        cutoffParam.setValue(view.cutoff, originator: paramObserverToken, atHostTime: 0, eventType: .touch)
        resonanceParam.setValue(view.resonance, originator: paramObserverToken, atHostTime: 0, eventType: .touch)
    }
    
    public func filterView(_ view: FilterView, didChangeResonance resonance: Float) {
        os_log(.debug, log: log, "resonance changed: %f", resonance)
        resonanceParam.setValue(resonance, originator: paramObserverToken, atHostTime: 0, eventType: .value)
        updateFilterViewFrequencyAndMagnitudes()
    }

    public func filterView(_ view: FilterView, didChangeCutoff cutoff: Float) {
        os_log(.debug, log: log, "cutoff changed: %f", cutoff)
        cutoffParam.setValue(cutoff, originator: paramObserverToken, atHostTime: 0, eventType: .value)
        updateFilterViewFrequencyAndMagnitudes()
    }

    public func filterView(_ view: FilterView, didChangeCutoff cutoff: Float, andResonance resonance: Float) {
        os_log(.debug, log: log, "changed cutoff: %f resonance: %f", cutoff, resonance)
        cutoffParam.setValue(cutoff, originator: paramObserverToken, atHostTime: 0, eventType: .value)
        resonanceParam.setValue(resonance, originator: paramObserverToken, atHostTime: 0, eventType: .value)
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

private extension FilterViewController {

    private func updateFilterViewFrequencyAndMagnitudes() {
        guard let audioUnit = audioUnit else { return }
        filterView.makeFilterResponseCurve(audioUnit.magnitudes(forFrequencies: filterView.responseCurveFrequencies))
        filterView.setNeedsDisplay()
    }

    private func connectViewToAU() {
        os_log(.info, log: log, "connectViewToAU")

        guard let audioUnit = audioUnit else {
            os_log(.error, log: log, "logic error -- nil audioUnit value")
            fatalError("logic error -- nil audioUnit value")
        }

        guard let paramTree = audioUnit.parameterTree else {
            os_log(.error, log: log, "logic error -- nil parameterTree")
            fatalError("logic error -- nil parameterTree")
        }

        // Fetch the expected parameters from the parameter tree. We could fetch directly from audioUnit, but this way
        // we show that the tree was setup correctly.
        let pdefs = audioUnit.parameterDefinitions
        guard let cutoffParam = paramTree.value(forKey: pdefs.cutoffParam.identifier) as? AUParameter,
            let resonanceParam = paramTree.value(forKey: pdefs.resonanceParam.identifier) as? AUParameter else {
                os_log(.error, log: log, "logic error -- missing parameter(s)")
                fatalError("logic error -- missing parameter(s)")
        }

        self.cutoffParam = cutoffParam
        self.resonanceParam = resonanceParam

        // Update display when a runtime parameter changes
        paramObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let self = self else { return }
            os_log(.info, log: self.log, "- parameter value changed: %d %f", address, value)
            self.performOnMain{ self.updateDisplay() }
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

    private func update(parameter: AUParameter, with textField: TextField) {
        guard let value = (textField.text as NSString?)?.floatValue else { return }
        parameter.value = value
        textField.text = parameter.string(fromValue: nil)
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
