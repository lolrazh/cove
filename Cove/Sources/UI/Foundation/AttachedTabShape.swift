import SwiftUI

/// The active top tab: rounded on top, and flared at the bottom so it runs into
/// the content card below as one surface.
///
/// The shape's rect includes the flares, `flare` points on each side of the
/// tab's body. Draw it with that much negative horizontal padding.
struct AttachedTabShape: Shape {
    var radius: CGFloat = ChromeRadius.tab
    var flare: CGFloat = ChromeRadius.flare

    func path(in rect: CGRect) -> Path {
        let body = rect.insetBy(dx: flare, dy: 0)
        var path = UnevenRoundedRectangle(
            topLeadingRadius: radius,
            topTrailingRadius: radius,
            style: .continuous
        )
        .path(in: body)

        // Concave fillets between the body's sides and the card's top edge.
        // Control points at 0.55 of the radius approximate a quarter circle.
        let k = flare * 0.55
        let bottom = rect.maxY

        path.move(to: CGPoint(x: body.minX, y: bottom - flare))
        path.addLine(to: CGPoint(x: body.minX, y: bottom))
        path.addLine(to: CGPoint(x: body.minX - flare, y: bottom))
        path.addCurve(
            to: CGPoint(x: body.minX, y: bottom - flare),
            control1: CGPoint(x: body.minX - flare + k, y: bottom),
            control2: CGPoint(x: body.minX, y: bottom - flare + k)
        )
        path.closeSubpath()

        path.move(to: CGPoint(x: body.maxX, y: bottom - flare))
        path.addLine(to: CGPoint(x: body.maxX, y: bottom))
        path.addLine(to: CGPoint(x: body.maxX + flare, y: bottom))
        path.addCurve(
            to: CGPoint(x: body.maxX, y: bottom - flare),
            control1: CGPoint(x: body.maxX + flare - k, y: bottom),
            control2: CGPoint(x: body.maxX, y: bottom - flare + k)
        )
        path.closeSubpath()

        return path
    }
}
