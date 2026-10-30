import CoreGraphics

/// A level's look: the palette the terrain is painted in, plus the scenery
/// drawn behind and in front of it.
struct Theme {
  var file: String
  var title: String

  var sky: RGB
  /// Sky color at the horizon, if the sky should fade.
  var skyHorizon: RGB?

  var dirt: RGB
  /// The stripe painted on every exposed dirt surface — grass, sand, snow.
  var dirtTop: RGB
  var rock: RGB
  var rockEdge: RGB
  var hazard: RGB
  var hazardTop: RGB
  var doorway: RGB
  var doorFrame: RGB

  /// Drawn before the terrain, so terrain covers it. `groundY` is the level's
  /// floor line, for standing props on.
  var backdrop: (Canvas, inout RNG, Theme, Int) -> Void = { _, _, _, _ in }
  /// Drawn after the terrain — keep it light, it sits over everything.
  var overlay: (Canvas, inout RNG, Theme, Int) -> Void = { _, _, _, _ in }
}

enum Themes {

  /// The ground line every backdrop is drawn against. The generator shifts the
  /// scenery so this lands on wherever the level's floor actually ended up.
  static let nominalGround = 470


  static let all: [Theme] = [
    pirates, space, castle, western, arctic, jungle,
    aquazone, dino, pharaoh, city, ninja, train,
    volcano, factory, haunted, mars,
  ]

  // MARK: - Shipwreck Cove

  static let pirates = Theme(
    file: "pirates", title: "Shipwreck Cove",
    sky: RGB(0x7EC8E3), skyHorizon: RGB(0xCFEAF2),
    dirt: RGB(0xC2A06B), dirtTop: RGB(0xE6CE94),
    rock: RGB(0x6B5B4A), rockEdge: RGB(0x8A7760),
    hazard: RGB(0x1C5FA8), hazardTop: RGB(0x4E8FD0),
    doorway: RGB(0x2A1A0E), doorFrame: RGB(0x8A6A3A),
    backdrop: { c, rng, t, groundY in
      Decor.clouds(c, &rng, count: 5, maxY: 150, color: RGB(0xFFFFFF))
      Decor.sun(c, x: 1020, y: 110, radius: 54, color: RGB(0xFFF2B0))
      // A wrecked hull leaning on the horizon.
      let hx = 150, hy = 430
      c.decoratePolygon(
        [(hx, hy), (hx + 250, hy), (hx + 215, hy + 70), (hx + 40, hy + 70)], RGB(0x5A4328))
      c.decorate(hx + 110, hy - 150, 11, 150, RGB(0x6B5030))
      c.decoratePolygon(
        [(hx + 121, hy - 145), (hx + 215, hy - 95), (hx + 121, hy - 45)], RGB(0xEDE3CC))
      Decor.palmTree(c, x: 930, groundY: 470, height: 120, trunk: RGB(0x7A5A32), leaf: RGB(0x3C8C46))
      Decor.palmTree(c, x: 1010, groundY: 480, height: 90, trunk: RGB(0x7A5A32), leaf: RGB(0x349040))
    })

  // MARK: - Lunar Outpost

  static let space = Theme(
    file: "space", title: "Lunar Outpost",
    sky: RGB(0x080818), skyHorizon: RGB(0x1A1A38),
    dirt: RGB(0x9A9AA8), dirtTop: RGB(0xCCCCD8),
    rock: RGB(0x45455A), rockEdge: RGB(0x6A6A86),
    hazard: RGB(0x2EE86A), hazardTop: RGB(0x9CFFBE),
    doorway: RGB(0x0A0A14), doorFrame: RGB(0x6AD8FF),
    backdrop: { c, rng, t, groundY in
      Decor.stars(c, &rng, count: 220, maxY: 600, color: RGB(0xFFFFFF))
      Decor.stars(c, &rng, count: 60, maxY: 600, color: RGB(0x9AC8FF))
      // A ringed planet hanging over the site.
      c.decorateEllipse(820, 70, 230, 230, RGB(0x3A6AC8))
      c.decorateEllipse(860, 110, 90, 60, RGB(0x5A8AE0))
      c.decorateEllipse(950, 200, 60, 44, RGB(0x2A5AA8))
      c.decorate(760, 172, 350, 7, RGB(0xC8B88A))
      c.decorate(770, 190, 330, 4, RGB(0x9A8A6A))
    },
    overlay: { c, rng, t, groundY in
      Decor.stars(c, &rng, count: 25, maxY: 200, color: RGB(0xFFFFFF))
    })

