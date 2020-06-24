// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

/**
 Delegation protocol for the FilterView. Reports out touch/mouse events and changes to the runtime
 parameters.
 */
public protocol FilterViewDelegate: class {

    /**
     Notification that a touch/mouse event has begun

     - parameter filterView: the source of the notification
     */
    func filterViewTouchBegan(_ filterView: FilterView)

    /**
     Notification that a touch/mouse event has finished

     - parameter filterView: the source of the notification
     */
    func filterViewTouchEnded(_ filterView: FilterView)

    /**
     Notification that the resonance setting has changed.

     - parameter filterView: the source of the notification
     - parameter resonance: the new value
     */
    func filterView(_ filterView: FilterView, didChangeResonance resonance: Float)

    /**
     Notification that the frequency setting has changed.

     - parameter filterView: the source of the notification
     - parameter frequency: the new value
     */
    func filterView(_ filterView: FilterView, didChangeFrequency frequency: Float)

    /**
     Notification that the frequency and resonance settings have changed.

     - parameter filterView: the source of the notification
     - parameter frequency: the new frequency value
     - parameter resonance: the new resonance value
     */
    func filterView(_ filterView: FilterView, didChangeFrequency frequency: Float, andResonance resonance: Float)
    func filterViewDataDidChange(_ filterView: FilterView)
}

/**
 Custom view that displays a response curve for the low-pass filter. Provides a control for changing the filter
 cutoff and resonance values in real-time.
 */
public final class FilterView: View {

    public static let hertzMin = Float(12.0)
    public static let hertzMax = Float(20_000.0)
    public static let hertzRange = hertzMin...hertzMax
    public static let hertzSpan = hertzMax - hertzMin
    public static let hertzScale = log2f(hertzMax / hertzMin)

    public static let gainMin = Float(-20)
    public static let gainMax = Float(20)
    public static let gainRange = gainMin...gainMax
    public static let gainSpan = gainMax - gainMin

    /// Delegate to receive change notification
    public weak var delegate: FilterViewDelegate?

    /// Collection of frequencies to use when generating the response curve
    public var responseCurveFrequencies: [Float] {
        guard frequencies == nil else { return frequencies! }
        let width = graphLayer.bounds.width
        let count = min(maxNumberOfResponseFrequencies, Int(width))
        let scale = width / CGFloat(count)
        frequencies = (0..<count).map { locationToFrequency(CGFloat($0) * scale) }
        return frequencies!
    }

    /// Current filter cutoff frequency setting
    public var frequency: Float = hertzMin {
        didSet {
            frequency = frequency.clamp(to: Self.hertzRange)
            controlPoint.x = floor(frequencyToLocation(frequency))
        }
    }

    /// Current filter resonance setting
    public var resonance: Float = 0.0 {
        didSet {
            resonance = resonance.clamp(to: Self.gainRange)
            controlPoint.y = floor(dbToLocation(resonance))
        }
    }

    #if os(macOS)
    override public var isFlipped: Bool { return true }
    #endif

    /// Width of the area to the left of the graph that shows dB labels
    private let yAxisWidth: CGFloat = 40.0
    /// Height of the area below the graph that shows Hz labels
    private let xAxisHeight: CGFloat = 20.0
    /// Max number of points in the response curve
    private let maxNumberOfResponseFrequencies = 1024
    /// Cache of the frequencies used to generate the response curve
    private var frequencies: [Float]?
    /// Collection of CALayer labels and grid lines that are recreated when the view resizes
    private var axisElements = [CALayer]()

