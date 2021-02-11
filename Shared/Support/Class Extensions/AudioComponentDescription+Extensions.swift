// Copyright © 2020 Apple. All rights reserved.

import Foundation
import os

extension AudioComponentDescription {

    func log(_ logger: OSLog, type: OSLogType) {
        os_log(type, log: logger,
               "AudioComponentDescription type: %{public}s, subtype: %{public}s, manufacturer: %{public}s flags: %x",
               componentType.stringValue,
               componentSubType.stringValue,
               componentManufacturer.stringValue,
               componentFlags)
    }
}