  // MARK: - Dragon Keep

  static let castle = Theme(
    file: "castle", title: "Dragon Keep",
    sky: RGB(0x6FA8DC), skyHorizon: RGB(0xB8D8F0),
    dirt: RGB(0x8B7355), dirtTop: RGB(0x4E8C3A),
    rock: RGB(0x8C8C8C), rockEdge: RGB(0xAEAEAE),
    hazard: RGB(0x2E5F8A), hazardTop: RGB(0x5A92BE),
    doorway: RGB(0x1A1410), doorFrame: RGB(0x6A6A6A),
    backdrop: { c, rng, t, groundY in
      Decor.clouds(c, &rng, count: 4, maxY: 130, color: RGB(0xEAF4FF))
      // A keep with crenellations and a banner.
      let kx = 760, ky = 180
      c.decorate(kx, ky, 200, 290, RGB(0x6E6E7A))
      for i in 0..<7 {
        c.decorate(kx + i * 29, ky - 22, 18, 22, RGB(0x6E6E7A))
      }
      c.decorate(kx + 60, ky + 60, 30, 46, RGB(0x2A2A32))
      c.decorate(kx + 120, ky + 60, 30, 46, RGB(0x2A2A32))
      Decor.brickwork(c, x0: kx, y0: ky, x1: kx + 200, y1: ky + 290, color: RGB(0x5A5A66), step: 26)
      Decor.banner(c, x: kx + 215, y: ky - 40, height: 120, cloth: RGB(0xC83A3A), pole: RGB(0x4A4A4A))
      Decor.ridgeline(c, &rng, baseY: 300, color: RGB(0x5A7A9A), peaks: 5)
    })

  // MARK: - Gold Gulch

  static let western = Theme(
    file: "western", title: "Gold Gulch",
    sky: RGB(0xF2C14E), skyHorizon: RGB(0xF7E0A8),
    dirt: RGB(0xC96F3A), dirtTop: RGB(0xE09355),
    rock: RGB(0x7A4A2A), rockEdge: RGB(0x9A6A42),
    hazard: RGB(0x6B4A1A), hazardTop: RGB(0x8E6A2E),
    doorway: RGB(0x2A1A0A), doorFrame: RGB(0x8A5A2A),
    backdrop: { c, rng, t, groundY in
      Decor.sun(c, x: 240, y: 130, radius: 70, color: RGB(0xFFE9A8))
      Decor.ridgeline(c, &rng, baseY: 330, color: RGB(0xB06038), peaks: 6)
      Decor.ridgeline(c, &rng, baseY: 360, color: RGB(0x8E4A2E), peaks: 4)
      Decor.cactus(c, x: 620, groundY: 360, height: 96, color: RGB(0x3A7A3A))
      Decor.cactus(c, x: 1060, groundY: 350, height: 78, color: RGB(0x357035))
    })

  // MARK: - Frozen Floe

