import CoreGraphics

/// Art-only props. None of these touch the mask, so they are pure scenery: the
/// engine cannot see them and lemmings walk straight through.
enum Decor {

  static func stars(_ c: Canvas, _ rng: inout RNG, count: Int, maxY: Int, color: RGB) {
    for _ in 0..<count {
      let x = rng.int(30, c.width - 30)
      let y = rng.int(30, maxY)
      let size = rng.chance(0.2) ? 3 : 2
      c.decorate(x, y, size, size, color)
    }
  }

  static func moon(_ c: Canvas, x: Int, y: Int, radius: Int, color: RGB, shadow: RGB) {
    c.decorateEllipse(x - radius, y - radius, radius * 2, radius * 2, color)
    c.decorateEllipse(x - radius / 2, y - radius, radius * 2, radius * 2, shadow)
  }

  static func sun(_ c: Canvas, x: Int, y: Int, radius: Int, color: RGB) {
    c.decorateEllipse(x - radius, y - radius, radius * 2, radius * 2, color)
  }

  static func clouds(_ c: Canvas, _ rng: inout RNG, count: Int, maxY: Int, color: RGB) {
    for _ in 0..<count {
      let x = rng.int(60, c.width - 200)
      let y = rng.int(40, maxY)
      let w = rng.int(90, 170)
      let h = rng.int(22, 34)
      c.decorateEllipse(x, y, w, h, color)
      c.decorateEllipse(x + w / 4, y - h / 2, w / 2, h, color)
    }
  }

  /// Horizontal mortar lines, for stone and brick.
  static func brickwork(_ c: Canvas, x0: Int, y0: Int, x1: Int, y1: Int, color: RGB, step: Int) {
    var y = y0
    var row = 0
    while y < y1 {
      c.decorate(x0, y, x1 - x0, 1, color)
      var x = x0 + (row % 2 == 0 ? 0 : step / 2)
      while x < x1 {
        c.decorate(x, y, 1, step, color)
        x += step
      }
      y += step
      row += 1
    }
  }

  /// Vertical seams, for wooden planking.
  static func planks(_ c: Canvas, x0: Int, y0: Int, x1: Int, y1: Int, color: RGB, step: Int) {
    var x = x0
    while x < x1 {
      c.decorate(x, y0, 1, y1 - y0, color)
      x += step
    }
  }

  static func bubbles(_ c: Canvas, _ rng: inout RNG, count: Int, color: RGB) {
    for _ in 0..<count {
      let x = rng.int(40, c.width - 40)
      let y = rng.int(40, c.height - 60)
      let size = rng.int(4, 11)
      c.decorateEllipse(x, y, size, size, color)
    }
  }

  static func embers(_ c: Canvas, _ rng: inout RNG, count: Int, colors: [RGB]) {
    for _ in 0..<count {
      let x = rng.int(40, c.width - 40)
      let y = rng.int(40, c.height - 60)
      let size = rng.int(2, 5)
      c.decorate(x, y, size, size, rng.pick(colors))
    }
  }

  static func palmTree(_ c: Canvas, x: Int, groundY: Int, height: Int, trunk: RGB, leaf: RGB) {
    c.decorate(x, groundY - height, 9, height, trunk)
    for i in 0..<5 {
      let spread = 46 - i * 4
      let lift = i * 7
      c.decoratePolygon(
        [
          (x + 4, groundY - height),
          (x + 4 - spread, groundY - height + 14 + lift),
          (x + 4 - spread / 2, groundY - height + 4 + lift),
        ], leaf)
      c.decoratePolygon(
        [
          (x + 5, groundY - height),
          (x + 5 + spread, groundY - height + 14 + lift),
          (x + 5 + spread / 2, groundY - height + 4 + lift),
        ], leaf)
    }
  }

