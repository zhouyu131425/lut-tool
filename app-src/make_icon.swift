import AppKit

/// 生成 App 图标：深色圆角底 + 橙色 LUT 立方体风面板
let px = 512
let size = NSSize(width: px, height: px)
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0) else {
    fatalError("cannot create bitmap")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// 外底：深色圆角方块（macOS 图标惯例，四角透明）
NSColor(calibratedRed: 0.075, green: 0.075, blue: 0.09, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: px, height: px), xRadius: 96, yRadius: 96).fill()

// 橙色渐变面板
let panel = NSRect(x: 84, y: 84, width: px - 168, height: px - 168)
let panelPath = NSBezierPath(roundedRect: panel, xRadius: 52, yRadius: 52)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 1.00, green: 0.60, blue: 0.10, alpha: 1),
    NSColor(calibratedRed: 0.92, green: 0.42, blue: 0.05, alpha: 1)
])!
gradient.draw(in: panelPath, angle: 60)

// 面板内三个小方块，示意 3D LUT 查找表
let small = NSRect(x: 0, y: 0, width: 78, height: 78)
let cyan = NSColor(calibratedRed: 0.36, green: 0.90, blue: 0.86, alpha: 1)
let magenta = NSColor(calibratedRed: 0.95, green: 0.38, blue: 0.66, alpha: 1)
let yellow = NSColor(calibratedRed: 0.99, green: 0.85, blue: 0.25, alpha: 1)
func drawCube(_ x: CGFloat, _ y: CGFloat, _ color: NSColor) {
    let r = NSRect(x: x, y: y, width: small.width, height: small.height)
    let p = NSBezierPath(roundedRect: r, xRadius: 18, yRadius: 18)
    color.setFill()
    p.fill()
    NSColor(calibratedWhite: 0, alpha: 0.25).setStroke()
    p.lineWidth = 6
    p.stroke()
}
let panelMinX = panel.minX, panelMaxX = panel.maxX, panelMinY = panel.minY, panelMaxY = panel.maxY
let gap: CGFloat = 34
drawCube(panelMinX + gap, panelMaxY - gap - 78, cyan)
drawCube(panel.midX - 39, panel.midY - 39, magenta)
drawCube(panelMaxX - gap - 78, panelMinY + gap, yellow)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode failed")
}
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png")
try! png.write(to: out)
print("icon written: \(out.path)")
