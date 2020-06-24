// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

import Foundation

public extension CALayer {

    convenience init(white: CGFloat, frame: CGRect) {
        self.init()
        backgroundColor = Color(white: white, alpha: 1.0).cgColor
        self.frame = frame
    }

    convenience init(color: Color, frame: CGRect) {
        self.init()
        backgroundColor = color.cgColor
        self.frame = frame
    }
}
