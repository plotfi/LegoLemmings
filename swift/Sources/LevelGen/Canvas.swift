import AppKit
import CoreGraphics

/// A packed ARGB color.
struct RGB {
  var r: Int, g: Int, b: Int

  init(_ r: Int, _ g: Int, _ b: Int) {
    self.r = r
    self.g = g
    self.b = b
  }

  init(_ hex: Int) {
    self.init((hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF)
  }

  var cgColor: CGColor {
    CGColor(
      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
      components: [CGFloat(r) / 255, CGFloat(g) / 255, CGFloat(b) / 255, 1])!
  }

  /// Mixes toward another color; `t` of 0 is self, 1 is `other`.
  func mix(_ other: RGB, _ t: Double) -> RGB {
    RGB(
      Int(Double(r) + (Double(other.r) - Double(r)) * t),
      Int(Double(g) + (Double(other.g) - Double(g)) * t),
      Int(Double(b) + (Double(other.b) - Double(b)) * t))
  }

  func lighter(_ t: Double) -> RGB { mix(RGB(255, 255, 255), t) }
  func darker(_ t: Double) -> RGB { mix(RGB(0, 0, 0), t) }
}

/// What a shape means to the game, as opposed to what it looks like.
///
/// Everything the engine cares about is in the mask, where only five exact
/// colors are legal. The art can be anything.
enum Material {
  /// Empty space. Lemmings fall through it.
  case air
  /// Terrain that diggers, bashers and miners can carve.
  case dirt
  /// Terrain nothing can carve.
  case rock
  /// Lethal on contact.
  case hazard
  /// The way out.
  case exit

  var maskColor: RGB {
    switch self {
    case .air: return RGB(0x000000)
    case .dirt: return RGB(0xFF0000)
    case .rock: return RGB(0x00FF00)
    case .hazard: return RGB(0xFFFFFF)
    case .exit: return RGB(0x0000FF)
    }
  }
}

/// Draws a level and its collision mask at the same time.
///
/// Every terrain call paints into both images: the art gets the theme's color,
/// the mask gets the one flat color the engine reads. Antialiasing is off
/// everywhere, because a blended mask pixel is a color the engine has no
/// meaning for.
final class Canvas {

  let width: Int
  let height: Int

  private var artPixels: UnsafeMutablePointer<UInt32>
  private var maskPixels: UnsafeMutablePointer<UInt32>
  private let artContext: CGContext
  private let maskContext: CGContext

  init(width: Int, height: Int) {
    self.width = width
    self.height = height
    self.artPixels = .allocate(capacity: width * height)
    self.maskPixels = .allocate(capacity: width * height)
    self.artPixels.initialize(repeating: 0xFF00_0000, count: width * height)
    self.maskPixels.initialize(repeating: 0xFF00_0000, count: width * height)

    func makeContext(_ data: UnsafeMutablePointer<UInt32>) -> CGContext {
      let context = CGContext(
        data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
          | CGBitmapInfo.byteOrder32Little.rawValue)!
      // Draw in top-left-origin coordinates, like the game does.
      context.translateBy(x: 0, y: CGFloat(height))
      context.scaleBy(x: 1, y: -1)
      context.setShouldAntialias(false)
      context.interpolationQuality = .none
      return context
    }
    self.artContext = makeContext(artPixels)
    self.maskContext = makeContext(maskPixels)
  }

  deinit {
    artPixels.deallocate()
    maskPixels.deallocate()
  }

  // MARK: - Terrain (paints art and mask together)

  func fill(_ rect: CGRect, _ material: Material, art: RGB) {
    artContext.setFillColor(art.cgColor)
    artContext.fill(rect)
    maskContext.setFillColor(material.maskColor.cgColor)
    maskContext.fill(rect)
  }

  func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ material: Material, art: RGB) {
    fill(CGRect(x: x, y: y, width: w, height: h), material, art: art)
  }

