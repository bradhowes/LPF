// Copyright © 2020 Apple. All rights reserved.

public extension Color {

    var darker: Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(hue: hue, saturation: saturation, brightness: brightness * 0.8, alpha: alpha)
    }

    var lighter: Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(hue: hue, saturation: saturation, brightness: brightness * 1.2, alpha: alpha)
    }
}
