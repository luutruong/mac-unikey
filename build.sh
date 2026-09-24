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

# Menu-bar icon: rounded square with "Vi" knocked out, 1x + 2x, template (macOS tints it).
swift - <<'EOF2'
import AppKit
func rep(_ scale: Int) -> NSBitmapImageRep {
    let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 16 * scale, pixelsHigh: 16 * scale, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
    r.size = NSSize(width: 16, height: 16)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: r)!
    NSGraphicsContext.current = ctx
    NSColor.black.setFill()
    NSBezierPath(roundedRect: NSRect(x: 0.5, y: 1.5, width: 15, height: 13), xRadius: 3.5, yRadius: 3.5).fill()
    ctx.cgContext.setBlendMode(.destinationOut)
    let s = NSAttributedString(string: "Vi", attributes: [.font: NSFont.systemFont(ofSize: 10.5, weight: .bold)])
    let b = s.boundingRect(with: .zero, options: [.usesLineFragmentOrigin, .usesFontLeading])
    s.draw(at: NSPoint(x: (16 - b.width) / 2, y: (16 - b.height) / 2 + 0.25))
    NSGraphicsContext.restoreGraphicsState()
    return r
}
let img = NSImage(size: NSSize(width: 16, height: 16))
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
