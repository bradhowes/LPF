/*
See LICENSE folder for this sample’s licensing information.

Abstract:
NSTextField extension to normalize interface for cross-platform usage.
*/

import AppKit

public extension NSTextField {

    var text: String? {
        get {
            return self.stringValue
        }
        set {
            self.objectValue = newValue
        }
    }
}
