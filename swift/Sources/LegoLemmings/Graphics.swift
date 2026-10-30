import AppKit
import CoreGraphics
import CoreText

/// The AWT color constants the original drew with, pinned to the same sRGB
/// space the bitmaps use so a fill lands on the exact byte values the mask is
/// later compared against.
enum AWTColor {
  static let space = CGColorSpace(name: CGColorSpace.sRGB)!

  static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, 1])!
  }

  /// Unpacks a `0xAARRGGBB` word, ignoring alpha the way `new Color(int)` does.
  static func packed(_ argb: UInt32) -> CGColor {
    rgb(
      CGFloat((argb >> 16) & 0xFF) / 255,
      CGFloat((argb >> 8) & 0xFF) / 255,
      CGFloat(argb & 0xFF) / 255)
  }

  static let black = rgb(0, 0, 0)
  static let blue = rgb(0, 0, 1)
  static let green = rgb(0, 1, 0)
  static let red = rgb(1, 0, 0)
  static let white = rgb(1, 1, 1)
  static let yellow = rgb(1, 1, 0)
  static let orange = rgb(1, 200.0 / 255.0, 0)  // java.awt.Color.ORANGE
}

/// A thin `java.awt.Graphics2D` stand-in that works in AWT's coordinate system:
/// origin top-left, y growing downward, `drawString` placing the text baseline.
///
/// Core Graphics is y-up, so every call flips its rect here. Doing the flip per
/// call rather than with a flipped CTM keeps `draw(image:in:)` upright, which a
/// flipped CTM would invert on each of the ~50 sprite draws per frame.
final class Graphics {

  private let context: CGContext
  private let logicalHeight: CGFloat
  private let didDraw: (() -> Void)?

  private var color: CGColor = AWTColor.black
  private var font: NSFont = .systemFont(ofSize: 12)

  init(context: CGContext, logicalHeight: CGFloat, didDraw: (() -> Void)? = nil) {
    self.context = context
    self.logicalHeight = logicalHeight
    self.didDraw = didDraw
    context.interpolationQuality = .none
    context.setLineWidth(1)
  }

  // MARK: - State

  func setColor(_ color: CGColor) {
    self.color = color
  }

  func setFont(size: CGFloat, bold: Bool = false) {
    font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
  }

  // MARK: - Coordinates

  /// Converts an AWT rect (y measured down from the top) into a CG rect.
  private func flip<T: BinaryInteger>(_ x: T, _ y: T, _ w: T, _ h: T) -> CGRect {
    CGRect(
      x: CGFloat(x), y: logicalHeight - CGFloat(y) - CGFloat(h),
      width: CGFloat(w), height: CGFloat(h))
  }

  // MARK: - Shapes

  func fillRect<T: BinaryInteger>(_ x: T, _ y: T, _ w: T, _ h: T) {
    context.setFillColor(color)
    context.fill(flip(x, y, w, h))
    didDraw?()
  }

  func drawRect<T: BinaryInteger>(_ x: T, _ y: T, _ w: T, _ h: T) {
    context.setStrokeColor(color)
    context.setLineWidth(1)
    context.stroke(flip(x, y, w, h).insetBy(dx: 0.5, dy: 0.5))
    didDraw?()
  }

  func drawOval<T: BinaryInteger>(_ x: T, _ y: T, _ w: T, _ h: T) {
    context.setStrokeColor(color)
    context.setLineWidth(1)
    context.strokeEllipse(in: flip(x, y, w, h).insetBy(dx: 0.5, dy: 0.5))
    didDraw?()
  }

  func fillOval<T: BinaryInteger>(_ x: T, _ y: T, _ w: T, _ h: T) {
    context.setFillColor(color)
    context.fillEllipse(in: flip(x, y, w, h))
    didDraw?()
  }

  /// A filled polygon in AWT coordinates, for shapes a rect cannot make.
  func fillPolygon<T: BinaryInteger>(_ points: [(T, T)]) {
    guard points.count > 2 else { return }
    let path = CGMutablePath()
    func place(_ p: (T, T)) -> CGPoint {
      CGPoint(x: CGFloat(p.0), y: logicalHeight - CGFloat(p.1))
    }
    path.move(to: place(points[0]))
    for point in points.dropFirst() { path.addLine(to: place(point)) }
    path.closeSubpath()
    context.setFillColor(color)
    context.addPath(path)
    context.fillPath()
    didDraw?()
  }

  // MARK: - Images

  func drawImage<T: BinaryInteger>(_ image: CGImage, _ x: T, _ y: T) {
    drawImage(image, x, y, T(image.width), T(image.height))
  }

  func drawImage<T: BinaryInteger>(_ image: CGImage, _ x: T, _ y: T, _ w: T, _ h: T) {
    guard w > 0, h > 0 else { return }
    context.draw(image, in: flip(x, y, w, h))
    didDraw?()
  }

  func drawImage<T: BinaryInteger>(_ bitmap: Bitmap, _ x: T, _ y: T) {
    drawImage(bitmap.cgImage, x, y)
  }

  func drawImage<T: BinaryInteger>(_ bitmap: Bitmap, _ x: T, _ y: T, _ w: T, _ h: T) {
    drawImage(bitmap.cgImage, x, y, w, h)
  }

  // MARK: - Text

  /// Draws `text` with its baseline at AWT coordinate (`x`, `y`), matching
  /// `Graphics.drawString`, which is what every hardcoded label position in the
  /// original assumes.
  func drawString<T: BinaryInteger>(_ text: String, _ x: T, _ y: T) {
    let attributed = NSAttributedString(
      string: text,
      attributes: [.font: font, .foregroundColor: NSColor(cgColor: color) ?? .labelColor])
    let line = CTLineCreateWithAttributedString(attributed)

    context.saveGState()
    context.textMatrix = .identity
    context.setFillColor(color)
    context.textPosition = CGPoint(x: CGFloat(x), y: logicalHeight - CGFloat(y))
    CTLineDraw(line, context)
    context.restoreGState()
    didDraw?()
  }
}