  static func pineTree(_ c: Canvas, x: Int, groundY: Int, height: Int, trunk: RGB, leaf: RGB) {
    c.decorate(x - 4, groundY - height / 4, 8, height / 4, trunk)
    for tier in 0..<3 {
      let w = 46 - tier * 12
      let y = groundY - height + (height * tier) / 4
      c.decoratePolygon([(x, y), (x - w / 2, y + height / 3), (x + w / 2, y + height / 3)], leaf)
    }
  }

  static func cactus(_ c: Canvas, x: Int, groundY: Int, height: Int, color: RGB) {
    c.decorate(x, groundY - height, 14, height, color)
    c.decorate(x - 14, groundY - height + 22, 14, 9, color)
    c.decorate(x - 14, groundY - height + 22, 9, 34, color)
    c.decorate(x + 14, groundY - height + 40, 14, 9, color)
    c.decorate(x + 19, groundY - height + 16, 9, 33, color)
  }

  static func gravestone(_ c: Canvas, x: Int, groundY: Int, color: RGB, shade: RGB) {
    c.decorate(x, groundY - 44, 30, 44, color)
    c.decorateEllipse(x, groundY - 58, 30, 30, color)
    c.decorate(x + 13, groundY - 40, 4, 22, shade)
    c.decorate(x + 7, groundY - 32, 16, 4, shade)
  }

  static func gear(_ c: Canvas, x: Int, y: Int, radius: Int, color: RGB, hub: RGB) {
    c.decorateEllipse(x - radius, y - radius, radius * 2, radius * 2, color)
    for tooth in 0..<8 {
      let angle = Double(tooth) * .pi / 4
      let tx = x + Int(cos(angle) * Double(radius))
      let ty = y + Int(sin(angle) * Double(radius))
      c.decorate(tx - 5, ty - 5, 10, 10, color)
    }
    c.decorateEllipse(x - radius / 3, y - radius / 3, radius * 2 / 3, radius * 2 / 3, hub)
  }

  static func pipes(_ c: Canvas, _ rng: inout RNG, count: Int, color: RGB, shade: RGB) {
    for _ in 0..<count {
      let x = rng.int(60, c.width - 120)
      let y = rng.int(60, 300)
      let length = rng.int(90, 220)
      if rng.chance(0.5) {
        c.decorate(x, y, length, 16, color)
        c.decorate(x, y, length, 4, shade)
      } else {
        c.decorate(x, y, 16, length, color)
        c.decorate(x, y, 4, length, shade)
      }
    }
  }

  static func banner(_ c: Canvas, x: Int, y: Int, height: Int, cloth: RGB, pole: RGB) {
    c.decorate(x, y, 4, height, pole)
    c.decoratePolygon(
      [(x + 4, y), (x + 40, y), (x + 40, y + 34), (x + 22, y + 26), (x + 4, y + 34)], cloth)
  }

  static func ladder(_ c: Canvas, x: Int, y0: Int, y1: Int, color: RGB) {
    c.decorate(x, y0, 4, y1 - y0, color)
    c.decorate(x + 26, y0, 4, y1 - y0, color)
    var y = y0 + 8
    while y < y1 {
      c.decorate(x, y, 30, 3, color)
      y += 16
    }
  }

  static func snowfall(_ c: Canvas, _ rng: inout RNG, count: Int, color: RGB) {
    for _ in 0..<count {
      let x = rng.int(30, c.width - 30)
      let y = rng.int(30, c.height - 60)
      c.decorate(x, y, 3, 3, color)
    }
  }

  /// A simple mountain range along the back.
  static func ridgeline(_ c: Canvas, _ rng: inout RNG, baseY: Int, color: RGB, peaks: Int) {
    var x = 0
    for _ in 0..<peaks {
      let w = rng.int(140, 280)
      let h = rng.int(70, 180)
      c.decoratePolygon([(x, baseY), (x + w / 2, baseY - h), (x + w, baseY)], color)
      x += w - rng.int(30, 70)
      if x > c.width { break }
    }
  }
}
