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
EOF2
cp build/icon.tiff "$APP/Contents/Resources/"

codesign --force -s - "$APP"

DEST="$HOME/Library/Input Methods"
mkdir -p "$DEST"
killall MacUnikey 2>/dev/null || true
rm -rf "$DEST/MacUnikey.app"
cp -R "$APP" "$DEST/"
echo "Installed to $DEST/MacUnikey.app"
