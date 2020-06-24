// Copyright © 2020 Apple. All rights reserved.

import Foundation

extension FourCharCode {

    var stringValue: String {
        String(bytes: [24, 16, 8, 0].map { UInt8(self >> $0 & 0x000000FF) }, encoding: .utf8) ?? "????"
    }
}