    /// Layer for all of the plot elements (graph + labels)
    private var plotLayer = CALayer()
    /// Layer for the graph elements
    private var graphLayer = CALayer()
    /// Layer for the grid in the graph
    private var gridLayer = CALayer()
    /// Layer that shows the response curve of the filter
    private var curveLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        let fillColor = Color(red: 0.067, green: 0.535, blue: 0.842, alpha: 1.000)
        shapeLayer.fillColor = fillColor.cgColor
        return shapeLayer
    }()

    /// Layer that indicates the current filter setting
    private var indicatorLayer = CALayer()

    private var controlPoint = CGPoint.zero
    private var touchIsActive = false

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

    private var axisLabelColor: Color {
        #if os(iOS)
        return Color.label
        #elseif os(macOS)
        return Color.labelColor
        #endif
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        rootLayer.masksToBounds = false
        rootLayer.contentsScale = screenScale

        plotLayer.name = "plot"
        plotLayer.anchorPoint = .zero
        plotLayer.bounds = CGRect(origin: .zero, size: rootLayer.bounds.size)
        plotLayer.contentsScale = screenScale
        rootLayer.addSublayer(plotLayer)

        graphLayer.name = "graph"
        graphLayer.backgroundColor = Color(white: 0.88, alpha: 1.0).cgColor
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
    }

    #if os(macOS)
    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutSublayers(of: rootLayer)
    }
    #endif

    #if os(iOS)
    override public func layoutSublayers(of layer: CALayer) {
        performLayout(of: layer)
    }
    #elseif os(macOS)
    func layoutSublayers(of layer: CALayer) {
        performLayout(of: layer)
    }
    #endif
}

// MARK: - Response Curve
extension FilterView {

    /**
     Convert "bad" values (NaNs, very small, and very large values to 1.0 (!)

     - parameter x: value to check
     - returns: filtered value or 1.0
     */
    private func filterBadValues(_ x: Float) -> Float {
        if !x.isNaN {
            let absx = abs(x)
            if absx >= 1e-15 && absx <= 1e15 {
                return x
            }
        }
        return 1.0
    }

    /**
     Create a new response curve using the given magnitude values.

     - parameter magnitudes: the magnitudes from the filter for the frequencies in `frequencies`
     */
    public func makeFilterResponseCurve(_ magnitudes: [Float]) {
        guard let frequencies = self.frequencies else { return }
        guard magnitudes.count > 0 else { return }

        let width = graphLayer.bounds.width
        let scale = width / CGFloat(frequencies.count)
        let bezierPath = CGMutablePath()

        bezierPath.move(to: CGPoint(x: 0, y: graphLayer.bounds.height))
        for (index, magnitude) in magnitudes.map({ filterBadValues($0) }).enumerated() {
            bezierPath.addLine(to: CGPoint(x: CGFloat(index) * scale,y: dbToLocation(20.0 * log10(magnitude))))
        }

        bezierPath.addLine(to: CGPoint(x: CGFloat(frequencies.count - 1) * scale, y: graphLayer.bounds.height))
        bezierPath.closeSubpath()

        CATransaction.noAnimation { curveLayer.path = bezierPath }
        updateIndicator()
    }
}

// MARK: - Touch/Mouse Event Handling
extension FilterView {

    #if os(iOS)

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pointOfTouch = touches.first?.location(in: self) else { return }
        let convertedPoint = rootLayer.convert(pointOfTouch, to: graphLayer)
        if graphLayer.contains(convertedPoint) {
            touchIsActive = true
            controlPoint = convertedPoint
            updateIndicator()
            delegate?.filterViewTouchBegan(self)
            updateFrequenciesAndResonance()
        }
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pointOfTouch = touches.first?.location(in: self) else { return }
        let convertedPoint = rootLayer.convert(pointOfTouch, to: graphLayer)
        if graphLayer.contains(convertedPoint) {
            handleDrag(convertedPoint)
            updateFrequenciesAndResonance()
        }
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchIsActive = false
        updateIndicator()
        delegate?.filterViewTouchEnded(self)
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchIsActive = false }

    #elseif os(macOS)

    override public func mouseDown(with event: NSEvent) {
        let pointOfTouch = NSPointToCGPoint(convert(event.locationInWindow, from: nil))
        let convertedPoint = graphLayer.convert(pointOfTouch, from: rootLayer)
        if graphLayer.contains(convertedPoint) {
            touchIsActive = true
            controlPoint = convertedPoint
            updateIndicator()
            delegate?.filterViewTouchBegan(self)
            updateFrequenciesAndResonance()
        }
    }

    override public func mouseDragged(with event: NSEvent) {
        let pointOfClick = NSPointToCGPoint(convert(event.locationInWindow, from: nil))
        let convertedPoint = rootLayer.convert(pointOfClick, to: graphLayer)
        if graphLayer.contains(convertedPoint) {
            handleDrag(convertedPoint)
            updateFrequenciesAndResonance()
        }
    }

    override public func mouseUp(with event: NSEvent) {
        touchIsActive = false
        updateIndicator()
        delegate?.filterViewTouchEnded(self)
    }

    #endif
}

