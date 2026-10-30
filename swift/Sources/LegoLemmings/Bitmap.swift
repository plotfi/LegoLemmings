import AppKit
import CoreGraphics

/// A mutable ARGB image: the stand-in for `java.awt.image.BufferedImage`.
///
/// Pixels are stored as packed `0xAARRGGBB` words, byte-for-byte the layout
/// Java's `TYPE_INT_ARGB` uses, so `getRGB`/`setRGB` return and accept exactly
/// the values the ported code compares against. A `CGContext` is wrapped around
/// the same memory, which gives the shape-drawing operations the original got
/// from `BufferedImage.createGraphics()` (the digger, basher, miner, bridger and
/// exploder all carve terrain with filled rects and ovals).
final class Bitmap {

  let width: Int
  let height: Int

  private let pixels: UnsafeMutablePointer<UInt32>
  let context: CGContext

  private var cachedImage: CGImage?

  init(width: Int, height: Int) {
    precondition(width > 0 && height > 0)
    self.width = width
    self.height = height
    self.pixels = .allocate(capacity: width * height)
    self.pixels.initialize(repeating: 0, count: width * height)

    // byteOrder32Little + premultipliedFirst puts the bytes down as B,G,R,A,
    // which read back as a little-endian 0xAARRGGBB word.
    guard
      let context = CGContext(
        data: pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
          | CGBitmapInfo.byteOrder32Little.rawValue)
    else {
      fatalError("Could not create a \(width)x\(height) bitmap context")
    }
    self.context = context
    context.interpolationQuality = .none
  }

  convenience init?(contentsOf url: URL) {
    guard
      let image = NSImage(contentsOf: url),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { return nil }

    self.init(width: cgImage.width, height: cgImage.height)
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
  }

  deinit {
    pixels.deallocate()
  }

  /// Reads a pixel, clamping to the edge rather than trapping.
  ///
  /// The Java original indexed straight into the raster and threw
  /// `ArrayIndexOutOfBoundsException` the moment a lemming reached the edge of
  /// the level, which killed the animation thread outright. Every level mask is
  /// bordered in green (indestructible), so clamping makes the border behave
  /// like the wall it looks like.
  @inline(__always)
  func getRGB(_ x: Int, _ y: Int) -> UInt32 {
    let cx = min(max(x, 0), width - 1)
    let cy = min(max(y, 0), height - 1)
    return pixels[cy * width + cx]
  }

  /// Writes a pixel, discarding writes that fall outside the image.
  @inline(__always)
  func setRGB(_ x: Int, _ y: Int, _ argb: UInt32) {
    guard x >= 0, x < width, y >= 0, y < height else { return }
    pixels[y * width + x] = argb
    cachedImage = nil
  }

  /// Fills a vertical run in one call.
  ///
  /// The raycaster draws the world as several hundred vertical strips a frame;
  /// going through `setRGB` per pixel would mean a bounds check and a cache
  /// invalidation on every one of a hundred thousand writes.
  func fillColumn(_ x: Int, from y0: Int, to y1: Int, _ argb: UInt32) {
    guard x >= 0, x < width else { return }
    let top = max(y0, 0)
    let bottom = min(y1, height - 1)
    guard top <= bottom else { return }
    var index = top * width + x
    for _ in top...bottom {
      pixels[index] = argb
      index += width
    }
    cachedImage = nil
  }

  /// Fills a horizontal run in one call.
  func fillRow(_ y: Int, from x0: Int, to x1: Int, _ argb: UInt32) {
    guard y >= 0, y < height else { return }
    let left = max(x0, 0)
    let right = min(x1, width - 1)
    guard left <= right else { return }
    let base = y * width
    for x in left...right {
      pixels[base + x] = argb
    }
    cachedImage = nil
  }

  /// A `Graphics` that draws into this bitmap, in top-left-origin coordinates.
  func createGraphics() -> Graphics {
    Graphics(context: context, logicalHeight: CGFloat(height)) { [weak self] in
      self?.cachedImage = nil
    }
  }

  /// A snapshot for drawing on screen, cached until the pixels change.
  var cgImage: CGImage {
    if let cachedImage { return cachedImage }
    guard let image = context.makeImage() else {
      fatalError("Could not snapshot a \(width)x\(height) bitmap")
    }
    cachedImage = image
    return image
  }

  /// Invalidates the snapshot cache after drawing through `context` directly.
  func invalidate() {
    cachedImage = nil
  }
}
