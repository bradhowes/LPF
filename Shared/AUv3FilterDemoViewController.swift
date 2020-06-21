// Copyright © 2020 Brad Howes. All rights reserved.

import CoreAudioKit

public class AUv3FilterDemoViewController: AUViewController {

    let compact = AUAudioUnitViewConfiguration(width: 400, height: 100, hostHasController: false)
    let expanded = AUAudioUnitViewConfiguration(width: 800, height: 500, hostHasController: false)
    public var viewConfigurations: [AUAudioUnitViewConfiguration] { [expanded, compact] }

    private var viewConfig: AUAudioUnitViewConfiguration!

    private var cutoffParam: AUParameter!
    private var resonanceParam: AUParameter!
    private var paramObserverToken: AUParameterObserverToken?

    @IBOutlet private weak var filterView: FilterView!
    @IBOutlet private weak var frequencyTextField: TextField!
    @IBOutlet private weak var resonanceTextField: TextField!
    
    private var observer: NSKeyValueObservation?

    private var needsConnection = true

    @IBOutlet var compactView: View! { didSet { compactView.setBorder(color: .black, width: 1) } }
    @IBOutlet var expandedView: View! { didSet { expandedView.setBorder(color: .black, width: 1) } }

    public var audioUnit: AUv3FilterDemo? {
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
        
        view.addSubview(expandedView)
        expandedView.pinToSuperviewEdges()

        viewConfig = expanded
        filterView.delegate = self

        #if os(iOS)
        frequencyTextField.delegate = self
        resonanceTextField.delegate = self
        #endif

        guard audioUnit != nil else { return }

        connectViewToAU()
    }

    private func connectViewToAU() {
        guard needsConnection, let paramTree = audioUnit?.parameterTree else { return }
        needsConnection = false

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
        filterView.frequency = cutoffParam.value
        filterView.resonance = resonanceParam.value
        frequencyTextField.text = cutoffParam.string(fromValue: nil)
        resonanceTextField.text = resonanceParam.string(fromValue: nil)
        updateFilterViewFrequencyAndMagnitudes()
    }

    @IBAction private func frequencyUpdated(_ sender: TextField) { update(parameter: cutoffParam, with: sender) }
    @IBAction private func resonanceUpdated(_ sender: TextField) { update(parameter: resonanceParam, with: sender) }

    private func update(parameter: AUParameter, with textField: TextField) {
        guard let value = (textField.text as NSString?)?.floatValue else { return }
        parameter.value = value
        textField.text = parameter.string(fromValue: nil)
    }

    public func toggleViewConfiguration() { audioUnit?.select(viewConfig == expanded ? compact : expanded) }

    public func selectViewConfiguration(_ viewConfig: AUAudioUnitViewConfiguration) {
        guard self.viewConfig != viewConfig else { return }
        self.viewConfig = viewConfig
        if viewConfig.width >= expanded.width && viewConfig.height >= expanded.height {
            performOnMain { self.transitionViews(from: self.compactView, to: self.expandedView) }
        }
        else {
            performOnMain { self.transitionViews(from: self.expandedView, to: self.compactView) }
        }
    }

    #if os(iOS)
    private func transitionViews(from: UIView, to: UIView) {
        UIView.transition(from: from, to: to, duration: 0.2, options: [.transitionCrossDissolve, .layoutSubviews])
        if to == self.expandedView { to.pinToSuperviewEdges() }
    }
    #endif

    #if os(macOS)
    private func transitionViews(from: View, to: View) {
        self.view.addSubview(to)
        from.removeFromSuperview()
        to.pinToSuperviewEdges()
    }
    #endif

    private func performOnMain(_ operation: @escaping () -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { operation() }
            return
        }
        operation()
    }
}

extension AUv3FilterDemoViewController: FilterViewDelegate {

    func updateFilterViewFrequencyAndMagnitudes() {
        guard let audioUnit = audioUnit else { return }
        let frequencies = filterView.frequencyDataForDrawing()
        let magnitudes = audioUnit.magnitudes(forFrequencies: frequencies)
        filterView.setMagnitudes(magnitudes)
    }

    func filterViewTouchBegan(_ view: FilterView) {
        cutoffParam.setValue(view.frequency, originator: paramObserverToken, atHostTime: 0, eventType: .touch)
        resonanceParam.setValue(view.resonance, originator: paramObserverToken, atHostTime: 0, eventType: .touch)
    }
    
    func filterView(_ view: FilterView, didChangeResonance resonance: Float) {
        resonanceParam.setValue(resonance, originator: paramObserverToken, atHostTime: 0, eventType: .value)
        updateFilterViewFrequencyAndMagnitudes()
    }

    func filterView(_ view: FilterView, didChangeFrequency frequency: Float) {
        cutoffParam.setValue(frequency, originator: paramObserverToken, atHostTime: 0, eventType: .value)
        updateFilterViewFrequencyAndMagnitudes()
    }

    func filterView(_ view: FilterView, didChangeFrequency frequency: Float, andResonance resonance: Float) {
        cutoffParam.setValue(frequency, originator: paramObserverToken, atHostTime: 0, eventType: .value)
        resonanceParam.setValue(resonance, originator: paramObserverToken, atHostTime: 0, eventType: .value)
        updateFilterViewFrequencyAndMagnitudes()
    }

    func filterViewTouchEnded(_ view: FilterView) {
        cutoffParam.setValue(filterView.frequency, originator: nil, atHostTime: 0, eventType: .release)
        resonanceParam.setValue(filterView.resonance, originator: nil, atHostTime: 0, eventType: .release)
    }
    
    func filterViewDataDidChange(_ view: FilterView) {
        updateFilterViewFrequencyAndMagnitudes()
    }
}

#if os(iOS)
extension AUv3FilterDemoViewController: UITextFieldDelegate {
    // MARK: UITextFieldDelegate
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
}
#endif