  static let arctic = Theme(
    file: "arctic", title: "Frozen Floe",
    sky: RGB(0xBFE8F5), skyHorizon: RGB(0xEAF9FF),
    dirt: RGB(0xD6EEF6), dirtTop: RGB(0xFFFFFF),
    rock: RGB(0x7FAEC4), rockEdge: RGB(0xA8CFE0),
    hazard: RGB(0x19497A), hazardTop: RGB(0x3E7FB8),
    doorway: RGB(0x123048), doorFrame: RGB(0x6FC8E8),
    backdrop: { c, rng, t, groundY in
      Decor.ridgeline(c, &rng, baseY: 340, color: RGB(0xA8D4E8), peaks: 6)
      Decor.ridgeline(c, &rng, baseY: 380, color: RGB(0x8ABEDA), peaks: 4)
      Decor.pineTree(c, x: 180, groundY: 390, height: 130, trunk: RGB(0x5A4030), leaf: RGB(0x2A6A4A))
      Decor.pineTree(c, x: 250, groundY: 395, height: 100, trunk: RGB(0x5A4030), leaf: RGB(0x256044))
    },
    overlay: { c, rng, t, groundY in
      Decor.snowfall(c, &rng, count: 260, color: RGB(0xFFFFFF))
    })

  // MARK: - Temple Ruins

  static let jungle = Theme(
    file: "jungle", title: "Temple Ruins",
    sky: RGB(0x8FD6A8), skyHorizon: RGB(0xCDEFD6),
    dirt: RGB(0x6B4A2A), dirtTop: RGB(0x3A8C3A),
    rock: RGB(0x9A9A7A), rockEdge: RGB(0xBABA9A),
    hazard: RGB(0x3A6A24), hazardTop: RGB(0x5E9440),
    doorway: RGB(0x14200E), doorFrame: RGB(0x8A8A6A),
    backdrop: { c, rng, t, groundY in
      // A stepped temple back in the haze.
      let tx = 480, ty = 420
      for tier in 0..<5 {
        let w = 300 - tier * 50
        c.decorate(tx + tier * 25, ty - tier * 42, w, 42, RGB(0x7E8E6E))
      }
      c.decorate(tx + 130, ty - 210, 40, 46, RGB(0x4A5A3A))
      Decor.palmTree(c, x: 160, groundY: 430, height: 140, trunk: RGB(0x5A4028), leaf: RGB(0x2E7A38))
      Decor.palmTree(c, x: 1050, groundY: 440, height: 115, trunk: RGB(0x5A4028), leaf: RGB(0x2A6E34))
    })

  // MARK: - Coral Deep

  static let aquazone = Theme(
    file: "aquazone", title: "Coral Deep",
    sky: RGB(0x1A7AAE), skyHorizon: RGB(0x0E4C78),
    dirt: RGB(0xD4A88A), dirtTop: RGB(0xEFCFAE),
    rock: RGB(0x4A7A8A), rockEdge: RGB(0x6EA0B0),
    hazard: RGB(0x0A1A2E), hazardTop: RGB(0x1E3A5E),
    doorway: RGB(0x05101E), doorFrame: RGB(0x3ADCD0),
    backdrop: { c, rng, t, groundY in
      // Light shafts coming down through the water.
      for i in 0..<7 {
        let x = 60 + i * 170
        c.decoratePolygon([(x, 0), (x + 60, 0), (x + 130, 520), (x + 50, 520)], RGB(0x2E92C2))
      }
      for _ in 0..<16 {
        let x = rng.int(60, 1100)
        let y = rng.int(330, 470)
        let h = rng.int(40, 90)
        c.decorate(x, y, 13, h, RGB(0xD85A8A))
        c.decorate(x - 15, y + 18, 13, h - 24, RGB(0xC84A7A))
        c.decorate(x + 15, y + 12, 13, h - 18, RGB(0xE86A9A))
      }
    },
    overlay: { c, rng, t, groundY in
      Decor.bubbles(c, &rng, count: 90, color: RGB(0x7FD8F0))
    })

  // MARK: - Raptor Valley

