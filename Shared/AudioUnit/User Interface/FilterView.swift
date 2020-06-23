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

    let leftMargin: CGFloat = 54.0
    let bottomMargin: CGFloat = 40.0

    let numDBLines = 8
    lazy var dbSpacing = Int(Self.gainSpan / Float(numDBLines))

    let numFreqLines = 11

    let maxNumberOfResponseFrequencies = 1024
    var frequencies: [Float]?

    var dbLines = [CALayer]()
    var dbLabels = [CATextLayer]()

    var freqLines = [CALayer]()
    var frequencyLabels = [CATextLayer]()

    var controls = [CALayer]()

    var plotLayer = CALayer()
    var graphLayer = CALayer()
    var curveLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        let fillColor = Color(red: 0.067, green: 0.535, blue: 0.842, alpha: 1.000)
        shapeLayer.fillColor = fillColor.cgColor
        return shapeLayer
    }()

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
            bezierPath.addLine(to: CGPoint(x: CGFloat(index) * scale, y: locationForDBValue(magnitude)))
        }

        bezierPath.addLine(to: CGPoint(x: CGFloat(frequencies.count - 1) * scale, y: graphLayer.bounds.height))
        bezierPath.closeSubpath()

        print(bezierPath.boundingBox)

        CATransaction.noAnimation { curveLayer.path = bezierPath }
        updateControls(refreshColor: true)
    }

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

    private func stringForValue(_ value: Float) -> String {
        let value = floor((value >= 1000 ? value / 1000 : value) * 100.0) / 100.0
        return String(format: floor(value) == value ? "%.0f" : "%.1f", value)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        plotLayer.name = "plot"
        plotLayer.anchorPoint = .zero
        plotLayer.bounds = CGRect(origin: .zero, size: rootLayer.bounds.size)
        plotLayer.contentsScale = screenScale
        plotLayer.borderColor = Color.red.cgColor
        plotLayer.borderWidth = 1.0

        rootLayer.addSublayer(plotLayer)
        rootLayer.masksToBounds = false

        graphLayer.name = "graph"
        graphLayer.borderColor = Color.green.cgColor
        graphLayer.borderWidth = 1.0
        graphLayer.backgroundColor = Color(white: 0.88, alpha: 1.0).cgColor
        graphLayer.bounds = CGRect(x: 0, y: 0, width: rootLayer.bounds.width - leftMargin, height: rootLayer.bounds.height - bottomMargin)
        graphLayer.position = CGPoint(x: leftMargin, y: 0)
        graphLayer.anchorPoint = .zero
        graphLayer.contentsScale = screenScale

        plotLayer.addSublayer(graphLayer)

        rootLayer.contentsScale = screenScale

        createDBLabelsAndLines()
        createFrequencyLabelsAndLines()

        curveLayer.anchorPoint = .zero
        curveLayer.position = .zero
        graphLayer.addSublayer(curveLayer)

        createControlPoint()

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

    private func createDBLabelsAndLines() {
        let maxLines = Int(Self.gainSpan / Float(dbSpacing) - 1)
        let minSpacing = CGFloat(20)
        let height = graphLayer.bounds.height

        var lineCount = maxLines
        var spacing = height / CGFloat(maxLines)

        if spacing < minSpacing {
            lineCount = Int(round(graphLayer.bounds.height / minSpacing))
            spacing = height / CGFloat(lineCount)
        }

        for value in stride(from: CGFloat(0), through: height, by: spacing) {
            let labelLayer = makeLabelLayer(alignment: .right)
            labelLayer.string = "\(dbValueForLocation(value)) db"

            dbLabels.append(labelLayer)
            plotLayer.addSublayer(labelLayer)

            if value > 0 && value < height {
                let lineLayer = CALayer(white: 0.8)
                dbLines.append(lineLayer)
                graphLayer.addSublayer(lineLayer)
            }
        }
    }

    private func updateDBLayers() {
        let spacing = graphLayer.bounds.height / CGFloat(dbLines.count + 1)
        let width = graphLayer.bounds.width
        for (index, line) in dbLines.enumerated() {
            line.frame = CGRect(x: 0, y: CGFloat(index + 1) * spacing, width: width, height: 1.0)
        }
    }

    private func createFrequencyLabelsAndLines() {
        for index in 0...numFreqLines {
            let value = valueAtFreqIndex(Float(index))

            let labelLayer = makeLabelLayer()
            var string = stringForValue(value)
            if index == 0 { string += " Hz" }
            else if value >= 1000 { string += "k" }

            labelLayer.string = string
            frequencyLabels.append(labelLayer)
            plotLayer.addSublayer(labelLayer)

            let lineLayer = CALayer(white: 0.8)
            freqLines.append(lineLayer)

            if index > 0 && index < numFreqLines {
                graphLayer.addSublayer(lineLayer)
            }
        }
    }

    private func makeLabelLayer(alignment: CATextLayerAlignmentMode = .center) -> CATextLayer {
        let labelLayer = CATextLayer()
        let fontSize = CGFloat(12)
        let font = CTFontCreateUIFontForLanguage(.label, fontSize, nil)
        labelLayer.font = font
        labelLayer.fontSize = fontSize
        labelLayer.contentsScale = screenScale
        labelLayer.foregroundColor = graphLabelColor.cgColor
        labelLayer.alignmentMode = alignment
        labelLayer.anchorPoint = .zero
        return labelLayer
    }

    private func createControlPoint() {
        guard let color = touchDown ? tintColor : Color.darkGray else {
            fatalError("Unable to get color value.")
        }

        var lineLayer = CALayer(color: color)
        lineLayer.name = "x"
        controls.append(lineLayer)
        graphLayer.addSublayer(lineLayer)

        lineLayer = CALayer(color: color)
        lineLayer.name = "y"
        controls.append(lineLayer)
        graphLayer.addSublayer(lineLayer)

        let circleLayer = CALayer(color: color)
        circleLayer.borderWidth = 2.0
        circleLayer.cornerRadius = 3.0
        circleLayer.name = "point"
        controls.append(circleLayer)

        graphLayer.addSublayer(circleLayer)
    }

    private func updateControls(refreshColor: Bool) {
        let color = touchDown ? tintColor.darker.cgColor: Color.darkGray.cgColor
        CATransaction.noAnimation {
            let width = graphLayer.bounds.width
            let height = graphLayer.bounds.height
            for layer in controls {
                switch layer.name! {
                case "point":
                    layer.frame = CGRect(x: editPoint.x - 3, y: editPoint.y - 3, width: 7, height: 7).integral
                    layer.position = editPoint

                case "x":
                    layer.frame = CGRect(x: 0, y: editPoint.y, width: width, height: 1.0)

                case "y":
                    layer.frame = CGRect(x: editPoint.x, y: 0.0, width: 1.0,  height: height)

                default:
                    layer.frame = .zero
                    continue
                }
                if refreshColor { layer.backgroundColor = color }
            }
        }
    }

    private func updateFrequencyLayers() {
    }

    #if os(iOS)
    override public func layoutSublayers(of layer: CALayer) {
        performLayout(of: layer)
    }
    #elseif os(macOS)
    func layoutSublayers(of layer: CALayer) {
        performLayout(of: layer)
    }
    #endif

    private func performLayout(of layer: CALayer) {
        if layer === rootLayer {
            CATransaction.noAnimation {
                plotLayer.bounds = rootLayer.bounds
                graphLayer.bounds = CGRect(x: 0, y: 0, width: layer.bounds.width - leftMargin,
                                           height: layer.bounds.height - bottomMargin - 10.0)

                updateDBLayers()
                updateFrequencyLayers()
                editPoint = CGPoint(x: locationForFrequencyValue(frequency), y: locationForDBValue(resonance))
                curveLayer.bounds = graphLayer.bounds
            }
        }

        updateControls(refreshColor: false)
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

    #if os(iOS)

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var pointOfTouch = touches.first?.location(in: self) else { return }
        pointOfTouch = CGPoint(x: pointOfTouch.x, y: pointOfTouch.y + bottomMargin)
        if graphLayer.contains(pointOfTouch) {
            touchDown = true
            editPoint = pointOfTouch
            updateFrequenciesAndResonance()
            delegate?.filterViewTouchBegan(self)
        }
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var pointOfTouch = touches.first?.location(in: self) else { return }
        pointOfTouch = CGPoint(x: pointOfTouch.x, y: pointOfTouch.y + bottomMargin)
        if graphLayer.contains(pointOfTouch) {
            handleDrag(pointOfTouch)
            updateFrequenciesAndResonance()
        }
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var pointOfTouch = touches.first?.location(in: self) else { return }
        pointOfTouch = CGPoint(x: pointOfTouch.x, y: pointOfTouch.y + bottomMargin)
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
            updateControls(refreshColor: true)
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
        updateControls(refreshColor: true)
        delegate?.filterViewTouchEnded(self)
    }

    #endif
}