// MARK: - Unit Conversions
extension FilterView {

    /**
     Obtain the frequency for an X position on the graph

     - parameter location: the X position to work with
     - returns: the frequency value
     */
    private func locationToFrequency(_ location: CGFloat) -> Float {
        Self.hertzMin * pow(2, Float((location) / graphLayer.bounds.width) * Self.hertzScale)
    }

    /**
     Obtain the X position on the graph for a frequency

     - parameter frequency: the frequency value to work with
     - returns: the X position
     */
    private func frequencyToLocation(_ frequency: Float) -> CGFloat {
        CGFloat(log2(frequency / Self.hertzMin) * Float(graphLayer.bounds.width) / Self.hertzScale)
    }

    /**
     Obtain the dB value for a Y position on the graph

     - parameter location: the Y position to work with
     - returns: the dB value
     */
    private func locationToDb(_ location: CGFloat) -> Float {
        Float(graphLayer.bounds.height - location) * Self.gainSpan / Float(graphLayer.bounds.height) + Self.gainMin
    }

    /**
     Obtain the Y position on the graph for a dB value

     - parameter frequency: the dB value to work with
     - returns: the Y position
     */
    private func dbToLocation(_ value: Float) -> CGFloat {
        CGFloat(Self.gainMax - value.clamp(to: Self.gainRange)) * graphLayer.bounds.height / CGFloat(Self.gainSpan)
    }
}

// MARK: - Axis Management
extension FilterView {

    private func frequencyString(_ value: Float) -> String {
        let value = floor((value >= 1000 ? value / 1000 : value) * 100.0) / 100.0
        return String(format: floor(value) == value ? "%.0f" : "%.1f", value)
    }

    private func makeLabelLayer(_ content: String, frame: CGRect, alignment: CATextLayerAlignmentMode) -> CATextLayer {
        let labelLayer = CATextLayer()
        let fontSize = CGFloat(11)
        let font = CTFontCreateUIFontForLanguage(.label, fontSize, nil)
        labelLayer.font = font
        labelLayer.fontSize = fontSize
        labelLayer.contentsScale = screenScale
        labelLayer.foregroundColor = axisLabelColor.cgColor
        labelLayer.alignmentMode = alignment
        labelLayer.anchorPoint = .zero
        labelLayer.string = content
        labelLayer.frame = frame
        return labelLayer
    }

    private func createAxisElements() {
        axisElements.forEach { $0.removeFromSuperlayer() }
        axisElements.removeAll()
        createHorizontalAxisElements()
        createVerticalAxisElements()
    }

    private func createVerticalAxisElements() {

        // Support small heights by reducing the number of ticks being shown
        var numTicks = 9
        let height = gridLayer.bounds.height
        while height / CGFloat(numTicks) < 40.0 && numTicks > 3 {
            numTicks -= 2
        }

        let spacing = height / CGFloat(numTicks - 1)
        let width = gridLayer.bounds.width

        for index in 0..<numTicks {
            let pos = CGFloat(index) * spacing
            let dbValue = locationToDb(pos)

            // First and last albels have special offsets to align with the top/bottom of the graph
            let offset = CGFloat(index == 0 ? 0 : (index == (numTicks - 1) ? -10 : -6))
            let label = makeLabelLayer(String(format: floor(dbValue) == dbValue ? "%.0f" : "%.1f", dbValue) + "dB",
                                       frame: CGRect(x: 0, y: pos + offset, width: yAxisWidth - 4, height: 16.0),
                                       alignment: .right)
            axisElements.append(label)
            plotLayer.addSublayer(label)

            // Create a grid line if not at the graph edge
            if index > 0 && index < numTicks - 1 {
                let line = CALayer(white: 0.8, frame: CGRect(x: 0, y: pos, width: width, height: 1.0))
                axisElements.append(line)
                gridLayer.addSublayer(line)
            }
        }
    }

