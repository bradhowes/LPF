// Copyright © 2020 Brad Howes. All rights reserved.

import AppKit

public extension NSStoryboard {

    func instantiateInitialViewController() -> Any? {
        return instantiateInitialController()
    }
}
