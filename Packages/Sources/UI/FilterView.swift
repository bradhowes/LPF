// Changes: Copyright © 2021 Brad Howes. All rights reserved.

import AUv3Support

#if os(iOS)
import UIKit
#endif

#if os(macOS)
import AppKit
import CoreMIDI
#endif

import os.log

/**
 Configuration of the frequency range and the dB range to show in the view. These are based on the parameter ranges
 of the cutoff and resonance settings.
 */
public struct FilterViewRanges {
  public let frequencyRange: ClosedRange<Float>
  public lazy var frequencyScale = log2f(frequencyRange.upperBound / frequencyRange.lowerBound)
  public let gainRange: ClosedRange<Float>

  public init(frequencyRange: ClosedRange<Float>, gainRange: ClosedRange<Float>) {
    self.frequencyRange = frequencyRange
    self.gainRange = gainRange
  }
}

/**
 Delegation protocol for the FilterView. Reports out touch/mouse events and changes to the runtime
 parameters.
 */
@MainActor
public protocol FilterViewDelegate: AnyObject {

  /// Defines the coordinate spaces for the view in AUParameter units.
  var filterViewRanges: FilterViewRanges { get }

  /**
   Notification that a touch/mouse event has begun

   - parameter filterView: the source of the notification
   */
  func filterViewInteractionStarted(_ filterView: FilterView, cutoff: Float, resonance: Float)

  /**
   Notification that a touch/mouse event has finished

   - parameter filterView: the source of the notification
   */
  func filterViewInteractionEnded(_ filterView: FilterView, cutoff: Float, resonance: Float)

  /**
   Notification that the frequency and resonance settings have changed.

   - parameter filterView: the source of the notification
   - parameter cutoff: the new frequency value
   - parameter resonance: the new resonance value
   */
  func filterViewInteracted(_ filterView: FilterView, cutoff: Float, resonance: Float)

  /**
   Notification that the layout of the view changed. This should usually require a regeneration of the
   response curve from the filter.

   - parameter filterView: the source of the notification
   */
  func filterViewLayoutChanged(_ filterView: FilterView)
}

/**
 Custom view that displays a response curve for the low-pass filter and provides a control point for changing the
 filter cutoff and resonance values in real-time. Note that there is purely UI -- there is no direct manipulation of
 AUParameter values here.
 */
@objc
public final class FilterView: View {
  private lazy var log = Shared.logger("FilterView")

  /// Delegate to receive change notification
  public weak var delegate: FilterViewDelegate? {
    didSet {
      if let delegate = delegate {
        viewRanges = delegate.filterViewRanges
        if !axisElements.isEmpty {
          createAxisElements()
        }
      }
    }
  }

  /// Collection of frequencies to use when generating the response curve
  public var responseCurveFrequencies: [Float] {
    guard frequencies == nil else { return frequencies! }
    let width = graphLayer.bounds.width
    let count = min(maxNumberOfResponseFrequencies, Int(width))
    let scale = width / CGFloat(count)
    frequencies = (0..<count).map { locationToFrequency(CGFloat($0) * scale) }
    return frequencies!
  }

  /// The current location of the control in frequency (X) and dB (Y) axis.
  private var controlPoint: CGPoint = .zero { didSet { updateIndicator() } }
  /// The coordinate spaces to work in. This is updated when there is a delegate set.
  private var viewRanges: FilterViewRanges = .init(frequencyRange: 100...200.0, gainRange: 0...1)

  private lazy var cutoff: Float = viewRanges.frequencyRange.mid
  private lazy var resonance: Float = viewRanges.gainRange.mid

#if os(macOS)
  override public var isFlipped: Bool { return true }
#endif

  private let numVerticalTicks: Int = 7

  /// Width of the area to the left of the graph that shows dB labels
  private let yAxisWidth: CGFloat = 40.0
  /// Height of the area below the graph that shows Hz labels
  private let xAxisHeight: CGFloat = 20.0
  /// Max number of points in the response curve.
  private let maxNumberOfResponseFrequencies = 1024
  /// Cache of the frequencies used to generate the response curve
  private var frequencies: [Float]?
  /// Collection of CALayer labels and grid lines that are recreated when the view resizes
  private var axisElements = [CALayer]()

  private let controlRadius: CGFloat = 4.0

  /// Layer for all of the plot elements (graph + labels)
  private let plotLayer = CALayer()
  /// Layer for the graph elements
  private let graphLayer = CALayer()
  /// Layer for the grid in the graph
  private let gridLayer = CALayer()
  /// Layer that shows the response curve of the filter
  private let curveLayer: CAShapeLayer = .init()

