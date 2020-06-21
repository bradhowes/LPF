// Copyright © 2020 Brad Howes. All rights reserved.

public let defaultMinHertz = Float(12.0)
public let defaultMaxHertz = Float(20_000.0)
public let defaultMinGain = Float(-20)
public let defaultMaxGain = Float(20)

protocol FilterViewDelegate: class {
    func filterViewTouchBegan(_ filterView: FilterView)
    func filterView(_ filterView: FilterView, didChangeResonance resonance: Float)
    func filterView(_ filterView: FilterView, didChangeFrequency frequency: Float)
    func filterView(_ filterView: FilterView, didChangeFrequency frequency: Float, andResonance resonance: Float)
    func filterViewTouchEnded(_ filterView: FilterView)
    func filterViewDataDidChange(_ filterView: FilterView)
}

extension Comparable {
    func clamp(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}

extension CATransaction {
    class func noAnimation(_ completion: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        completion()
        CATransaction.commit()
    }
}

extension Color {
    var darker: Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(hue: hue, saturation: saturation, brightness: brightness * 0.8, alpha: alpha)
    }
}

class FilterView: View {
    let logBase = 2
    let leftMargin: CGFloat = 54.0
    let rightMargin: CGFloat = 10.0
    let bottomMargin: CGFloat = 40.0

    let numDBLines = 8
    lazy var dbSpacing = Int((defaultMaxGain - defaultMinGain) / Float(numDBLines))
    let numFreqLines = 11

    let labelWidth: CGFloat = 40.0
    let maxNumberOfResponseFrequencies = 1024

    var frequencies: [Float]?

    var dbLines = [CALayer]()
    var dbLabels = [CATextLayer]()

    var freqLines = [CALayer]()
    var frequencyLabels = [CATextLayer]()

    var controls = [CALayer]()

    var graphLayer = CALayer()
    var containerLayer = CALayer()

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

    var frequency: Float = defaultMinHertz {
        didSet {
            frequency = frequency.clamp(to: defaultMinHertz...defaultMaxHertz)
            editPoint.x = floor(locationForFrequencyValue(frequency))
        }
    }

    var resonance: Float = 0.0 {
        didSet {
            resonance = resonance.clamp(to: defaultMinGain...defaultMaxGain)
            editPoint.y = floor(locationForDBValue(resonance))
        }
    }

    func valueAtFreqIndex(_ index: Float) -> Float { defaultMinHertz * powf(Float(logBase), index) }

    func logValueForNumber(_ number: Float, base: Float) -> Float { logf(number) / logf(base) }

    func frequencyDataForDrawing() -> [Float] {
        guard frequencies == nil else { return frequencies! }

        let width = graphLayer.bounds.width
        let rightEdge = width + leftMargin

        var pixelRatio = Int(ceil(width / CGFloat(maxNumberOfResponseFrequencies)))
        var location = leftMargin
        var locationsCount = maxNumberOfResponseFrequencies

        if pixelRatio <= 1 {
            pixelRatio = 1
            locationsCount = Int(width)
        }

        frequencies = (0..<locationsCount).map { _ in
            guard location <= rightEdge else { return defaultMaxHertz }
            let frequency = frequencyValueForLocation(location).clamp(to: defaultMinHertz...defaultMaxHertz)
            location += CGFloat(pixelRatio)
            return frequency
        }
        return frequencies!
    }