  static let dino = Theme(
    file: "dino", title: "Raptor Valley",
    sky: RGB(0xA8D8E8), skyHorizon: RGB(0xDCF0F6),
    dirt: RGB(0x6E7A3A), dirtTop: RGB(0x87A33E),
    rock: RGB(0x7A6A5A), rockEdge: RGB(0x9A8A76),
    hazard: RGB(0xD9461A), hazardTop: RGB(0xF2843A),
    doorway: RGB(0x1E1608), doorFrame: RGB(0x8A7A4A),
    backdrop: { c, rng, t, groundY in
      Decor.ridgeline(c, &rng, baseY: 360, color: RGB(0x6E8A6A), peaks: 5)
      // A smoking cone off to one side.
      c.decoratePolygon([(840, 400), (990, 150), (1140, 400)], RGB(0x5A5A4A))
      c.decoratePolygon([(950, 220), (990, 150), (1030, 220)], RGB(0xD9461A))
      for i in 0..<5 {
        c.decorateEllipse(960 + i * 14, 120 - i * 26, 60 + i * 12, 40 + i * 8, RGB(0x8A8A8A))
      }
      Decor.palmTree(c, x: 210, groundY: 420, height: 150, trunk: RGB(0x5A4028), leaf: RGB(0x3E8C4A))
    })

  // MARK: - Scarab Tomb

  static let pharaoh = Theme(
    file: "pharaoh", title: "Scarab Tomb",
    sky: RGB(0xF2D9A0), skyHorizon: RGB(0xF9EDCE),
    dirt: RGB(0xD9B870), dirtTop: RGB(0xEDD79A),
    rock: RGB(0xB2975A), rockEdge: RGB(0xD0B87E),
    hazard: RGB(0x2E2216), hazardTop: RGB(0x53402C),
    doorway: RGB(0x120C06), doorFrame: RGB(0xD8B33A),
    backdrop: { c, rng, t, groundY in
      Decor.sun(c, x: 980, y: 120, radius: 64, color: RGB(0xFFF4C8))
      c.decoratePolygon([(150, 420), (330, 150), (510, 420)], RGB(0xCFAF72))
      c.decoratePolygon([(330, 150), (510, 420), (330, 420)], RGB(0xB8995E))
      c.decoratePolygon([(430, 430), (540, 265), (650, 430)], RGB(0xC7A76A))
      c.decoratePolygon([(540, 265), (650, 430), (540, 430)], RGB(0xAF9156))
    })

  // MARK: - Downtown Blaze

  static let city = Theme(
    file: "city", title: "Downtown Blaze",
    sky: RGB(0x8FC4E2), skyHorizon: RGB(0xD2E8F4),
    dirt: RGB(0xB4B4B8), dirtTop: RGB(0x8A8A90),
    rock: RGB(0x55555F), rockEdge: RGB(0x76768A),
    hazard: RGB(0xE8561A), hazardTop: RGB(0xF9A03A),
    doorway: RGB(0x14141A), doorFrame: RGB(0xE8C23A),
    backdrop: { c, rng, t, groundY in
      // A skyline with lit windows.
      var x = 40
      while x < 1160 {
        let w = rng.int(70, 130)
        let h = rng.int(140, 330)
        let top = 470 - h
        c.decorate(x, top, w, h, RGB(0x6E8296))
        var wy = top + 14
        while wy < 460 {
          var wx = x + 10
          while wx < x + w - 12 {
            c.decorate(wx, wy, 11, 14, rng.chance(0.4) ? RGB(0xFFE08A) : RGB(0x4E6276))
            wx += 22
          }
          wy += 26
        }
        x += w + rng.int(8, 26)
      }
    })

  // MARK: - Shadow Dojo

