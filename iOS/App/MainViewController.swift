// Copyright © 2020 Brad Howes. All rights reserved.

import UIKit
import LowPassFilterFramework

final class MainViewController: UIViewController {

    private let cutoffSliderMinValue: Float = 0.0
    private let cutoffSliderMaxValue: Float = 9.0
    private lazy var cutoffSliderMaxValuePower2Minus1 = Float(pow(2, cutoffSliderMaxValue) - 1)

    private let audioUnitManager = AudioUnitManager(componentDescription: FilterAudioUnit.componentDescription)

    @IBOutlet var playButton: UIButton!

    @IBOutlet var cutoffSlider: UISlider!
    @IBOutlet var cutoffTextField: UITextField!

    @IBOutlet var resonanceSlider: UISlider!
    @IBOutlet var resonanceTextField: UITextField!
    
    @IBOutlet var containerView: UIView!

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
        audioUnitManager.cutoffValue = frequencyValueForSliderLocation(sender.value)
    }

    @IBAction private func resonanceSliderValueChanged(_ sender: UISlider) {
        audioUnitManager.resonanceValue = sender.value
    }
}

private extension MainViewController {

    private func logValueForNumber(_ number: Float) -> Float { log(number) / log(2) }

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

    func audioUnitCutoffParameter(_ parameter: AUParameter) {
    }

    func audioUnitResonanceParameter(_ parameter: AUParameter) {
        resonanceSlider.minimumValue = parameter.minValue
        resonanceSlider.maximumValue = parameter.maxValue
    }

    func audioUnitViewController(_ viewController: UIViewController?) {
        guard let viewController = viewController else { return }
        guard let filterView = viewController.view else { return }

        addChild(viewController)
        filterView.frame = containerView.bounds
        containerView.addSubview(filterView)

        filterView.translatesAutoresizingMaskIntoConstraints = false
        filterView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        filterView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        filterView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        filterView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true

        viewController.didMove(toParent: self)
    }

    func cutoffValueDidChange(_ value: Float) {
        let normalizedValue = ((value - FilterView.hertzMin) / (FilterView.hertzMax - FilterView.hertzMin)) * 511 + 1
        cutoffSlider.value = Float(logValueForNumber(normalizedValue))
        cutoffTextField.text = String(format: "%.f", value)
    }

    func resonanceValueDidChange(_ value: Float) {
        resonanceSlider.value = value
        resonanceTextField.text = String(format: "%.2f", value)
    }
}