    func setMagnitudes(_ magnitudeData: [Float]) {
        let bezierPath = CGMutablePath()
        let width = graphLayer.bounds.width

        bezierPath.move(to: CGPoint(x: leftMargin, y: graphLayer.frame.height + bottomMargin))

        var lastDBPosition: CGFloat = 0.0
        var location: CGFloat = leftMargin
        let frequencyCount = frequencies?.count ?? 0
        let pixelRatio = Int(ceil(width / CGFloat(frequencyCount)))

        for i in 0 ..< frequencyCount {
            let dbValue = 20.0 * log10(magnitudeData[i])
            var dbPosition: CGFloat = 0.0

            switch dbValue {
            case let x where x < defaultMinGain: dbPosition = locationForDBValue(defaultMinGain)
            case let x where x > defaultMaxGain: dbPosition = locationForDBValue(defaultMaxGain)
            default: dbPosition = locationForDBValue(dbValue)
            }

            if abs(lastDBPosition - dbPosition) >= 0.1 {
                bezierPath.addLine(to: CGPoint(x: location, y: dbPosition))
            }

            lastDBPosition = dbPosition
            location += CGFloat(pixelRatio)

            if location > width + graphLayer.frame.origin.x {
                location = width + graphLayer.frame.origin.x
                break
            }
        }

        bezierPath.addLine(to: CGPoint(x: location,
                                       y: graphLayer.frame.origin.y + graphLayer.frame.height + bottomMargin))
        bezierPath.closeSubpath()

        CATransaction.noAnimation { curveLayer.path = bezierPath }
        updateControls(refreshColor: true)
    }

    private func locationForFrequencyValue(_ value: Float) -> CGFloat {
        let pixelIncrement = graphLayer.frame.width / CGFloat(numFreqLines)
        let number = value / defaultMinHertz
        let location = logValueForNumber(number, base: Float(logBase)) * Float(pixelIncrement)
        return floor(CGFloat(location) + graphLayer.frame.origin.x) + 0.5
    }

    private func frequencyValueForLocation(_ location: CGFloat) -> Float {
        let pixelIncrement = graphLayer.frame.width / CGFloat(numFreqLines)
        let index = (location - graphLayer.frame.origin.x) / CGFloat(pixelIncrement)
        return valueAtFreqIndex(Float(index))
    }

    private func dbValueForLocation(_ location: CGFloat) -> Float {
        let step = graphLayer.frame.height / CGFloat(defaultMaxGain - defaultMinGain)
        return Float(-(((location - bottomMargin) / step) - CGFloat(defaultMaxGain)))
    }

    private func locationForDBValue(_ value: Float) -> CGFloat {
        let step = graphLayer.frame.height / CGFloat(defaultMaxGain - defaultMinGain)
        let location = (CGFloat(value) + CGFloat(defaultMaxGain)) * step
        return graphLayer.frame.height - location + bottomMargin
    }

    private func stringForValue(_ value: Float) -> String {
        var temp = value

        if value >= 1000 {
            temp /= 1000
        }

        temp = floor((temp * 100.0) / 100.0)

        if floor(temp) == temp {
            return String(format: "%.0f", temp)
        } else {
            return String(format: "%.1f", temp)
        }
    }

    #if os(macOS)
    override var isFlipped: Bool { return true }
    #endif

    private func newLayer(of size: CGSize) -> CALayer {
        let layer = CALayer()
        layer.anchorPoint = .zero
        layer.frame = CGRect(origin: .zero, size: size)
        layer.contentsScale = screenScale
        return layer
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        // Create all of the CALayers for the graph, lines, and labels.

        containerLayer.name = "container"
        containerLayer.anchorPoint = .zero
        containerLayer.frame = CGRect(origin: .zero, size: rootLayer.bounds.size)
        containerLayer.bounds = containerLayer.frame
        containerLayer.contentsScale = screenScale
        rootLayer.addSublayer(containerLayer)
        rootLayer.masksToBounds = false

        graphLayer.name = "graph background"
        graphLayer.borderColor = Color.darkGray.cgColor
        graphLayer.borderWidth = 1.0
        graphLayer.backgroundColor = Color(white: 0.88, alpha: 1.0).cgColor
        graphLayer.bounds = CGRect(x: 0, y: 0,
                                   width: rootLayer.frame.width - leftMargin,
                                   height: rootLayer.frame.height - bottomMargin)
        graphLayer.position = CGPoint(x: leftMargin, y: 0)
        graphLayer.anchorPoint = CGPoint.zero
        graphLayer.contentsScale = screenScale

        containerLayer.addSublayer(graphLayer)

        rootLayer.contentsScale = screenScale

        createDBLabelsAndLines()
        createFrequencyLabelsAndLines()

        graphLayer.addSublayer(curveLayer)
        createControlPoint()

        #if os(macOS)
        layoutSublayers(of: rootLayer)
        #endif
    }

