// Copyright © 2020 Brad Howes. All rights reserved.

import CoreAudioKit

extension FilterViewController: AUAudioUnitFactory {
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: [])
        return audioUnit!
    }
}