  static let ninja = Theme(
    file: "ninja", title: "Shadow Dojo",
    sky: RGB(0x2A1A3E), skyHorizon: RGB(0x5A3A6A),
    dirt: RGB(0x4A3A2A), dirtTop: RGB(0x7A4A36),
    rock: RGB(0x33333F), rockEdge: RGB(0x52526A),
    hazard: RGB(0xC33A3A), hazardTop: RGB(0xE86A5A),
    doorway: RGB(0x0E0A14), doorFrame: RGB(0xD8A33A),
    backdrop: { c, rng, t, groundY in
      Decor.moon(c, x: 300, y: 150, radius: 80, color: RGB(0xF6E8C8), shadow: RGB(0x2A1A3E))
      Decor.stars(c, &rng, count: 120, maxY: 420, color: RGB(0xE8D8F0))
      // A pagoda silhouette.
      let px = 820
      for tier in 0..<4 {
        let w = 230 - tier * 44
        let y = 430 - tier * 80
        c.decoratePolygon(
          [(px - w / 2 - 26, y), (px + w / 2 + 26, y), (px + w / 2, y - 26), (px - w / 2, y - 26)],
          RGB(0x1A1424))
        c.decorate(px - w / 2 + 14, y - 74, w - 28, 48, RGB(0x241A2E))
      }
      for _ in 0..<9 {
        let bx = rng.int(60, 700)
        c.decorate(bx, rng.int(300, 460), 7, rng.int(90, 180), RGB(0x2E4A32))
      }
    })

  // MARK: - Iron Trestle

  static let train = Theme(
    file: "train", title: "Iron Trestle",
    sky: RGB(0xC2D6E6), skyHorizon: RGB(0xE6F0F7),
    dirt: RGB(0x7A6A58), dirtTop: RGB(0x9C8C76),
    rock: RGB(0x45454A), rockEdge: RGB(0x6A6A72),
    hazard: RGB(0x3A6A8A), hazardTop: RGB(0x6A9ABA),
    doorway: RGB(0x14181C), doorFrame: RGB(0xB24A2A),
    backdrop: { c, rng, t, groundY in
      Decor.clouds(c, &rng, count: 5, maxY: 160, color: RGB(0xFFFFFF))
      Decor.ridgeline(c, &rng, baseY: 400, color: RGB(0x8A9AAA), peaks: 5)
      // A trestle bridge receding into the back.
      c.decorate(120, 330, 960, 16, RGB(0x5A4A3A))
      for i in 0..<11 {
        let x = 140 + i * 90
        c.decorate(x, 346, 13, 130, RGB(0x5A4A3A))
        c.decoratePolygon([(x, 476), (x + 80, 346), (x + 88, 346)], RGB(0x5A4A3A))
      }
    })

  // MARK: - Magma Core

  static let volcano = Theme(
    file: "volcano", title: "Magma Core",
    sky: RGB(0x3A1612), skyHorizon: RGB(0x7A2A14),
    dirt: RGB(0x4E2A24), dirtTop: RGB(0x7A3A26),
    rock: RGB(0x241414), rockEdge: RGB(0x4A2E2E),
    hazard: RGB(0xFF6A14), hazardTop: RGB(0xFFC24A),
    doorway: RGB(0x0A0404), doorFrame: RGB(0xFFA23A),
    backdrop: { c, rng, t, groundY in
      for i in 0..<9 {
        c.decorate(0, 90 + i * 40, 1200, 20, RGB(0x5A1E14).mix(RGB(0x8A3A1A), Double(i) / 9))
      }
      c.decoratePolygon([(300, 470), (520, 120), (740, 470)], RGB(0x2A1614))
      c.decoratePolygon([(470, 190), (520, 120), (570, 190)], RGB(0xFF8A2A))
    },
    overlay: { c, rng, t, groundY in
      Decor.embers(c, &rng, count: 150, colors: [RGB(0xFFC24A), RGB(0xFF7A2A), RGB(0xFFE88A)])
    })

  // MARK: - Gear Works

