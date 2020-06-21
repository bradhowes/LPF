// Copyright © 2020 Brad Howes. All rights reserved.

import CoreAudioKit
import AUv3FilterFramework

extension FilterViewController: AUAudioUnitFactory {

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: [])
        return audioUnit!
    }
}
