// Draws the macOS disk image's artwork into an output folder:
//   background.png, background@2x.png  the window background: the app icon's
//                                      bird, with the app sitting on its green
//                                      (start) dot and Applications on its
//                                      pink (destination) dot
//   Applications                       a Finder alias to /Applications with
//                                      its folder icon tinted the dot's pink
// Usage: swift dmg-art.swift out-dir
//
// The window size and icon positions must match scripts/dmg-settings.py.
// Drawn with Core Graphics rather than SVG because AppKit's SVG support
// can't render the text line.
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

// The window's content size in points, and the scale and offset that place
// the icon's 1024-unit drawing in it.
let width: CGFloat = 640
let height: CGFloat = 400
let scale: CGFloat = 0.62
// The icon's green dot (182, 468) lands at (115.4, 165).
let offsetX: CGFloat = width / 2 - 512 * scale
let offsetY: CGFloat = 165 - 468 * scale
// Where Finder draws the two icons (their centers), set in dmg-settings.py.
// A little above the dots: with a label underneath, an icon centered
// exactly on its dot reads as sitting low.
let iconCenters: [CGFloat] = [115, 525]
let iconY: CGFloat = 155
let iconSize: CGFloat = 128

// The space between the wings and anything they meet.
let gap: CGFloat = 7

// What's visibly drawn of each 128pt icon, measured from a screenshot of the
// window: the app's rounded tile (Apple's icon grid: 824 of 1024, corner
// 185) and the Applications folder, which sits a little high in its square.
let tileSide = iconSize * 824 / 1024
let iconShapes: [(rect: CGRect, radius: CGFloat)] = [
  (CGRect(x: iconCenters[0] - tileSide / 2, y: iconY - tileSide / 2,
          width: tileSide, height: tileSide), iconSize * 185 / 1024),
  (CGRect(x: iconCenters[1] - 59, y: iconY - 48, width: 118, height: 95), 6),
]
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
  CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
}

func color(_ hex: UInt32) -> CGColor {
  CGColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
    green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255,
    alpha: 1)
}

// A shade lighter than the icon's own navy, so the app icon's navy tile still
// stands out against it.
let background = color(0x1A2331)
let orange = color(0xE69F00)
let skyBlue = color(0x56B4E9)
let pink = color(0xCC79A7)
let hint = NSColor(srgbRed: 0x9B / 255, green: 0xAE / 255, blue: 0xC4 / 255, alpha: 1)
// Finder draws icon labels in black on a background picture, even in dark
// mode, and has no setting for their color, so each label gets a light plate
// behind it: a pale tint of its own dot's color.
let plates = [color(0xD5F0E7), color(0xF5E1EC)]
// Both plates are one width, fitting the longest name in Finder's label font
// (the system font at dmg-settings.py's text_size). That includes
// "Flights.app": Macs set to show all filename extensions show it, despite
// the disk image asking to hide it, so the app's plate can't hug "Flights".
let labelFont = NSFont.systemFont(ofSize: 16)
let platePadding: CGFloat = 10
let plateWidth: CGFloat = ceil(
  ["Flights.app", "Applications"]
    .map { NSAttributedString(string: $0, attributes: [.font: labelFont]).size().width }
    .max()!) + 2 * platePadding
let plateHeight: CGFloat = 22
// The plate's top, below the icon's bottom edge, so it's centered on the
// name (measured from a screenshot of the window).
let plateGap: CGFloat = 9

