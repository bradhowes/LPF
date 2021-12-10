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
public typealias ViewController = UIViewController

#elseif os(macOS)

import AppKit
public typealias Color = NSColor
public typealias Storyboard = NSStoryboard
public typealias View = NSView
public typealias ViewController = NSViewController
public extension NSView {
  func setNeedsDisplay() { needsDisplay = true }
}

#endif