  private var curveColor: Color { Color.systemOrange.withAlphaComponent(0.8) }
  private var gridColor: Color { Color.systemGreen.withAlphaComponent(0.5) }
  private var controlColor: Color { Color.systemYellow }
  private var tickLabelColor: Color { Color.systemGray }

  /// Layer that indicates the current filter setting
  private var indicatorLayer = CALayer()

  private var rootLayer: CALayer {
#if os(iOS)
    return layer
#elseif os(macOS)
    return layer!
#endif
  }

  private var screenScale: CGFloat {
#if os(iOS)
    return UIScreen.main.scale
#elseif os(macOS)
    return NSScreen.main?.backingScaleFactor ?? 1.0
#endif
  }

  override public func awakeFromNib() {
    MainActor.assumeIsolated {
      os_log(.debug, log: log, "awakeFromNib BEGIN")
      
#if os(macOS)
      self.wantsLayer = true
#endif
      
      super.awakeFromNib()
      
      rootLayer.masksToBounds = false
      rootLayer.contentsScale = screenScale
      
      plotLayer.name = "plot"
      plotLayer.anchorPoint = .zero
      plotLayer.bounds = CGRect(origin: .zero, size: rootLayer.bounds.size)
      plotLayer.contentsScale = screenScale
      rootLayer.addSublayer(plotLayer)
      
      graphLayer.name = "graph"
      graphLayer.backgroundColor = Color.black.cgColor
      graphLayer.position = CGPoint(x: yAxisWidth, y: 0.0)
      graphLayer.anchorPoint = .zero
      graphLayer.contentsScale = screenScale
      plotLayer.addSublayer(graphLayer)
      
      gridLayer.name = "grid"
      gridLayer.position = .zero
      gridLayer.anchorPoint = .zero
      graphLayer.addSublayer(gridLayer)
      
      curveLayer.name = "curve"
      curveLayer.anchorPoint = .zero
      curveLayer.position = .zero
      graphLayer.addSublayer(curveLayer)
      
      indicatorLayer.name = "indicator"
      indicatorLayer.position = .zero
      indicatorLayer.anchorPoint = .zero
      graphLayer.addSublayer(indicatorLayer)
      
      createIndicatorPoint()
      
#if os(macOS)
      layoutSublayers(of: rootLayer)
#endif
      
      os_log(.debug, log: log, "awakeFromNib END")
    }
  }

#if os(iOS)

  override public func layoutSublayers(of layer: CALayer) {
    os_log(.debug, log: log, "layoutSublayers BEGIN")
    super.layoutSublayers(of: layer)
    performLayout(of: layer)
    os_log(.debug, log: log, "layoutSublayers END")
  }

#elseif os(macOS)

  override public func setFrameSize(_ newSize: NSSize) {
    os_log(.debug, log: log, "setFrameSize BEGIN - w: %f h: %f", newSize.width, newSize.height)
    super.setFrameSize(newSize)
    layoutSublayers(of: rootLayer)
    os_log(.debug, log: log, "setFrameSize END")
  }

  func layoutSublayers(of layer: CALayer) {
    os_log(.debug, log: log, "layoutSublayers BEGIN")
    performLayout(of: layer)
    os_log(.debug, log: log, "layoutSublayers END")
  }

#endif
}

// MARK: - Response Curve

public extension FilterView {

  func setControlPoint(_ value: CGPoint) {
    os_log(.info, log: log, "setControlPoint BEGIN - x: %f y: %f", value.x, value.y)
    cutoff = locationToFrequency(value.x)
    resonance = locationToDb(value.y)
    controlPoint = value
    os_log(.info, log: log, "setControlPoint END")
  }

  func setControlPoint(cutoff: Float, resonance: Float) {
    os_log(.info, log: log, "setControlPoint BEGIN - cutoff: %f resonance: %f", cutoff, resonance)
    self.cutoff = cutoff
    self.resonance = resonance
    updateControlPoint()
    os_log(.info, log: log, "setControlPoint END")
  }

  /**
   Create a new response curve using the given magnitude values.

   - parameter magnitudes: the magnitudes from the filter for the frequencies in `frequencies`
   */
  func makeFilterResponseCurve(_ magnitudes: [Float]) {
    guard let frequencies = frequencies else { return }
    guard !magnitudes.isEmpty else { return }

    let width = graphLayer.bounds.width
    let scale = width / CGFloat(frequencies.count)
    let bezierPath = CGMutablePath()

    bezierPath.move(to: CGPoint(x: 0, y: graphLayer.bounds.height))
    for (index, magnitude) in magnitudes.enumerated() {
      bezierPath.addLine(to: CGPoint(x: CGFloat(index) * scale, y: dbToLocation(magnitude)))
    }

    bezierPath.addLine(to: CGPoint(x: CGFloat(frequencies.count - 1) * scale, y: graphLayer.bounds.height))
    bezierPath.closeSubpath()

    CATransaction.noAnimation {
      curveLayer.fillColor = curveColor.cgColor
      curveLayer.path = bezierPath
    }
    updateIndicator()
  }
}