func drawBackground(pixelScale: CGFloat) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width * pixelScale),
    pixelsHigh: Int(height * pixelScale), bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
    bitsPerPixel: 0)!
  // Points, not pixels, so the 2x image reads as 144 dpi and Finder (via
  // tiffutil) pairs the two as one retina background.
  rep.size = NSSize(width: width, height: height)
  NSGraphicsContext.saveGraphicsState()
  let ns = NSGraphicsContext(bitmapImageRep: rep)!
  NSGraphicsContext.current = ns
  let ctx = ns.cgContext
  // Flip to top-left origin, the way Finder (and the icon's SVG) measure.
  ctx.translateBy(x: 0, y: height)
  ctx.scaleBy(x: 1, y: -1)

  ctx.setFillColor(background)
  ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

  // The wings, as in flights_icon.svg; their ends run under the icons and
  // the middle dot, then are cut back to leave a gap around each.
  let wings = CGMutablePath()
  wings.move(to: p(182, 468))
  wings.addCurve(to: p(512, 597), control1: p(284, 426), control2: p(444, 435))
  wings.addCurve(to: p(842, 468), control1: p(580, 435), control2: p(740, 426))
  ctx.addPath(wings)
  ctx.setStrokeColor(orange)
  ctx.setLineWidth(48 * scale)
  ctx.setLineCap(.round)
  ctx.setLineJoin(.round)
  ctx.strokePath()

  // Gaps between the wings and the icons, the same width as the ring around
  // the middle dot: each icon's visible shape (not its 128pt square, which
  // has transparent margins), grown by the gap, painted over in the
  // background color.
  ctx.setFillColor(background)
  for shape in iconShapes {
    let rect = shape.rect.insetBy(dx: -gap, dy: -gap)
    let radius = shape.radius + gap
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
  }

  // Label plates, just under each icon where Finder puts its name.
  for (x, fill) in zip(iconCenters, plates) {
    let rect = CGRect(
      x: x - plateWidth / 2, y: iconY + iconSize / 2 + plateGap,
      width: plateWidth, height: plateHeight)
    let radius = plateHeight / 2
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(fill)
    ctx.fillPath()
  }

  // The middle airport stays a dot, with a gap (the background color, not
  // an outline) between it and the wings, as around the icons.
  let mid = p(512, 597)
  let r = 58 * scale
  ctx.setFillColor(background)
  ctx.fillEllipse(in: CGRect(x: mid.x - r - gap, y: mid.y - r - gap,
                             width: 2 * (r + gap), height: 2 * (r + gap)))
  ctx.setFillColor(skyBlue)
  ctx.fillEllipse(in: CGRect(x: mid.x - r, y: mid.y - r, width: 2 * r, height: 2 * r))

  // Text draws upside down in the flipped context, so unflip around it.
  let text = NSAttributedString(
    string: "Drag Flights to Applications",
    attributes: [
      .font: NSFont.systemFont(ofSize: 14, weight: .medium),
      .foregroundColor: hint,
    ])
  let size = text.size()
  ctx.saveGState()
  ctx.translateBy(x: 0, y: height)
  ctx.scaleBy(x: 1, y: -1)
  text.draw(at: NSPoint(x: (width - size.width) / 2, y: 52))
  ctx.restoreGState()

  NSGraphicsContext.restoreGraphicsState()
  return rep
}

for (name, pixelScale) in [("background.png", 1.0), ("background@2x.png", 2.0)] {
  let rep = drawBackground(pixelScale: pixelScale)
  try rep.representation(using: .png, properties: [:])!
    .write(to: outDir.appendingPathComponent(name))
}

// The Applications folder's own icon, recolored: the tint takes the pink's
// hue and saturation but keeps the icon's lightness, so the folder's shading
// and the "A" glyph survive, as with Finder's own folder colors.
func pinkFolderIcon() -> NSImage {
  let side = 1024
  let source = NSWorkspace.shared.icon(forFile: "/Applications")
  source.size = NSSize(width: side, height: side)
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  let ns = NSGraphicsContext(bitmapImageRep: rep)!
  NSGraphicsContext.current = ns
  let ctx = ns.cgContext
  let rect = CGRect(x: 0, y: 0, width: side, height: side)
  source.draw(in: rect)
  ctx.setBlendMode(.color)
  ctx.setFillColor(pink)
  ctx.fill(rect)
  // The fill covered the transparent corners too; cut back to the icon.
  // NSImage drawing ignores the context's blend mode, so the operation is
  // passed to it directly.
  ctx.setBlendMode(.normal)
  source.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
  NSGraphicsContext.restoreGraphicsState()
  let image = NSImage(size: NSSize(width: side, height: side))
  image.addRepresentation(rep)
  return image
}

// An alias rather than the usual symlink, because Finder shows a custom icon
// on an alias but not on a symlink. Dropping the app on it copies into
// /Applications all the same.
let alias = outDir.appendingPathComponent("Applications")
try? FileManager.default.removeItem(at: alias)
let bookmark = try URL(fileURLWithPath: "/Applications").bookmarkData(
  options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
try URL.writeBookmarkData(bookmark, to: alias)
guard NSWorkspace.shared.setIcon(pinkFolderIcon(), forFile: alias.path, options: []) else {
  fatalError("couldn't set the Applications alias's icon")
}
