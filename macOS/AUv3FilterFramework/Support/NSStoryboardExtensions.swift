/*
See LICENSE folder for this sample’s licensing information.

Abstract:
NSStoryboard extension to normalize interface for cross-platform usage.
*/

import AppKit

public extension NSStoryboard {

    func instantiateInitialViewController() -> Any? {
        return instantiateInitialController()
    }
}
