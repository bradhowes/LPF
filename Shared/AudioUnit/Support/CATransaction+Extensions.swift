// Copyright © 2020 Brad Howes. All rights reserved.

public extension CATransaction {

    class func noAnimation(_ completion: () -> Void) {
        defer { CATransaction.commit() }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        completion()
    }
}
