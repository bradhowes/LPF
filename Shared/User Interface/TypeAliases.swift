/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Type alias mapping to normalize AppKit and UIKit interfaces to support cross-platform code reuse.
*/

#if os(iOS)
import UIKit
public typealias Color = UIColor
public typealias Font = UIFont

public typealias Storyboard = UIStoryboard

public typealias View = UIView
public typealias ViewController = UIViewController
public typealias TextField = UITextField
public typealias Label = UILabel
public typealias Button = UIButton
public typealias Slider = UISlider

#elseif os(macOS)
import AppKit
public typealias Color = NSColor
public typealias Font = NSFont

public typealias Storyboard = NSStoryboard

public typealias View = NSView
public typealias ViewController = NSViewController
public typealias TextField = NSTextField
public typealias Label = NSTextField
public typealias Button = NSButton
public typealias Slider = NSSlider

public var tintColor: NSColor! = NSColor.controlAccentColor.usingColorSpace(.deviceRGB)

public extension NSView {

    func setNeedsLayout() {
        self.needsLayout = true
    }

    func setNeedsDisplay() {
        self.needsDisplay = true
    }
}

public extension NSTextField {

    /// Replicate attribute found on UITextField for convenience
    var text: String? {
        get { self.stringValue }
        set { self.objectValue = newValue }
    }
}

#endif
