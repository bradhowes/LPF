// Copyright © 2020 Brad Howes. All rights reserved.

import AppKit

public extension NSTextField {

    /// Replicate attribute found on UITextField for convenience
    var text: String? {
        get { self.stringValue }
        set { self.objectValue = newValue }
    }
}