// MARK: - Touch/Mouse Event Handling

public extension FilterView {
#if os(iOS)

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let pointOfTouch = touches.first?.location(in: self) else { return }
    let convertedPoint = rootLayer.convert(pointOfTouch, to: graphLayer)
    if graphLayer.contains(convertedPoint) {
      setControlPoint(convertedPoint)
      delegate?.filterViewInteractionStarted(self, cutoff: cutoff, resonance: resonance)
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let pointOfTouch = touches.first?.location(in: self) else { return }
    let convertedPoint = rootLayer.convert(pointOfTouch, to: graphLayer)
    if graphLayer.contains(convertedPoint) {
      setControlPoint(convertedPoint)
      delegate?.filterViewInteracted(self, cutoff: cutoff, resonance: resonance)
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    delegate?.filterViewInteractionEnded(self, cutoff: cutoff, resonance: resonance)
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}

#elseif os(macOS)

  override func mouseDown(with event: NSEvent) {
    let pointOfTouch = NSPointToCGPoint(convert(event.locationInWindow, from: nil))
    let convertedPoint = graphLayer.convert(pointOfTouch, from: rootLayer)
    if graphLayer.contains(convertedPoint) {
      setControlPoint(convertedPoint)
      delegate?.filterViewInteractionStarted(self, cutoff: cutoff, resonance: resonance)
    }
  }

  override func mouseDragged(with event: NSEvent) {
    let pointOfClick = NSPointToCGPoint(convert(event.locationInWindow, from: nil))
    let convertedPoint = rootLayer.convert(pointOfClick, to: graphLayer)
    if graphLayer.contains(convertedPoint) {
      setControlPoint(convertedPoint)
      delegate?.filterViewInteracted(self, cutoff: cutoff, resonance: resonance)
    }
  }

  override func mouseUp(with event: NSEvent) {
    delegate?.filterViewInteractionEnded(self, cutoff: cutoff, resonance: resonance)
  }

#endif
}

// MARK: - Unit Conversions

private extension FilterView {

  func updateControlPoint() {
    os_log(.info, log: log, "updateControlPoint BEGIN - cutoff: %f resonance: %f", cutoff, resonance)
    controlPoint = .init(x: frequencyToLocation(cutoff), y: dbToLocation(resonance))
    os_log(.info, log: log, "updateControlPoint - x: %f y: %f", controlPoint.x, controlPoint.y)
    os_log(.info, log: log, "updateControlPoint END")
  }

  /**
   Obtain the frequency for an X position on the graph

   - parameter location: the X position to work with
   - returns: the frequency value
   */
  func locationToFrequency(_ location: CGFloat) -> Float {
    viewRanges.frequencyRange.lowerBound * pow(2, Float(location / graphLayer.bounds.width) *
                                               viewRanges.frequencyScale)
  }

  /**
   Obtain the X position on the graph for a frequency

   - parameter frequency: the frequency value to work with
   - returns: the X position
   */
  func frequencyToLocation(_ frequency: Float) -> CGFloat {
    CGFloat(log2(frequency / viewRanges.frequencyRange.lowerBound) * Float(graphLayer.bounds.width) /
            viewRanges.frequencyScale)
  }

  /**
   Obtain the dB value for a Y position on the graph

   - parameter location: the Y position to work with
   - returns: the dB value
   */
  func locationToDb(_ location: CGFloat) -> Float {
    Float(graphLayer.bounds.height - location) * viewRanges.gainRange.distance / Float(graphLayer.bounds.height) +
    viewRanges.gainRange.lowerBound
  }

  /**
   Obtain the Y position on the graph for a dB value

   - parameter frequency: the dB value to work with
   - returns: the Y position
   */
  func dbToLocation(_ value: Float) -> CGFloat {
    CGFloat(viewRanges.gainRange.upperBound - value.clamped(to: viewRanges.gainRange)) * graphLayer.bounds.height /
    CGFloat(viewRanges.gainRange.distance)
  }
}

// MARK: - Axis Management

private extension FilterView {

  func dbLabel(_ value: Float) -> String { "\(Int(round(value)))dB" }

