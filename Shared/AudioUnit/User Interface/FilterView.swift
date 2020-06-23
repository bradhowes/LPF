// Copyright © 2020 Brad Howes. All rights reserved.

protocol FilterViewDelegate: class {
    func filterViewTouchBegan(_ filterView: FilterView)
    func filterView(_ filterView: FilterView, didChangeResonance resonance: Float)
    func filterView(_ filterView: FilterView, didChangeFrequency frequency: Float)
    func filterView(_ filterView: FilterView, didChangeFrequency frequency: Float, andResonance resonance: Float)
    func filterViewTouchEnded(_ filterView: FilterView)
    func filterViewDataDidChange(_ filterView: FilterView)
}

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

    private let yAxisWidth: CGFloat = 40.0
    private let xAxisHeight: CGFloat = 20.0

    private let maxNumberOfResponseFrequencies = 1024
    private var frequencies: [Float]?

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

    weak var delegate: FilterViewDelegate?

    var editPoint = CGPoint.zero
    var touchDown = false

    var rootLayer: CALayer {
        #if os(iOS)
        return layer
        #elseif os(macOS)
        return layer!
        #endif
    }

    var screenScale: CGFloat {
        #if os(iOS)
        return UIScreen.main.scale
        #elseif os(macOS)
        return NSScreen.main?.backingScaleFactor ?? 1.0
        #endif
    }

    var frequency: Float = hertzMin {
        didSet {
            frequency = frequency.clamp(to: Self.hertzRange)
            editPoint.x = floor(locationForFrequencyValue(frequency))
        }
    }

    var resonance: Float = 0.0 {
        didSet {
            resonance = resonance.clamp(to: Self.gainRange)
            editPoint.y = floor(locationForDBValue(resonance))
        }
    }

    #if os(macOS)
    override public var isFlipped: Bool { return true }
    #endif

    private var graphLabelColor: Color {
        #if os(iOS)
        return Color(white: 0.1, alpha: 1.0)
        #elseif os(macOS)
        return Color.labelColor // Use Appearance-aware label color
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

    func valueAtFreqIndex(_ index: Float) -> Float { Self.hertzMin * powf(2.0, index) }

    func frequencyDataForDrawing() -> [Float] {
        guard frequencies == nil else { return frequencies! }
        let width = graphLayer.bounds.width
        let count = min(maxNumberOfResponseFrequencies, Int(width))
        let scale = width / CGFloat(count)
        frequencies = (0..<count).map { frequencyValueForLocation(CGFloat($0) * scale) }
        return frequencies!
    }

    func setMagnitudes(_ magnitudes: [Float]) {
        guard let frequencies = self.frequencies else { return }

        let width = graphLayer.bounds.width
        let scale = width / CGFloat(frequencies.count)
        let bezierPath = CGMutablePath()

        bezierPath.move(to: CGPoint(x: 0, y: graphLayer.bounds.height))
        for (index, magnitude) in magnitudes.enumerated() {
            let dbValue = 20.0 * log10(magnitude)
            bezierPath.addLine(to: CGPoint(x: CGFloat(index) * scale, y: locationForDBValue(dbValue)))
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
        guard var pointOfTouch = touches.first?.location(in: self) else { return }
        pointOfTouch = CGPoint(x: pointOfTouch.x, y: pointOfTouch.y)
        if graphLayer.contains(pointOfTouch) {
            touchDown = true
            editPoint = pointOfTouch
            updateFrequenciesAndResonance()
            delegate?.filterViewTouchBegan(self)
        }
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var pointOfTouch = touches.first?.location(in: self) else { return }
        pointOfTouch = CGPoint(x: pointOfTouch.x, y: pointOfTouch.y)
        if graphLayer.contains(pointOfTouch) {
            handleDrag(pointOfTouch)
            updateFrequenciesAndResonance()
        }
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var pointOfTouch = touches.first?.location(in: self) else { return }
        pointOfTouch = CGPoint(x: pointOfTouch.x, y: pointOfTouch.y)
        if graphLayer.contains(pointOfTouch) { handleDrag(pointOfTouch) }
        touchDown = false
        updateFrequenciesAndResonance()
        delegate?.filterViewTouchEnded(self)
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchDown = false }

    #elseif os(macOS)

    override public func mouseDown(with event: NSEvent) {
        let pointOfTouch = NSPointToCGPoint(convert(event.locationInWindow, from: nil))
        let convertedPoint = graphLayer.convert(pointOfTouch, from: rootLayer)
        if graphLayer.contains(convertedPoint) {
            touchDown = true
            editPoint = convertedPoint
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
        touchDown = false
        updateIndicator()
        delegate?.filterViewTouchEnded(self)
    }

    #endif
}

// MARK: - Unit Conversions
extension FilterView {

    private func frequencyValueForLocation(_ location: CGFloat) -> Float {
        Self.hertzMin * pow(2, Float((location) / graphLayer.bounds.width) * Self.hertzScale)
    }

    private func locationForFrequencyValue(_ value: Float) -> CGFloat {
        CGFloat(log2(value / Self.hertzMin) * Float(graphLayer.bounds.width) / Self.hertzScale)
    }

    private func dbValueForLocation(_ location: CGFloat) -> Float {
        Float(graphLayer.bounds.height - location) * Self.gainSpan / Float(graphLayer.bounds.height) + Self.gainMin
    }

    private func locationForDBValue(_ value: Float) -> CGFloat {
        CGFloat(Self.gainMax - value.clamp(to: Self.gainRange)) * graphLayer.bounds.height / CGFloat(Self.gainSpan)
    }
}

// MARK: - Axis Management
extension FilterView {

    private func stringForValue(_ value: Float) -> String {
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
        labelLayer.foregroundColor = graphLabelColor.cgColor
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
        var numTicks = 9
        let height = gridLayer.bounds.height
        while height / CGFloat(numTicks) < 40.0 && numTicks > 3 {
            numTicks -= 2
        }

        let spacing = height / CGFloat(numTicks - 1)
        let width = gridLayer.bounds.width

        for index in 0..<numTicks {
            let pos = CGFloat(index) * spacing
            let dbValue = dbValueForLocation(pos)
            let offset = CGFloat(index == 0 ? 0 : (index == (numTicks - 1) ? -10 : -6))
            let label = makeLabelLayer(String(format: floor(dbValue) == dbValue ? "%.0f" : "%.1f", dbValue) + "dB",
                                       frame: CGRect(x: 0, y: pos + offset, width: yAxisWidth - 4, height: 16.0),
                                       alignment: .right)
            axisElements.append(label)
            plotLayer.addSublayer(label)

            if index > 0 && index < numTicks - 1 {
                let line = CALayer(white: 0.8)
                line.frame = CGRect(x: 0, y: pos, width: width, height: 1.0)
                axisElements.append(line)
                gridLayer.addSublayer(line)
            }
        }
    }

    private func createHorizontalAxisElements() {
        var numTicks = 12
        let width = graphLayer.bounds.width
        while width / CGFloat(numTicks) < 40.0 && numTicks > 3 {
            numTicks -= 1
        }

        let spacing = width / CGFloat(numTicks - 1)
        let height = gridLayer.bounds.height

        for index in 0..<numTicks {
            let pos = CGFloat(index) * spacing
            let freqValue = frequencyValueForLocation(pos)
            let text = stringForValue(freqValue) + (index == 0 ? "Hz" : (freqValue >= 1000 ? "k" : ""))
            let offset = CGFloat(index == 0 ? 32 : (index == (numTicks - 1) ? 10 : 20))
            let labelLayer = makeLabelLayer(text,
                                            frame: CGRect(x: pos + offset, y: height + 4.0, width: 40, height: 16.0),
                                            alignment: .center)

            axisElements.append(labelLayer)
            plotLayer.addSublayer(labelLayer)

            if index > 0 && index < numTicks - 1 {
                let line = CALayer(white: 0.8)
                line.frame = CGRect(x: pos, y: 0, width: 1.0, height: height)
                axisElements.append(line)
                gridLayer.addSublayer(line)
            }
        }
    }
}

// MARK: - Filter Setting Indicator
extension FilterView {

    private func createIndicatorPoint() {
        guard let color = touchDown ? tintColor : Color.darkGray else {
            fatalError("Unable to get color value.")
        }

        let vline = CALayer(color: color)
        vline.name = "v"
        indicatorLayer.addSublayer(vline)

        let hline = CALayer(color: color)
        hline.name = "h"
        indicatorLayer.addSublayer(hline)

        let circle = CALayer(color: color)
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
                    case "pos": return CGRect(x: editPoint.x - 3, y: editPoint.y - 3, width: 7, height: 7)
                    case "h": return CGRect(x: 0, y: editPoint.y, width: width, height: 1.0)
                    case "v": return CGRect(x: editPoint.x, y: 0.0, width: 1.0,  height: height)
                    default: return .zero
                    }
                }($0)
            }
        }
    }
}

extension FilterView {
    private func performLayout(of layer: CALayer) {
        if layer === rootLayer {
            CATransaction.noAnimation {
                plotLayer.bounds = rootLayer.bounds
                graphLayer.bounds = CGRect(x: 0, y: 0, width: layer.bounds.width - yAxisWidth,
                                           height: layer.bounds.height - xAxisHeight - 10.0)
                gridLayer.bounds = graphLayer.bounds
                indicatorLayer.bounds = graphLayer.bounds

                createAxisElements()

                editPoint = CGPoint(x: locationForFrequencyValue(frequency), y: locationForDBValue(resonance))
                curveLayer.bounds = graphLayer.bounds
            }
        }

        updateIndicator()
        frequencies = nil
        delegate?.filterViewDataDidChange(self)
    }

    private func updateFrequenciesAndResonance() {
        let pickedFrequency = frequencyValueForLocation(editPoint.x)
        let pickedResonance = dbValueForLocation(editPoint.y)

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
        editPoint.x = dragPoint.x.clamp(to: 0...graphLayer.bounds.width)
        editPoint.y = dragPoint.y.clamp(to: 0...graphLayer.bounds.height)
    }
}
