// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import CoreAudioKit

/**
 Controller for the AUv3 filter view.
 */
public final class FilterViewController: AUViewController {

    private var cutoffParam: AUParameter!
    private var resonanceParam: AUParameter!
    private var paramObserverToken: AUParameterObserverToken?

    @IBOutlet private weak var filterView: FilterView!

    private var observer: NSKeyValueObservation?

    public var audioUnit: FilterAudioUnit? {
        didSet {
            audioUnit?.viewController = self
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

extension FilterViewController: AUAudioUnitFactory {

    /**
     Create a new FilterAudioUnit instance to run in an AVu3 container.

     - parameter componentDescription: descriptions of the audio environment it will run in
     - returns: new FilterAudioUnit
     */
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: [])
        return audioUnit!
    }
}

extension FilterViewController: FilterViewDelegate {

    public func filterViewTouchBegan(_ view: FilterView) {
        cutoffParam.setValue(view.cutoff, originator: paramObserverToken, atHostTime: 0, eventType: .touch)
        resonanceParam.setValue(view.resonance, originator: paramObserverToken, atHostTime: 0, eventType: .touch)
    }
    
    public func filterView(_ view: FilterView, didChangeResonance resonance: Float) {
        resonanceParam.setValue(resonance, originator: paramObserverToken, atHostTime: 0, eventType: .value)
        updateFilterViewFrequencyAndMagnitudes()
    }

    public func filterView(_ view: FilterView, didChangeCutoff cutoff: Float) {
        cutoffParam.setValue(cutoff, originator: paramObserverToken, atHostTime: 0, eventType: .value)
        updateFilterViewFrequencyAndMagnitudes()
    }

    public func filterView(_ view: FilterView, didChangeCutoff cutoff: Float, andResonance resonance: Float) {
        cutoffParam.setValue(cutoff, originator: paramObserverToken, atHostTime: 0, eventType: .value)
        resonanceParam.setValue(resonance, originator: paramObserverToken, atHostTime: 0, eventType: .value)
        updateFilterViewFrequencyAndMagnitudes()
    }

    public func filterViewTouchEnded(_ view: FilterView) {
        cutoffParam.setValue(filterView.cutoff, originator: nil, atHostTime: 0, eventType: .release)
        resonanceParam.setValue(filterView.resonance, originator: nil, atHostTime: 0, eventType: .release)
    }
    
    public func filterViewDataDidChange(_ view: FilterView) {
        updateFilterViewFrequencyAndMagnitudes()
    }
}

private extension FilterViewController {

    private func updateFilterViewFrequencyAndMagnitudes() {
        guard let audioUnit = audioUnit else { return }
        filterView.makeFilterResponseCurve(audioUnit.magnitudes(forFrequencies: filterView.responseCurveFrequencies))
    }

    private func connectViewToAU() {
        guard let paramTree = audioUnit?.parameterTree else { return }

        guard let cutoff = paramTree.value(forKey: "cutoff") as? AUParameter,
            let resonance = paramTree.value(forKey: "resonance") as? AUParameter else {
                fatalError("Required AU parameters not found.")
        }

        cutoffParam = cutoff
        resonanceParam = resonance
        observer = audioUnit?.observe(\.allParameterValues) { _, _ in self.performOnMain { self.updateDisplay() } }

        paramObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let self = self else { return }
            if address == cutoff.address || address == resonance.address {
                self.performOnMain{ self.updateDisplay() }
            }
        })

        updateDisplay()
    }

    private func updateDisplay() {
        filterView.cutoff = cutoffParam.value
        filterView.resonance = resonanceParam.value
        updateFilterViewFrequencyAndMagnitudes()
    }

    private func update(parameter: AUParameter, with textField: TextField) {
        guard let value = (textField.text as NSString?)?.floatValue else { return }
        parameter.value = value
        textField.text = parameter.string(fromValue: nil)
    }

    private func performOnMain(_ operation: @escaping () -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { operation() }
            return
        }
        operation()
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
