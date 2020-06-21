// Copyright © 2020 Brad Howes. All rights reserved.

import CoreAudioKit
import AUv3FilterFramework

extension AUv3FilterDemoViewController: AUAudioUnitFactory {

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try AUv3FilterDemo(componentDescription: componentDescription, options: [])
        return audioUnit!
    }
}