  static let factory = Theme(
    file: "factory", title: "Gear Works",
    sky: RGB(0x56687A), skyHorizon: RGB(0x8A9AAA),
    dirt: RGB(0x7A7A66), dirtTop: RGB(0x9E9E86),
    rock: RGB(0x42525A), rockEdge: RGB(0x64767E),
    hazard: RGB(0xAEE839), hazardTop: RGB(0xD8FF7A),
    doorway: RGB(0x10161A), doorFrame: RGB(0xE8A23A),
    backdrop: { c, rng, t, groundY in
      Decor.gear(c, x: 240, y: 200, radius: 86, color: RGB(0x4A5A64), hub: RGB(0x36424A))
      Decor.gear(c, x: 400, y: 300, radius: 58, color: RGB(0x44545E), hub: RGB(0x323E46))
      Decor.gear(c, x: 960, y: 170, radius: 104, color: RGB(0x4A5A64), hub: RGB(0x36424A))
      Decor.pipes(c, &rng, count: 12, color: RGB(0x5A6A74), shade: RGB(0x7E8E98))
      for i in 0..<5 {
        c.decorate(700 + i * 60, 60, 34, 300, RGB(0x4E5E68))
      }
    })

  // MARK: - Crypt Hollow

  static let haunted = Theme(
    file: "haunted", title: "Crypt Hollow",
    sky: RGB(0x161628), skyHorizon: RGB(0x30304E),
    dirt: RGB(0x3A3A4A), dirtTop: RGB(0x4E4E64),
    rock: RGB(0x66667A), rockEdge: RGB(0x8A8A9E),
    hazard: RGB(0x56E856), hazardTop: RGB(0x9CFF9C),
    doorway: RGB(0x08080E), doorFrame: RGB(0x8ADC8A),
    backdrop: { c, rng, t, groundY in
      Decor.moon(c, x: 940, y: 140, radius: 76, color: RGB(0xE4E4D0), shadow: RGB(0x161628))
      Decor.stars(c, &rng, count: 150, maxY: 480, color: RGB(0xBEBED8))
      // Bare trees and a crooked fence.
      for _ in 0..<5 {
        let x = rng.int(80, 1100)
        let y = rng.int(380, 460)
        c.decorate(x, y - 130, 11, 130, RGB(0x241C24))
        c.decoratePolygon([(x + 5, y - 110), (x - 50, y - 160), (x - 44, y - 150)], RGB(0x241C24))
        c.decoratePolygon([(x + 6, y - 120), (x + 60, y - 172), (x + 54, y - 162)], RGB(0x241C24))
      }
      for i in 0..<16 {
        Decor.gravestone(
          c, x: 60 + i * 74 + rng.int(-10, 10), groundY: 470, color: RGB(0x4A4A5A),
          shade: RGB(0x32323E))
      }
    },
    overlay: { c, rng, t, groundY in
      // Drifting wisps.
      for _ in 0..<22 {
        let x = rng.int(60, 1120)
        let y = rng.int(80, 560)
        c.decorateEllipse(x, y, rng.int(8, 18), rng.int(6, 12), RGB(0x6AE89A))
      }
    })

  // MARK: - Red Frontier

  static let mars = Theme(
    file: "mars", title: "Red Frontier",
    sky: RGB(0xE09A6A), skyHorizon: RGB(0xF2CBA8),
    dirt: RGB(0xB2503A), dirtTop: RGB(0xC9694A),
    rock: RGB(0x6E3226), rockEdge: RGB(0x90503C),
    hazard: RGB(0x3A8A9A), hazardTop: RGB(0x6EC0CE),
    doorway: RGB(0x1A0C08), doorFrame: RGB(0xE8E8F0),
    backdrop: { c, rng, t, groundY in
      Decor.ridgeline(c, &rng, baseY: 380, color: RGB(0xA05840), peaks: 6)
      // Two small moons and a habitat dome.
      c.decorateEllipse(220, 100, 54, 54, RGB(0xC8A890))
      c.decorateEllipse(330, 160, 30, 30, RGB(0xB09078))
      let dx = 820, dy = 400
      c.decorateEllipse(dx, dy - 90, 220, 180, RGB(0xCFD8E0))
      c.decorate(dx, dy, 220, 20, RGB(0x9AA4AE))
      c.decorateEllipse(dx + 70, dy - 60, 70, 60, RGB(0x7ABEE0))
      c.decorate(dx + 210, dy - 40, 120, 26, RGB(0xB8C2CC))
    })
}
