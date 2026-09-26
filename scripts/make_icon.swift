// Genera AppIcon.iconset: cuadrado redondeado color terracota con un medidor blanco.
// El medidor se dibuja a mano: la licencia de SF Symbols no permite usarlos en íconos de apps.
import AppKit

let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let size = CGFloat(px)
    let inset = size * 0.1
    let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    NSColor(srgbRed: 0.85, green: 0.47, blue: 0.34, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225).fill()

    // Medidor: arco de 240° con marcas y una aguja apuntando a ~60 %.
    let center = NSPoint(x: size / 2, y: size * 0.45)
    let radius = size * 0.26
    let lineWidth = size * 0.045
    NSColor.white.set()

    let arc = NSBezierPath()
    arc.appendArc(withCenter: center, radius: radius, startAngle: 210, endAngle: -30, clockwise: true)
    arc.lineWidth = lineWidth
    arc.lineCapStyle = .round
    arc.stroke()

    for step in 0...4 {
        let angle = (210 - CGFloat(step) * 60) * .pi / 180
        let dot = radius * 0.72
        let r = lineWidth * 0.55
        let p = NSPoint(x: center.x + cos(angle) * dot, y: center.y + sin(angle) * dot)
        NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)).fill()
    }

    let needleAngle: CGFloat = 66 * .pi / 180
    let needle = NSBezierPath()
    needle.move(to: center)
    needle.line(to: NSPoint(x: center.x + cos(needleAngle) * radius * 0.85,
                            y: center.y + sin(needleAngle) * radius * 0.85))
    needle.lineWidth = lineWidth
    needle.lineCapStyle = .round
    needle.stroke()
    let hub = lineWidth * 1.1
    NSBezierPath(ovalIn: NSRect(x: center.x - hub, y: center.y - hub, width: 2 * hub, height: 2 * hub)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(base)x\(base)@2x.png"))
}