  func fillEllipse(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ material: Material, art: RGB) {
    let rect = CGRect(x: x, y: y, width: w, height: h)
    artContext.setFillColor(art.cgColor)
    artContext.fillEllipse(in: rect)
    maskContext.setFillColor(material.maskColor.cgColor)
    maskContext.fillEllipse(in: rect)
  }

  /// A filled polygon, for ramps and slopes.
  func fillPolygon(_ points: [(Int, Int)], _ material: Material, art: RGB) {
    guard points.count > 2 else { return }
    let path = CGMutablePath()
    path.move(to: CGPoint(x: points[0].0, y: points[0].1))
    for point in points.dropFirst() {
      path.addLine(to: CGPoint(x: point.0, y: point.1))
    }
    path.closeSubpath()

    artContext.setFillColor(art.cgColor)
    artContext.addPath(path)
    artContext.fillPath()
    maskContext.setFillColor(material.maskColor.cgColor)
    maskContext.addPath(path)
    maskContext.fillPath()
  }

  // MARK: - Decoration (art only, invisible to the engine)

  func decorate(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: RGB) {
    artContext.setFillColor(color.cgColor)
    artContext.fill(CGRect(x: x, y: y, width: w, height: h))
  }

  func decorateEllipse(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: RGB) {
    artContext.setFillColor(color.cgColor)
    artContext.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
  }

  func decoratePolygon(_ points: [(Int, Int)], _ color: RGB) {
    guard points.count > 2 else { return }
    let path = CGMutablePath()
    path.move(to: CGPoint(x: points[0].0, y: points[0].1))
    for point in points.dropFirst() {
      path.addLine(to: CGPoint(x: point.0, y: point.1))
    }
    path.closeSubpath()
    artContext.setFillColor(color.cgColor)
    artContext.addPath(path)
    artContext.fillPath()
  }

  /// Runs `body` with all art shifted down by `dy`, so scenery written against
  /// a nominal ground line lands on the layout's actual one. Decoration only —
  /// the mask is untouched, which is why this cannot move any collision.
  func withVerticalShift(_ dy: Int, _ body: () -> Void) {
    artContext.saveGState()
    artContext.translateBy(x: 0, y: CGFloat(dy))
    body()
    artContext.restoreGState()
  }

  // MARK: - Inspection and output

  func maskColor(atX x: Int, y: Int) -> UInt32 {
    maskPixels[y * width + x] & 0x00FF_FFFF
  }

  func artColor(atX x: Int, y: Int) -> UInt32 {
    artPixels[y * width + x] & 0x00FF_FFFF
  }

  /// Every distinct mask color, for checking that nothing bled.
  func maskColors() -> Set<UInt32> {
    var colors = Set<UInt32>()
    for i in 0..<(width * height) {
      colors.insert(maskPixels[i] & 0x00FF_FFFF)
    }
    return colors
  }

  func writePNGs(artPath: String, maskPath: String) throws {
    try write(artContext, to: artPath)
    try write(maskContext, to: maskPath)
  }

  private func write(_ context: CGContext, to path: String) throws {
    guard let image = context.makeImage() else { return }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try data.write(to: URL(fileURLWithPath: path))
  }
}

/// A small reproducible RNG, so regenerating gives the same levels back.
struct RNG {
  private var state: UInt64

  init(seed: UInt64) {
    self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
  }

  mutating func next() -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }

  /// A value in `low...high`.
  mutating func int(_ low: Int, _ high: Int) -> Int {
    guard high > low else { return low }
    return low + Int(next() % UInt64(high - low + 1))
  }

  mutating func double() -> Double {
    Double(next() % 1_000_000) / 1_000_000
  }

  mutating func chance(_ probability: Double) -> Bool {
    double() < probability
  }

  mutating func pick<T>(_ items: [T]) -> T {
    items[int(0, items.count - 1)]
  }
}
