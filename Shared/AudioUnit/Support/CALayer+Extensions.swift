import Foundation

public extension CALayer {

    convenience init(white: CGFloat) {
        self.init()
        backgroundColor = Color(white: white, alpha: 1.0).cgColor
    }

    convenience init(color: Color) {
        self.init()
        backgroundColor = color.cgColor
    }
}
