// Copyright © 2020 Brad Howes. All rights reserved.

import UIKit
import LowPassFilterFramework

final class MainViewController: UIViewController {

    private let cutoffSliderMinValue: Float = 0.0
    private let cutoffSliderMaxValue: Float = 9.0
    private lazy var cutoffSliderMaxValuePower2Minus1 = Float(pow(2, cutoffSliderMaxValue) - 1)

    private let audioUnitManager = AudioUnitManager<FilterViewController>(componentDescription: FilterAudioUnit.componentDescription, appExt: "LPF")
    private var cutoff: AUParameter? { audioUnitManager.auAudioUnit?.parameterDefinitions.cutoff }
    private var resonance: AUParameter? { audioUnitManager.auAudioUnit?.parameterDefinitions.resonance }

    @IBOutlet var playButton: UIButton!

    @IBOutlet var cutoffSlider: UISlider!
    @IBOutlet var cutoffTextField: UITextField!

    @IBOutlet var resonanceSlider: UISlider!
    @IBOutlet var resonanceTextField: UITextField!
    
    @IBOutlet var containerView: UIView!

    private var filterView: UIView?
    private var parameterObserverToken: AUParameterObserverToken?

    override func viewDidLoad() {
        super.viewDidLoad()
        audioUnitManager.delegate = self
        cutoffSlider.minimumValue = cutoffSliderMinValue
        cutoffSlider.maximumValue = cutoffSliderMaxValue
    }

    @IBAction private func togglePlay(_ sender: UIButton) {
        let isPlaying = audioUnitManager.togglePlayback()
        let titleText = isPlaying ? "Stop" : "Play"
        playButton.setTitle(titleText, for: .normal)
    }

    @IBAction private func cutoffSliderValueChanged(_ sender: UISlider) {
        cutoff?.value = frequencyValueForSliderLocation(sender.value)
    }

    @IBAction private func resonanceSliderValueChanged(_ sender: UISlider) {
        resonance?.value = sender.value
    }
}

private extension MainViewController {

    private func sliderLocationForFrequencyValue(_ frequency: Float) -> Float {
        log(((frequency - FilterView.hertzMin) / (FilterView.hertzMax - FilterView.hertzMin)) *
            cutoffSliderMaxValuePower2Minus1 + 1.0) / log(2)
    }

    private func frequencyValueForSliderLocation(_ location: Float) -> Float {
        ((pow(2, location) - 1) / cutoffSliderMaxValuePower2Minus1) * (FilterView.hertzMax - FilterView.hertzMin) +
            FilterView.hertzMin
    }
}

extension MainViewController: AudioUnitManagerDelegate {

    func connected() {
        connectFilterView()
        connectParametersToControls()
    }

    private func connectFilterView() {
        guard let viewController = audioUnitManager.viewController else { fatalError() }
        filterView = viewController.view
        containerView.addSubview(filterView!)
        filterView?.pinToSuperviewEdges()

        addChild(viewController)
        view.setNeedsLayout()
        containerView.setNeedsLayout()
    }

    private func connectParametersToControls() {
        guard let auAudioUnit = audioUnitManager.auAudioUnit else {
            fatalError("Couldn't locate FilterAudioUnit")
        }

        guard let parameterTree = auAudioUnit.parameterTree else {
            fatalError("FilterAudioUnit does not define any parameters.")
        }

        guard let cutoffParameter = parameterTree.parameter(withAddress: FilterParameterAddress.cutoff.rawValue) else {
            fatalError("Undefined cutoff parameter")
        }

        let minimumValue = cutoffParameter.minValue
        print("cutoffParameter.minValue: \(minimumValue)")
        let maximumValue = cutoffParameter.maxValue
        print("cutoffParameter.maxValue: \(maximumValue)")


        guard let resonanceParameter = parameterTree.parameter(withAddress: FilterParameterAddress.resonance.rawValue)
        else {
            fatalError("Undefined resonance parameter")
        }

        resonanceSlider.minimumValue = resonanceParameter.minValue
        resonanceSlider.maximumValue = resonanceParameter.maxValue

        parameterObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let self = self else { return }
            switch address {

            case FilterParameterAddress.cutoff.rawValue:
                DispatchQueue.main.async { self.cutoffValueDidChange(value) }

            case FilterParameterAddress.resonance.rawValue:
                DispatchQueue.main.async { self.resonanceValueDidChange(value) }

            default: break
            }
        })
    }

    func cutoffValueDidChange(_ value: Float) {
        // let normalizedValue = ((value - FilterView.hertzMin) / (FilterView.hertzMax - FilterView.hertzMin)) * 511 + 1
        cutoffSlider.value = sliderLocationForFrequencyValue(value)
        cutoffTextField.text = String(format: "%.f", value)
    }

    func resonanceValueDidChange(_ value: Float) {
        resonanceSlider.value = value
        resonanceTextField.text = String(format: "%.2f", value)
    }
}