  func makeLabelLayer(_ content: String, frame: CGRect, alignment: CATextLayerAlignmentMode) -> CATextLayer {
    let labelLayer = CATextLayer()
    let fontSize = CGFloat(11)
    let font = CTFontCreateUIFontForLanguage(.label, fontSize, nil)
    labelLayer.font = font
    labelLayer.fontSize = fontSize
    labelLayer.contentsScale = screenScale
    labelLayer.foregroundColor = tickLabelColor.cgColor
    labelLayer.alignmentMode = alignment
    labelLayer.anchorPoint = .zero
    labelLayer.string = content
    labelLayer.frame = frame
    return labelLayer
  }

  func createAxisElements() {
    axisElements.forEach { $0.removeFromSuperlayer() }
    axisElements.removeAll()
    createHorizontalAxisElements()
    createVerticalAxisElements()
  }

  func createVerticalAxisElements() {
    let numTicks = numVerticalTicks
    let spacing = gridLayer.bounds.height / CGFloat(numTicks - 1)
    let width = gridLayer.bounds.width

    for index in 0..<numTicks {
      // First and last labels have special offsets to align with the top/bottom of the graph
      let offset = CGFloat(index == 0 ? 0 : (index == (numTicks - 1) ? -10 : -6))
      let pos = CGFloat(index) * spacing
      let label = makeLabelLayer(dbLabel(locationToDb(pos)),
                                 frame: CGRect(x: 0, y: pos + offset, width: yAxisWidth - 4, height: 16.0),
                                 alignment: .right)
      axisElements.append(label)
      plotLayer.addSublayer(label)

      // Create a grid line if not at the graph edge
      if index > 0, index < numTicks - 1 {
        let line = CALayer(color: gridColor, frame: CGRect(x: 0, y: pos, width: width, height: 1.0))
        axisElements.append(line)
        gridLayer.addSublayer(line)
      }
    }
  }

  var numHorizontalTicks: Int {
    let width = gridLayer.bounds.width
    var numTicks = Int(floor(width / 60.0))
    if numTicks > Int(viewRanges.gainRange.distance / 2.0) {
      numTicks = Int(viewRanges.gainRange.distance / 2.0)
    }
    if numTicks < 3 {
      numTicks = 3
    }
    return numTicks
  }

  func frequencyLabel(_ value: Float) -> String {
    "\(Int(round(value >= 1000 ? value / 1000 : value)))"
    + (value == viewRanges.frequencyRange.lowerBound ? "Hz" : (value >= 1000 ? "k" : ""))
  }

  func createHorizontalAxisElements() {
    let numTicks = numHorizontalTicks
    let spacing = gridLayer.bounds.width / CGFloat(numTicks - 1)
    let height = gridLayer.bounds.height

    for index in 0..<numTicks {
      // First and last labels have special offsets to align with the left/right of the graph
      let offset = CGFloat(index == 0 ? 32 : (index == (numTicks - 1) ? 10 : 20))
      let pos = CGFloat(index) * spacing
      let labelLayer = makeLabelLayer(frequencyLabel(locationToFrequency(pos)),
                                      frame: CGRect(x: pos + offset, y: height + 4.0, width: 40, height: 16.0),
                                      alignment: .center)
      axisElements.append(labelLayer)
      plotLayer.addSublayer(labelLayer)

      // Create a grid line if not at the graph edge
      if index > 0, index < numTicks - 1 {
        let line = CALayer(color: gridColor, frame: CGRect(x: pos, y: 0, width: 1.0, height: height))
        axisElements.append(line)
        gridLayer.addSublayer(line)
      }
    }
  }
}

// MARK: - Filter Setting Indicator

private extension FilterView {
  enum LayerKind: String {
    case verticalLine
    case horizontalLine
    case position
    case verticalDot
    case horizontalDot
    case cutoffLabel
    case resonanceLabel
  }

  func makeValueLayer(_ alignment: CATextLayerAlignmentMode) -> CATextLayer {
    let labelLayer = CATextLayer()
    let fontSize = CGFloat(15)
    let font = CTFontCreateUIFontForLanguage(.label, fontSize, nil)
    labelLayer.font = font
    labelLayer.fontSize = fontSize
    labelLayer.contentsScale = screenScale
    labelLayer.foregroundColor = Color.white.cgColor
    labelLayer.alignmentMode = alignment
    labelLayer.anchorPoint = .zero
    labelLayer.string = ""
    labelLayer.frame = frame
    return labelLayer
  }

