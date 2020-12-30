// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import CoreAudioKit
import os

/**
 Controller for the AUv3 filter view.
 */
public final class FilterViewController: AUViewController {

    private let log = Logging.logger("FilterViewController")
    private let compact = AUAudioUnitViewConfiguration(width: 400, height: 100, hostHasController: false)
    private let expanded = AUAudioUnitViewConfiguration(width: 800, height: 500, hostHasController: false)

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
        // If requested configuration is already active, do nothing
        guard self.viewConfig != viewConfig else { return }
        self.viewConfig = viewConfig

//        let isDefault = viewConfig.width >= expanded.width && viewConfig.height >= expanded.height
//        let fromView = isDefault ? compactView : expandedView
//        let toView = isDefault ? expandedView : compactView
//
//        performOnMain {
//            #if os(iOS)
//            UIView.transition(from: fromView!,
//                              to: toView!,
//                              duration: 0.2,
//                              options: [.transitionCrossDissolve, .layoutSubviews])
//
//            if toView == self.expandedView {
//                toView?.pinToSuperviewEdges()
//            }
//
//            #elseif os(macOS)
//            self.view.addSubview(toView!)
//            fromView!.removeFromSuperview()
//            toView!.pinToSuperviewEdges()
//            #endif
//        }
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
    
    public func filterView(_ view: FilterView, didChangeResonance resonance: Float) {
        os_log(.debug, log: log, "resonance changed: %f", resonance)
        resonanceParam.setValue(resonance, originator: parameterObserverToken, atHostTime: 0, eventType: .value)
        updateFilterViewFrequencyAndMagnitudes()
    }

    public func filterView(_ view: FilterView, didChangeCutoff cutoff: Float) {
        os_log(.debug, log: log, "cutoff changed: %f", cutoff)
        cutoffParam.setValue(cutoff, originator: parameterObserverToken, atHostTime: 0, eventType: .value)
        updateFilterViewFrequencyAndMagnitudes()
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
            os_log(.error, log: log, "logic error -- nil audioUnit value")
            fatalError("logic error -- nil audioUnit value")
        }

        guard let paramTree = audioUnit.parameterTree else {
            os_log(.error, log: log, "logic error -- nil parameterTree")
            fatalError("logic error -- nil parameterTree")
        }

        let defs = audioUnit.parameterDefinitions
        guard let cutoffParam = paramTree.value(forKey: defs.cutoff.identifier) as? AUParameter,
              let resonanceParam = paramTree.value(forKey: defs.resonance.identifier) as? AUParameter else {
            os_log(.error, log: log, "logic error -- missing parameter(s)")
            fatalError("logic error -- missing parameter(s)")
        }

        self.cutoffParam = cutoffParam
        self.resonanceParam = resonanceParam

        // Observe major state changes like a user selecting a user preset.
        keyValueObserverToken = audioUnit.observe(\.allParameterValues) { _, _ in self.performOnMain { self.updateDisplay() } }

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
