// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import UIKit
import LowPassFilterFramework

final class MainViewController: UIViewController {

    private let cutoffSliderMinValue: Float = 0.0
    private let cutoffSliderMaxValue: Float = 9.0
    private lazy var cutoffSliderMaxValuePower2Minus1 = Float(pow(2, cutoffSliderMaxValue) - 1)

    private let audioUnitManager = AudioUnitManager(componentDescription: FilterAudioUnit.componentDescription,
                                                    appExtension: Bundle.main.auBaseName)
    private var cutoff: AUParameter? { audioUnitManager.audioUnit?.parameterDefinitions.cutoff }
    private var resonance: AUParameter? { audioUnitManager.audioUnit?.parameterDefinitions.resonance }

    @IBOutlet weak var reviewButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var bypassButton: UIButton!
    @IBOutlet weak var cutoffSlider: UISlider!
    @IBOutlet weak var cutoffValue: UILabel!
    @IBOutlet weak var resonanceSlider: UISlider!
    @IBOutlet weak var resonanceValue: UILabel!
    @IBOutlet weak var containerView: UIView!

    private var parameterObserverToken: AUParameterObserverToken?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let delegate = UIApplication.shared.delegate as? AppDelegate else { fatalError() }
        delegate.setMainViewController(self)

        let version = Bundle.main.releaseVersionNumber
        reviewButton.setTitle(version, for: .normal)

        audioUnitManager.delegate = self
        cutoffSlider.minimumValue = cutoffSliderMinValue
        cutoffSlider.maximumValue = cutoffSliderMaxValue
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let showedAlertKey = "showedInitialAlert"
        guard UserDefaults.standard.bool(forKey: showedAlertKey) == false else { return }
        UserDefaults.standard.set(true, forKey: showedAlertKey)
        let alert = UIAlertController(title: "AUv3 Component Installed",
                                      message: nil, preferredStyle: .alert)
        alert.message =
"""
The AUv3 component 'SimplyLowPass' is now available on your device.

This app uses the component to demonstrate how it works and sounds.
"""
        alert.addAction(
            UIAlertAction(title: "OK", style: .default, handler: { _ in })
        )
        present(alert, animated: true)
    }

    public func stopPlaying() {
        audioUnitManager.cleanup()
    }

    @IBAction private func togglePlay(_ sender: UIButton) {
        let isPlaying = audioUnitManager.togglePlayback()
        let titleText = isPlaying ? "Stop" : "Play"
        playButton.setTitle(titleText, for: .normal)
        playButton.setTitleColor(isPlaying ? .systemRed : .systemTeal, for: .normal)
    }

    @IBAction private func toggleBypass(_ sender: UIButton) {
        let wasBypassed = audioUnitManager.audioUnit?.shouldBypassEffect ?? false
        let isBypassed = !wasBypassed
        audioUnitManager.audioUnit?.shouldBypassEffect = isBypassed

        let titleText = isBypassed ? "Resume" : "Bypass"
        bypassButton.setTitle(titleText, for: .normal)
        bypassButton.setTitleColor(isBypassed ? .systemYellow : .systemTeal, for: .normal)
    }

    @IBAction private func cutoffSliderValueChanged(_ sender: UISlider) {
        cutoff?.value = frequencyValueForSliderLocation(sender.value)
    }

    @IBAction private func resonanceSliderValueChanged(_ sender: UISlider) {
        resonance?.value = sender.value
    }

    @IBAction private func visitAppStore(_ sender: UIButton) {
        let appStoreId = Bundle.main.appStoreId
        guard let url = URL(string: "https://itunes.apple.com/app/id\(appStoreId)") else {
            fatalError("Expected a valid URL")
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    @IBAction private func reviewApp(_ sender: UIButton) {
        AppStore.visitAppStore()
    }
}

extension MainViewController: AudioUnitManagerDelegate {

    func connected() {
        connectFilterView()
        connectParametersToControls()
    }
}

extension MainViewController {

    private func connectFilterView() {
        let viewController = audioUnitManager.viewController
        guard let filterView = viewController.view else { fatalError("no view found from audio unit") }
        containerView.addSubview(filterView)
        filterView.pinToSuperviewEdges()

        addChild(viewController)
        view.setNeedsLayout()
        containerView.setNeedsLayout()
    }

    private func connectParametersToControls() {
        guard let audioUnit = audioUnitManager.audioUnit else {
            fatalError("Couldn't locate FilterAudioUnit")
        }
        guard let parameterTree = audioUnit.parameterTree else {
            fatalError("FilterAudioUnit does not define any parameters.")
        }
        guard let cutoffParameter = parameterTree.parameter(withAddress: .cutoff) else {
            fatalError("Undefined cutoff parameter")
        }
        guard let resonanceParameter = parameterTree.parameter(withAddress: .resonance) else {
            fatalError("Undefined resonance parameter")
        }

        resonanceSlider.minimumValue = resonanceParameter.minValue
        resonanceSlider.maximumValue = resonanceParameter.maxValue

        parameterObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let self = self else { return }
            switch address.filterParameter {
            case .cutoff: DispatchQueue.main.async { self.cutoffValueDidChange(value) }
            case .resonance: DispatchQueue.main.async { self.resonanceValueDidChange(value) }
            default: break
            }
        })

        cutoffValueDidChange(cutoffParameter.value)
        resonanceValueDidChange(resonanceParameter.value)
    }

    private func cutoffValueDidChange(_ value: Float) {
        cutoffSlider.value = sliderLocationForFrequencyValue(value)
        cutoffValue.text = String(format: "%.2f", value)
    }

    private func resonanceValueDidChange(_ value: Float) {
        resonanceSlider.value = value
        resonanceValue.text = String(format: "%.2f", value)
    }

    func sliderLocationForFrequencyValue(_ frequency: Float) -> Float {
        log(((frequency - FilterView.hertzMin) / (FilterView.hertzMax - FilterView.hertzMin)) *
                cutoffSliderMaxValuePower2Minus1 + 1.0) / log(2)
    }

    func frequencyValueForSliderLocation(_ location: Float) -> Float {
        ((pow(2, location) - 1) / cutoffSliderMaxValuePower2Minus1) * (FilterView.hertzMax - FilterView.hertzMin) +
            FilterView.hertzMin
    }
}
