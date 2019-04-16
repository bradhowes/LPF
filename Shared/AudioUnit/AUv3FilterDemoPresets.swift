/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The object managing the filter's factory presets.
*/

import Foundation

protocol AUv3FilterDemoPresetSelectionObserver: AnyObject {
    func didSelectPreset(cutoff: AUValue, resonance: AUValue)
}

extension AUAudioUnitPreset {
    convenience init(number: Int, name: String) {
        self.init()
        self.number = number
        self.name = name
    }
}

/// Manages the AUv3Filter object's factory presets.
class AUv3FilterDemoPresets {

    let factoryPresets = [
        AUAudioUnitPreset(number: 0, name: "Prominent"),
        AUAudioUnitPreset(number: 1, name: "Bright"),
        AUAudioUnitPreset(number: 2, name: "Warm")
    ]

    private let factoryPresetValues:[(cutoff: AUValue, resonance: AUValue)] = [
        (2500.0, 5.0),    // "Prominent"
        (14_000.0, 12.0), // "Bright"
        (384.0, -3.0)     // "Warm"
    ]

    var currentPreset: AUAudioUnitPreset? {
        didSet {
            guard let preset = currentPreset else { return }

            // Notify the observer of the selection change.
            let values = factoryPresetValues[preset.number]
            presetObserver.didSelectPreset(cutoff: values.cutoff,
                                           resonance: values.resonance)
        }
    }

    private unowned let presetObserver: AUv3FilterDemoPresetSelectionObserver

    init(presetObserver: AUv3FilterDemoPresetSelectionObserver) {
        currentPreset = factoryPresets.first!
        self.presetObserver = presetObserver
    }

    func activateDefault() {
        currentPreset = factoryPresets.first!
    }
}
