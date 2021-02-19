/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Type alias mapping to normalize AppKit and UIKit interfaces to support cross-platform code reuse.
*/

#if os(iOS)

import UIKit
public typealias Color = UIColor
public typealias Storyboard = UIStoryboard
public typealias View = UIView

#elseif os(macOS)

import AppKit
public typealias Color = NSColor
public typealias Storyboard = NSStoryboard
public typealias View = NSView

public extension NSView {
    func setNeedsDisplay() { self.needsDisplay = true }
}

#endif