  func createIndicatorPoint() {
    indicatorLayer.sublayers?.removeAll()

    let width = graphLayer.bounds.width
    let height = graphLayer.bounds.height

    let vline = CALayer(color: controlColor, frame: CGRect(x: controlPoint.x, y: 0.0, width: 1.0, height: height))
    vline.layerKind = .verticalLine
    indicatorLayer.addSublayer(vline)

    let hline = CALayer(color: controlColor, frame: CGRect(x: 0, y: controlPoint.y, width: width, height: 1.0))
    hline.layerKind = .horizontalLine
    indicatorLayer.addSublayer(hline)

    let pos = CALayer(color: controlColor, frame: .zero)
    pos.cornerRadius = controlRadius
    pos.layerKind = .position
    indicatorLayer.addSublayer(pos)

    let vdot = CALayer(color: controlColor, frame: .zero)
    vdot.cornerRadius = controlRadius
    vdot.layerKind = .verticalDot
    indicatorLayer.addSublayer(vdot)

    let hdot = CALayer(color: controlColor, frame: .zero)
    hdot.cornerRadius = controlRadius
    hdot.layerKind = .horizontalDot
    indicatorLayer.addSublayer(hdot)

    let cutoffLabel = makeValueLayer(.center)
    cutoffLabel.layerKind = .cutoffLabel
    indicatorLayer.addSublayer(cutoffLabel)

    let resonanceLabel = makeValueLayer(.left)
    resonanceLabel.layerKind = .resonanceLabel
    indicatorLayer.addSublayer(resonanceLabel)
  }

  func frequencyValue(_ value: Float) -> String {
    String(format: "%.02f ", value >= 1000 ? value / 1000 : value) + (value >= 1000 ? "kHz" : "Hz")
  }

  func dbValue(_ value: Float) -> String {
    String(format: "%.02f dB", value)
  }

  func updateIndicator() {
    guard let layers = indicatorLayer.sublayers else { return }
    let height = graphLayer.bounds.height
    let halfWidth = graphLayer.bounds.width / 2
    let diameter = 2 * controlRadius
    let pos = controlPoint

    CATransaction.noAnimation {
      for layer in layers {
        switch layer.layerKind {
        case .position:
          layer.frame = CGRect(x: pos.x - controlRadius, y: pos.y - controlRadius, width: diameter, height: diameter)
        case .horizontalDot:
          layer.frame = CGRect(x: pos.x - controlRadius, y: height - controlRadius, width: diameter, height: diameter)
        case .verticalDot:
          layer.frame = CGRect(x: -3, y: pos.y - controlRadius, width: diameter, height: diameter)
        case .horizontalLine:
          layer.frame = CGRect(x: 0, y: pos.y, width: pos.x, height: 1.0)
        case .verticalLine:
          layer.frame = CGRect(x: pos.x, y: pos.y, width: 1.0, height: height - pos.y)

        case .cutoffLabel:
          guard let label = layer as? CATextLayer else { fatalError() }
          label.string = self.frequencyValue(cutoff)
            if pos.x < halfWidth {
              label.alignmentMode = .left
              layer.frame = CGRect(x: pos.x + 10, y: height - 20.0, width: 100.0, height: 30.0)
            } else {
              label.alignmentMode = .right
              layer.frame = CGRect(x: pos.x - 110, y: height - 20.0, width: 100.0, height: 30.0)
            }

        case .resonanceLabel:
          guard let label = layer as? CATextLayer else { fatalError() }
          label.string = self.dbValue(resonance)
          if resonance < 30 {
            layer.frame = CGRect(x: 10, y: pos.y - 20.0, width: 100.0, height: 30.0)
          } else {
            layer.frame = CGRect(x: 10, y: pos.y + 4, width: 100.0, height: 30.0)
          }
        }
      }
    }
  }
}

private extension FilterView {

  func performLayout(of layer: CALayer) {
    guard layer === rootLayer else { return }
    os_log(.info, log: log, "performLayout BEGIN")
    CATransaction.noAnimation {
      plotLayer.bounds = rootLayer.bounds
      graphLayer.bounds = CGRect(x: 0, y: 0, width: layer.bounds.width - yAxisWidth,
                                 height: layer.bounds.height - xAxisHeight - 10.0)
      gridLayer.bounds = graphLayer.bounds
      indicatorLayer.bounds = graphLayer.bounds
      curveLayer.bounds = graphLayer.bounds
      createAxisElements()
    }

    updateIndicator()
    frequencies = nil

    DispatchQueue.main.async {
      self.delegate?.filterViewLayoutChanged(self)
    }

    os_log(.info, log: log, "performLayout END")
  }
}

fileprivate extension CALayer {

  var layerKind: FilterView.LayerKind {
    get {
      FilterView.LayerKind(rawValue: name!)!
    }
    set {
      name = newValue.rawValue
    }
  }
}