    private func createHorizontalAxisElements() {

        // Support narrow widths by reducing the number of ticks being shown
        var numTicks = 12
        let width = graphLayer.bounds.width
        while width / CGFloat(numTicks) < 40.0 && numTicks > 3 {
            numTicks -= 1
        }

        let spacing = width / CGFloat(numTicks - 1)
        let height = gridLayer.bounds.height

        for index in 0..<numTicks {
            let pos = CGFloat(index) * spacing
            let freqValue = locationToFrequency(pos)
            let text = frequencyString(freqValue) + (index == 0 ? "Hz" : (freqValue >= 1000 ? "k" : ""))

            // First and last labels have special offsets to align with the left/right of the graph
            let offset = CGFloat(index == 0 ? 32 : (index == (numTicks - 1) ? 10 : 20))
            let labelLayer = makeLabelLayer(text,
                                            frame: CGRect(x: pos + offset, y: height + 4.0, width: 40, height: 16.0),
                                            alignment: .center)

            axisElements.append(labelLayer)
            plotLayer.addSublayer(labelLayer)

            // Create a grid line if not at the graph edge
            if index > 0 && index < numTicks - 1 {
                let line = CALayer(white: 0.8, frame: CGRect(x: pos, y: 0, width: 1.0, height: height))
                axisElements.append(line)
                gridLayer.addSublayer(line)
            }
        }
    }
}

// MARK: - Filter Setting Indicator
extension FilterView {

    private func createIndicatorPoint() {
        guard let color = touchIsActive ? tintColor : Color.darkGray else {
            fatalError("Unable to get color value.")
        }

        let width = graphLayer.bounds.width
        let height = graphLayer.bounds.height

        let vline = CALayer(color: color, frame: CGRect(x: controlPoint.x, y: 0.0, width: 1.0,  height: height))
        vline.name = "v"
        indicatorLayer.addSublayer(vline)

        let hline = CALayer(color: color, frame: CGRect(x: 0, y: controlPoint.y, width: width, height: 1.0))
        hline.name = "h"
        indicatorLayer.addSublayer(hline)

        let circle = CALayer(color: color, frame: .zero)
        circle.borderWidth = 2.0
        circle.cornerRadius = 3.0
        circle.name = "pos"
        indicatorLayer.addSublayer(circle)
    }

    private func updateIndicator() {
        guard let layers = indicatorLayer.sublayers else { return }
        let width = graphLayer.bounds.width
        let height = graphLayer.bounds.height
        CATransaction.noAnimation {
            layers.forEach {
                $0.frame = {
                    switch $0.name! {
                    case "pos": return CGRect(x: controlPoint.x - 3, y: controlPoint.y - 3, width: 7, height: 7)
                    case "h": return CGRect(x: 0, y: controlPoint.y, width: width, height: 1.0)
                    case "v": return CGRect(x: controlPoint.x, y: 0.0, width: 1.0,  height: height)
                    default: return .zero
                    }
                }($0)
            }
        }
    }
}

extension FilterView {
    private func performLayout(of layer: CALayer) {

        // Resize layers and remake the response curve
        guard layer === rootLayer else { return }
        CATransaction.noAnimation {
            plotLayer.bounds = rootLayer.bounds
            graphLayer.bounds = CGRect(x: 0, y: 0, width: layer.bounds.width - yAxisWidth,
                                           height: layer.bounds.height - xAxisHeight - 10.0)
            gridLayer.bounds = graphLayer.bounds
            indicatorLayer.bounds = graphLayer.bounds

            createAxisElements()

            controlPoint = CGPoint(x: frequencyToLocation(frequency), y: dbToLocation(resonance))
            curveLayer.bounds = graphLayer.bounds
        }

        updateIndicator()
        frequencies = nil

        delegate?.filterViewDataDidChange(self)
    }

    private func updateFrequenciesAndResonance() {
        let pickedFrequency = locationToFrequency(controlPoint.x)
        let pickedResonance = locationToDb(controlPoint.y)

        if pickedFrequency != frequency && pickedResonance != resonance {
            frequency = pickedFrequency
            resonance = pickedResonance
            delegate?.filterView(self, didChangeFrequency: frequency, andResonance: resonance)
        }
        else if pickedFrequency != frequency {
            frequency = pickedFrequency
            delegate?.filterView(self, didChangeFrequency: frequency)
        }
        else if pickedResonance != resonance {
            resonance = pickedResonance
            delegate?.filterView(self, didChangeResonance: resonance)
        }
    }

    private func handleDrag(_ dragPoint: CGPoint) {
        controlPoint.x = dragPoint.x.clamp(to: 0...graphLayer.bounds.width)
        controlPoint.y = dragPoint.y.clamp(to: 0...graphLayer.bounds.height)
    }
}
