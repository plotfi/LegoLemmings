import CoreGraphics

extension Canvas {

  /// Paints the theme's surface stripe onto every exposed terrain edge.
  ///
  /// Running this as a pass over the finished mask means grass, snow or sand
  /// shows up on carved ledges and tunnel floors too, not just on the tops of
  /// the rectangles that were placed by hand.
  func applySurfaceStripe(material: Material, color: RGB, depth: Int) {
    let target = material.maskColor
    let targetKey = UInt32(target.r << 16 | target.g << 8 | target.b)
    let air: UInt32 = 0x000000

    for x in 0..<width {
      var y = 1
      while y < height {
        if maskColor(atX: x, y: y) == targetKey && maskColor(atX: x, y: y - 1) == air {
          var d = 0
          while d < depth && y + d < height && maskColor(atX: x, y: y + d) == targetKey {
            decorate(x, y + d, 1, 1, color)
            d += 1
          }
          y += max(d, 1)
        } else {
          y += 1
        }
      }
    }
  }

  /// A one-pixel highlight under every overhang, which reads as depth.
  func applyUnderShadow(material: Material, color: RGB, depth: Int) {
    let target = material.maskColor
    let targetKey = UInt32(target.r << 16 | target.g << 8 | target.b)
    let air: UInt32 = 0x000000

    for x in 0..<width {
      var y = 0
      while y < height - 1 {
        if maskColor(atX: x, y: y) == targetKey && maskColor(atX: x, y: y + 1) == air {
          for d in 0..<depth where y - d >= 0 && maskColor(atX: x, y: y - d) == targetKey {
            decorate(x, y - d, 1, 1, color)
          }
          y += max(depth, 1)
        } else {
          y += 1
        }
      }
    }
  }

  /// Scatters flecks across one material, so large fills do not read as flat.
  func speckle(material: Material, _ rng: inout RNG, colors: [RGB], count: Int) {
    let target = material.maskColor
    let targetKey = UInt32(target.r << 16 | target.g << 8 | target.b)
    for _ in 0..<count {
      let x = rng.int(0, width - 1)
      let y = rng.int(0, height - 1)
      guard maskColor(atX: x, y: y) == targetKey else { continue }
      let size = rng.int(2, 6)
      decorate(x, y, size, size, rng.pick(colors))
    }
  }

  /// Vertical sky gradient, flat below `fadeTo` so that the color the digging
  /// code samples at (200, 200) matches the sky everywhere terrain is carved.
  func skyGradient(top: RGB, bottom: RGB, fadeTo: Int) {
    for y in 0..<height {
      let t = min(Double(y) / Double(fadeTo), 1.0)
      decorate(0, y, width, 1, top.mix(bottom, t))
    }
  }

  /// Repaints a small patch of flat sky over the pixel the engine samples for
  /// its "erase" color, so a stray star or bubble landing there cannot turn
  /// every dug tunnel that color. Invisible, because the sky is flat by then.
  func stampSkySample(color: RGB) {
    decorate(194, 194, 13, 13, color)
  }
}
