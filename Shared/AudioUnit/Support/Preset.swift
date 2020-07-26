// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import AVFoundation

/**
 Wrapper around AUAudioUnitPreset that just exposes the preset's index and name.
 */
public struct Preset {

    /// The index of the preset
    public var number: Int { audioUnitPreset.number }
    /// The name of the preset
    public var name: String { audioUnitPreset.name }

    internal init(preset: AUAudioUnitPreset) {
        audioUnitPreset = preset
    }

    internal let audioUnitPreset: AUAudioUnitPreset
}

internal extension AUAudioUnitPreset {

    convenience init(number: Int, name: String) {
        self.init()
        self.number = number
        self.name = name
    }
}