    var graphLabelColor: Color {
        #if os(iOS)
        return Color(white: 0.1, alpha: 1.0)
        #elseif os(macOS)
        return Color.labelColor // Use Appearance-aware label color
        #endif
    }
    
    #if os(macOS)
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutSublayers(of: rootLayer)
    }
    #endif

    func createDBLabelsAndLines() {
        for index in 0...numDBLines {
            let value = index * dbSpacing + Int(defaultMinGain)
            let labelLayer = makeLabelLayer(alignment: .right)
            labelLayer.string = "\(value) db"

            dbLabels.append(labelLayer)
            containerLayer.addSublayer(labelLayer)

            let lineLayer = ColorLayer(white: index == 0 ? 0.65 : 0.8)
            dbLines.append(lineLayer)

            if index > 0 && index < numDBLines {
                graphLayer.addSublayer(lineLayer)
            }
        }
    }

    class ColorLayer: CALayer {

        init(white: CGFloat) {
            super.init()
            backgroundColor = Color(white: white, alpha: 1.0).cgColor
        }

        init(color: Color) {
            super.init()
            backgroundColor = color.cgColor
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
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
            containerLayer.addSublayer(labelLayer)

            let lineLayer = ColorLayer(white: 0.8)
            freqLines.append(lineLayer)

            if index > 0 && index < numFreqLines {
                graphLayer.addSublayer(lineLayer)
            }
        }
    }

    private func makeLabelLayer(alignment: CATextLayerAlignmentMode = .center) -> CATextLayer {
        let labelLayer = CATextLayer()
        labelLayer.font = Font.systemFont(ofSize: 14).fontName as CFTypeRef
        labelLayer.fontSize = 14
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

        var lineLayer = ColorLayer(color: color)
        lineLayer.name = "x"
        controls.append(lineLayer)
        graphLayer.addSublayer(lineLayer)

        lineLayer = ColorLayer(color: color)
        lineLayer.name = "y"
        controls.append(lineLayer)
        graphLayer.addSublayer(lineLayer)

        let circleLayer = ColorLayer(color: color)
        circleLayer.borderWidth = 2.0
        circleLayer.cornerRadius = 3.0
        circleLayer.name = "point"
        controls.append(circleLayer)

        graphLayer.addSublayer(circleLayer)
    }

    func updateControls(refreshColor: Bool) {
        let color = touchDown ? tintColor.darker.cgColor: Color.darkGray.cgColor
        CATransaction.noAnimation {
            let posX = graphLayer.frame.origin.x
            let width = graphLayer.frame.width
            let height = graphLayer.frame.height
            for layer in controls {
                switch layer.name! {
                case "point":
                    layer.frame = CGRect(x: editPoint.x - 3, y: editPoint.y - 3, width: 7, height: 7).integral
                    layer.position = editPoint

                case "x":
                    layer.frame = CGRect(x: posX, y: floor(editPoint.y + 0.5), width: width, height: 1.0)

                case "y":
                    layer.frame = CGRect(x: floor(editPoint.x) + 0.5, y: bottomMargin, width: 1.0,  height: height)

                default:
                    layer.frame = .zero
                    continue
                }
                if refreshColor { layer.backgroundColor = color }
            }
        }
    }

    private func updateDBLayers() {
        let lineX = graphLayer.frame.origin.x
        let lineWidth = graphLayer.frame.width
        let labelYOffset = bottomMargin + 8
        let labelWidth = leftMargin - 7.0
        for index in 0...numDBLines {
            let value = Float(index * dbSpacing) + defaultMinGain
            let location = floor(locationForDBValue(value))
            dbLines[index].frame = CGRect(x: lineX, y: location, width: lineWidth, height: 1.0)
            dbLabels[index].frame = CGRect(x: 0.0, y: location - labelYOffset, width: labelWidth, height: 16.0)
        }
    }

    private func updateFrequencyLayers() {
        let graphHeight = graphLayer.frame.height
        let halfWidth = labelWidth / 2.0
        for index in 0...numFreqLines {
            let value = valueAtFreqIndex(Float(index))
            let pos = floor(locationForFrequencyValue(value))
            freqLines[index].frame = CGRect(x: pos, y: bottomMargin, width: 1.0, height: graphHeight)
            frequencyLabels[index].frame = CGRect(x: pos - halfWidth, y: graphHeight + 16, width: labelWidth + rightMargin, height: 16.0)
        }
    }

    #if os(iOS)
    override func layoutSublayers(of layer: CALayer) {
        performLayout(of: layer)
    }
    #elseif os(macOS)
    func layoutSublayers(of layer: CALayer) {
        performLayout(of: layer)
    }
    #endif

    func performLayout(of layer: CALayer) {
        if layer === rootLayer {
            CATransaction.noAnimation {
                containerLayer.bounds = rootLayer.bounds
                graphLayer.bounds = CGRect(x: leftMargin, y: bottomMargin,
                                           width: layer.bounds.width - leftMargin - rightMargin,
                                           height: layer.bounds.height - bottomMargin - 10.0)
                updateDBLayers()
                updateFrequencyLayers()
                editPoint = CGPoint(x: locationForFrequencyValue(frequency), y: locationForDBValue(resonance))
                curveLayer.bounds = graphLayer.bounds
                curveLayer.frame = CGRect(x: graphLayer.frame.origin.x,
                                          y: graphLayer.frame.origin.y + bottomMargin,
                                          width: graphLayer.frame.width,
                                          height: graphLayer.frame.height)
            }
        }

        updateControls(refreshColor: false)
        frequencies = nil
        delegate?.filterViewDataDidChange(self)
    }

    func updateFrequenciesAndResonance() {
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

    #if os(iOS)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var pointOfTouch = touches.first?.location(in: self) else { return }
        pointOfTouch = CGPoint(x: pointOfTouch.x, y: pointOfTouch.y + bottomMargin)
        if graphLayer.contains(pointOfTouch) {
            touchDown = true
            editPoint = pointOfTouch
            updateFrequenciesAndResonance()
            delegate?.filterViewTouchBegan(self)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var pointOfTouch = touches.first?.location(in: self) else { return }
        pointOfTouch = CGPoint(x: pointOfTouch.x, y: pointOfTouch.y + bottomMargin)
        if graphLayer.contains(pointOfTouch) {
            handleDrag(pointOfTouch)
            updateFrequenciesAndResonance()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var pointOfTouch = touches.first?.location(in: self) else { return }
        pointOfTouch = CGPoint(x: pointOfTouch.x, y: pointOfTouch.y + bottomMargin)
        if graphLayer.contains(pointOfTouch) { handleDrag(pointOfTouch) }
        touchDown = false
        updateFrequenciesAndResonance()
        delegate?.filterViewTouchEnded(self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchDown = false }

    #elseif os(macOS)

    override func mouseDown(with event: NSEvent) {
        let pointOfTouch = NSPointToCGPoint(convert(event.locationInWindow, from: nil))
        let convertedPoint = rootLayer.convert(pointOfTouch, to: graphLayer)
        if graphLayer.contains(convertedPoint) {
            let layerPoint = rootLayer.convert(pointOfTouch, to: graphLayer)
            touchDown = true
            editPoint = layerPoint
            updateControls(refreshColor: true)
            delegate?.filterViewTouchBegan(self)
            updateFrequenciesAndResonance()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let pointOfClick = NSPointToCGPoint(convert(event.locationInWindow, from: nil))
        let convertedPoint = rootLayer.convert(pointOfClick, to: graphLayer)
        if graphLayer.contains(convertedPoint) {
            handleDrag(convertedPoint)
            updateFrequenciesAndResonance()
        }
    }

    override func mouseUp(with event: NSEvent) {
        touchDown = false
        updateControls(refreshColor: true)
        delegate?.filterViewTouchEnded(self)
    }

    #endif

    func handleDrag(_ dragPoint: CGPoint) {
        editPoint.x = dragPoint.x.clamp(to: 0...(graphLayer.frame.width + leftMargin))
        editPoint.y = dragPoint.y.clamp(to: 0...(graphLayer.frame.height + bottomMargin))
    }
}
