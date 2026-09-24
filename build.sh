#!/bin/bash
# Build MacUnikey.app and install it into ~/Library/Input Methods.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/MacUnikey.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -module-name MacUnikey Sources/*.swift \
    -framework InputMethodKit -o "$APP/Contents/MacOS/MacUnikey"
cp Info.plist "$APP/Contents/"

# Menu-bar icon, matching the system "A" badge of U.S.: 22x16pt rounded rect (r=4),
# 12pt bold text knocked out and centered on cap height. 1x + 2x, template (macOS tints it).
swift - <<'EOF2'
import AppKit
let (w, h) = (22, 16)
func rep(_ scale: Int) -> NSBitmapImageRep {
    let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w * scale, pixelsHigh: h * scale, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
    r.size = NSSize(width: w, height: h)
    let ctx = NSGraphicsContext(bitmapImageRep: r)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    NSColor.black.setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: w, height: h), xRadius: 4, yRadius: 4).fill()
    cg.setBlendMode(.destinationOut)
    let font = NSFont.systemFont(ofSize: 12, weight: .bold)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Vi", attributes: [.font: font]))
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    cg.textPosition = CGPoint(x: (Double(w) - width) / 2 + 0.5, y: (Double(h) - font.capHeight) / 2)
    CTLineDraw(line, cg)
    NSGraphicsContext.current = nil
    return r
}
let img = NSImage(size: NSSize(width: w, height: h))
img.addRepresentations([rep(1), rep(2)])
try! img.tiffRepresentation!.write(to: URL(fileURLWithPath: "build/icon.tiff"))

// App icon (Finder): macOS grid — 824pt rounded square centered on a 1024 canvas,
// red gradient with a soft shadow, white "Vi" centered on cap height.
func appIcon(_ px: Int) -> Data {
    let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: r)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    let k = CGFloat(px) / 1024
    cg.scaleBy(x: k, y: k)
    let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 20
    shadow.set()
    NSColor(red: 0.85, green: 0.15, blue: 0.12, alpha: 1).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(red: 0.96, green: 0.30, blue: 0.22, alpha: 1),
               ending: NSColor(red: 0.74, green: 0.09, blue: 0.08, alpha: 1))!.draw(in: body, angle: -90)
    let font = NSFont.systemFont(ofSize: 440, weight: .bold)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Vi",
        attributes: [.font: font, .foregroundColor: NSColor.white]))
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    cg.textPosition = CGPoint(x: (1024 - width) / 2 + 8, y: (1024 - font.capHeight) / 2)
    CTLineDraw(line, cg)
    NSGraphicsContext.current = nil
    return r.representation(using: .png, properties: [:])!
}
let set = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for s in [16, 32, 128, 256, 512] {
    try! appIcon(s).write(to: set.appendingPathComponent("icon_\(s)x\(s).png"))
    try! appIcon(s * 2).write(to: set.appendingPathComponent("icon_\(s)x\(s)@2x.png"))
}
EOF2
cp build/icon.tiff "$APP/Contents/Resources/"
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force -s - "$APP"

DEST="$HOME/Library/Input Methods"
mkdir -p "$DEST"
killall MacUnikey 2>/dev/null || true
rm -rf "$DEST/MacUnikey.app"
cp -R "$APP" "$DEST/"
echo "Installed to $DEST/MacUnikey.app"
