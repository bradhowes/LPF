// Copyright © 2020 Brad Howes. All rights reserved.

import UIKit
import AUv3FilterFramework

class MainViewController: UIViewController {

    let audioUnitManager = AudioUnitManager()

    @IBOutlet var playButton: UIButton!
    @IBOutlet var toggleButton: UIButton!

    @IBOutlet var cutoffSlider: UISlider!
    @IBOutlet var cutoffTextField: UITextField!

    @IBOutlet var resonanceSlider: UISlider!
    @IBOutlet var resonanceTextField: UITextField!
    
    @IBOutlet var containerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        embedPlugInView()
        audioUnitManager.delegate = self
    }

    private func embedPlugInView() {
        guard let controller = audioUnitManager.viewController else {
            fatalError("Could not load audio unit's view controller.")
        }

        if let view = controller.view {
            addChild(controller)
            view.frame = containerView.bounds
            containerView.addSubview(view)
            view.pinToSuperviewEdges()
            controller.didMove(toParent: self)
        }
    }

    @IBAction func togglePlay(_ sender: UIButton) {
        let isPlaying = audioUnitManager.togglePlayback()
        let titleText = isPlaying ? "Stop" : "Play"
        playButton.setTitle(titleText, for: .normal)
    }

    @IBAction func toggleView(_ sender: UIButton) {
        audioUnitManager.toggleView()
    }

    @IBAction func cutoffSliderValueChanged(_ sender: UISlider) {
        audioUnitManager.cutoffValue = frequencyValueForSliderLocation(sender.value)
    }

    @IBAction func resonanceSliderValueChanged(_ sender: UISlider) {
        audioUnitManager.resonanceValue = sender.value
    }
}

private extension MainViewController {

    func logValueForNumber(_ number: Float) -> Float {
        return log(number) / log(2)
    }
    
    func frequencyValueForSliderLocation(_ location: Float) -> Float {
        var value = pow(2, location)
        value = (value - 1) / 511

        value *= (defaultMaxHertz - defaultMinHertz)

        return value + defaultMinHertz
    }
}

extension MainViewController: AUManagerDelegate {
    func cutoffValueDidChange(_ value: Float) {
        let normalizedValue = ((value - defaultMinHertz) / (defaultMaxHertz - defaultMinHertz)) * 511 + 1
        cutoffSlider.value = Float(logValueForNumber(normalizedValue))
        cutoffTextField.text = String(format: "%.f", value)
    }

    func resonanceValueDidChange(_ value: Float) {
        resonanceSlider.value = value
        resonanceTextField.text = String(format: "%.2f", value)
    }
}

