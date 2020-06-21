// Copyright © 2020 Brad Howes. All rights reserved.

import AppKit

public extension NSTextField {
    var text: String? {
        get { self.stringValue }
        set { self.objectValue = newValue }
    }
}
