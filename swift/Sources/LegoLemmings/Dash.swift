import CoreGraphics
import Foundation

/// LEMMING DASH — a side-scroller built on the Lemmings assets.
///
/// The puzzle game watches a crowd from above and tells them what to do. This
/// plays one of them, from the side, at 60Hz: run, jump, and carve through the
/// level with the same abilities the crowd gets handed.
///
/// Everything here reads the same collision masks the puzzle game does — red
/// and green are solid, white kills, blue is the way out — so all twenty levels
/// are playable without touching a single asset. The terrain is destructible
/// for the same reason, which is the part a platformer almost never gets: if a
/// wall is in the way, dig through the floor or blow a hole in it.
final class Dash {

  // MARK: - Tuning

  /// How far in the level is magnified on screen. Higher means a closer, more
  /// side-scroller-ish view and more scrolling.
  static let zoom = 1.75
  static let hudHeight = 40

  /// The player's collision box, a little tighter than the 36x41 sprite so it
  /// fits through gaps that look like they should fit.
  static let boxW = 22
  static let boxH = 36
  /// Ledges up to this tall are walked up rather than bumped into.
  static let stepHeight = 8

  // Physics, in pixels per frame at 60Hz.
  static let gravity = 0.78
  static let maxFall = 15.0
  static let runAccel = 0.95
  static let runMax = 5.4
  static let groundFriction = 0.76
  static let airControl = 0.55
  static let jumpSpeed = -13.6
  /// Frames of grace after walking off a ledge during which a jump still works.
  static let coyoteFrames = 7
  /// Frames a jump pressed just before landing is remembered for.
  static let bufferFrames = 7

  static let digRadius = 15
  static let bashRadius = 16
  static let bombRadius = 30
  /// How hard a blast throws the player. This is the rocket jump.
  static let bombKick = 15.0

  // MARK: - Level

  private let chooser: LevelChooser
  private(set) var levelIndex: Int
  private var data: LevelData
  private var art: Bitmap
  private var mask: Bitmap

  // MARK: - Player

  /// Top-left of the collision box, in level pixels.
  private var px = 0.0
  private var py = 0.0
  private var vx = 0.0
  private var vy = 0.0
  private var onGround = false
  private var facingRight = true
  private var coyote = 0
  private var jumpBuffer = 0
  /// Armed while rising from a jump the player initiated. Only then may
  /// releasing the key cut the rise short — otherwise the same clamp would
  /// swallow every blast kick and every bounce, which is exactly what it did.
  private var jumpCutArmed = false
  private var animTick = 0
  private var digging = false
  private var bashing = false

  // MARK: - World

  private var camX = 0.0
  private var camY = 0.0
  private var bombs: [DashBomb] = []
  private var blasts: [Blast] = []
  /// The mindless crowd, still running the puzzle game's own movement code.
  private var horde: [Lemming] = []
  private var hordePhase = 0
  private var hordeTimer = 0

  // MARK: - Run state

  private var held: Set<GameKey> = []
  private(set) var deaths = 0
  private var frames = 0
  private var finished = false
  private var flash = 0
  /// Set when the player asks to leave; the controller reads it and goes back.
  private(set) var wantsOut = false

  // MARK: - Setup

  init(chooser: LevelChooser, levelIndex: Int) {
    self.chooser = chooser
    self.levelIndex = levelIndex
    self.data = chooser.levelData(levelIndex)
    self.art = Assets.bitmap("\(data.file).png")
    self.mask = Assets.bitmap("\(data.file)mask.png")
    respawn()
    snapCamera()
  }

  /// Loads another level, wrapping at either end.
  func load(levelOffset: Int) {
    levelIndex = (levelIndex + levelOffset + chooser.levelCount) % chooser.levelCount
    data = chooser.levelData(levelIndex)
    // Fresh copies: the level gets chewed up as it is played.
    art = Assets.bitmap("\(data.file).png")
    mask = Assets.bitmap("\(data.file)mask.png")
    bombs.removeAll()
    blasts.removeAll()
    horde.removeAll()
    deaths = 0
    frames = 0
    finished = false
    respawn()
    snapCamera()
  }

  private func respawn() {
    px = Double(data.start.x)
    py = Double(data.start.y)
    vx = 0
    vy = 0
    onGround = false
    digging = false
    bashing = false
  }

  // MARK: - Terrain

  private func isSolid(_ x: Int, _ y: Int) -> Bool {
    let color = mask.getRGB(x, y)
    return isColor(color, Mask.red) || isColor(color, Mask.green)
  }

  /// Samples a grid across the player's box. Sampling rather than testing every
  /// pixel is what keeps this cheap enough to run 16 times a frame per axis.
  private func boxTouches(_ x: Double, _ y: Double, _ test: (Int, Int) -> Bool) -> Bool {
    let x0 = Int(x)
    let y0 = Int(y)
    let x1 = x0 + Dash.boxW - 1
    let y1 = y0 + Dash.boxH - 1
    let columns = [x0, x0 + Dash.boxW / 3, x0 + 2 * Dash.boxW / 3, x1]
    let rows = [y0, y0 + Dash.boxH / 4, y0 + Dash.boxH / 2, y0 + 3 * Dash.boxH / 4, y1]
    for cx in columns {
      for cy in rows where test(cx, cy) { return true }
    }
    return false
  }

  private func boxHitsSolid(_ x: Double, _ y: Double) -> Bool {
    boxTouches(x, y) { isSolid($0, $1) }
  }

  private func boxTouchesColor(_ color: UInt32) -> Bool {
    boxTouches(px, py) { isColor(self.mask.getRGB($0, $1), color) }
  }

  /// Removes diggable earth in a circle. Rock, hazard and the exit survive, so
  /// the player can tunnel but cannot delete the level's frame.
  private func carve(atX x: Int, y: Int, radius: Int) {
    let sky = art.getRGB(200, 200)
    for dy in -radius...radius {
      let py = y + dy
      guard py >= 0, py < mask.height else { continue }
      let span = Int(Double(radius * radius - dy * dy).squareRoot())
      for dx in -span...span {
        let px = x + dx
        guard px >= 0, px < mask.width else { continue }
        if isColor(mask.getRGB(px, py), Mask.red) {
          mask.setRGB(px, py, Mask.black)
          art.setRGB(px, py, sky)
        }
      }
    }
  }

  // MARK: - Movement

  private func moveX(_ amount: Double) {
    guard amount != 0 else { return }
    let direction = amount > 0 ? 1.0 : -1.0
    var remaining = abs(amount)

    while remaining > 0 {
      let step = min(1.0, remaining)
      let next = px + direction * step
      if !boxHitsSolid(next, py) {
        px = next
      } else {
        // Walk up a small ledge rather than stopping dead at it — but only
        // when grounded, or the player could climb walls in mid-air.
        var climbed = false
        if onGround {
          for lift in 1...Dash.stepHeight where !boxHitsSolid(next, py - Double(lift)) {
            px = next
            py -= Double(lift)
            climbed = true
            break
          }
        }
        if !climbed {
          vx = 0
          return
        }
      }
      remaining -= step
    }
  }

  private func moveY(_ amount: Double) {
    guard amount != 0 else { return }
    let direction = amount > 0 ? 1.0 : -1.0
    var remaining = abs(amount)

    while remaining > 0 {
      let step = min(1.0, remaining)
      let next = py + direction * step
      if !boxHitsSolid(px, next) {
        py = next
      } else {
        if direction > 0 { onGround = true }
        vy = 0
        return
      }
      remaining -= step
    }
  }

  // MARK: - Frame

  func tick() {
    guard !finished else { return }
    frames += 1
    animTick += 1
    if flash > 0 { flash -= 1 }

    let left = held.contains(.left) || held.contains(.char("a"))
    let right = held.contains(.right) || held.contains(.char("d"))
    let wantsJump =
      held.contains(.char(" ")) || held.contains(.up) || held.contains(.char("w"))

    // Horizontal
    let control = onGround ? 1.0 : Dash.airControl
    if left && !right {
      vx -= Dash.runAccel * control
      facingRight = false
    } else if right && !left {
      vx += Dash.runAccel * control
      facingRight = true
    } else if onGround {
      vx *= Dash.groundFriction
      if abs(vx) < 0.2 { vx = 0 }
    }
    vx = min(max(vx, -Dash.runMax), Dash.runMax)

    // Jump, with a little forgiveness at both ends.
    if onGround { coyote = Dash.coyoteFrames } else if coyote > 0 { coyote -= 1 }
    if wantsJump { jumpBuffer = Dash.bufferFrames } else if jumpBuffer > 0 { jumpBuffer -= 1 }
    if jumpBuffer > 0 && coyote > 0 {
      vy = Dash.jumpSpeed
      onGround = false
      coyote = 0
      jumpBuffer = 0
      jumpCutArmed = true
    }
    // Releasing early cuts that jump short, so height is controllable.
    if jumpCutArmed && !wantsJump && vy < -4 {
      vy = -4
      jumpCutArmed = false
    }
    if vy >= 0 { jumpCutArmed = false }

    vy = min(vy + Dash.gravity, Dash.maxFall)

    onGround = false
    moveX(vx)
    moveY(vy)

    // Abilities, held down rather than clicked.
    digging = held.contains(.down) || held.contains(.char("s"))
    bashing = held.contains(.char("x"))
    if digging {
      carve(atX: Int(px) + Dash.boxW / 2, y: Int(py) + Dash.boxH + 6, radius: Dash.digRadius)
    }
    if bashing {
      let reach = facingRight ? Dash.boxW + 10 : -10
      carve(atX: Int(px) + reach, y: Int(py) + Dash.boxH / 2, radius: Dash.bashRadius)
    }

    updateBombs()
    updateHorde()
    stompCheck()

    // Hazards and the way out.
    if boxTouchesColor(Mask.white) { die() }
    if py > Double(mask.height) { die() }
    if boxTouchesColor(Mask.blue) { finished = true }

    followCamera()
  }

  private func die() {
    deaths += 1
    flash = 10
    respawn()
    snapCamera()
  }

  // MARK: - Bombs

  /// Lobs a bomb forward when running, or drops one at your feet when standing
  /// still. The second is the rocket jump: stand on the spot, drop one, and
  /// ride the blast. Without it there was no way to put a bomb under yourself.
  func throwBomb() {
    guard !finished, bombs.count < 6 else { return }
    let running = abs(vx) > 1.0
    bombs.append(
      DashBomb(
        x: px + Double(Dash.boxW) / 2,
        y: py + Double(Dash.boxH) / 2,
        vx: running ? (facingRight ? 7.0 : -7.0) + vx * 0.4 : 0,
        vy: running ? -6.0 : 1.5,
        fuse: running ? 70 : 26))
  }

  private func updateBombs() {
    var index = 0
    while index < bombs.count {
      let bomb = bombs[index]
      bomb.age += 1
      bomb.fuse -= 1
      bomb.vy = min(bomb.vy + Dash.gravity, Dash.maxFall)
      bomb.x += bomb.vx
      bomb.y += bomb.vy

      let hit = bomb.age > 2 && isSolid(Int(bomb.x), Int(bomb.y))
      let gone =
        bomb.x < 0 || bomb.x >= Double(mask.width) || bomb.y >= Double(mask.height)

      if hit || gone || bomb.fuse <= 0 {
        explode(atX: Int(bomb.x), y: Int(bomb.y))
        bombs.remove(at: index)
        continue
      }
      index += 1
    }

    for i in blasts.indices { blasts[i].life -= 1 }
    blasts.removeAll { $0.life <= 0 }
  }

  /// Blows a crater — and shoves the player. Standing next to your own bomb is
  /// the fastest way up a wall, which is the whole point of letting you carry
  /// them.
  private func explode(atX x: Int, y: Int) {
    carve(atX: x, y: y, radius: Dash.bombRadius)
    blasts.append(Blast(x: x, y: y, radius: Dash.bombRadius, life: Blast.duration))

    let cx = px + Double(Dash.boxW) / 2
    let cy = py + Double(Dash.boxH) / 2
    let dx = cx - Double(x)
    let dy = cy - Double(y)
    let distance = max((dx * dx + dy * dy).squareRoot(), 1)
    let reach = Double(Dash.bombRadius) * 2.4
    if distance < reach {
      let power = Dash.bombKick * (1 - distance / reach)
      vx += dx / distance * power
      vy += dy / distance * power
      vy = max(vy, -Dash.maxFall * 1.4)
      onGround = false
      // Not a jump, so releasing the jump key must not cut it short.
      jumpCutArmed = false
      debugLastKick = power
    }

    for lemming in horde where !lemming.dead && !lemming.dying {
      let lx = lemming.xPos + lemming.curImage.width / 2
      let ly = lemming.yPos + lemming.curImage.height / 2
      let ddx = lx - x
      let ddy = ly - y
      if ddx * ddx + ddy * ddy <= (Dash.bombRadius + 8) * (Dash.bombRadius + 8) {
        lemming.dying = true
      }
    }
  }

  // MARK: - The crowd

  /// The puzzle game's lemmings, wandering the same level. They run on their
  /// own 10Hz movement code, so they are stepped once every sixth frame.
  private func updateHorde() {
    hordeTimer += 1
    if hordeTimer > 70 && horde.count < 22 {
      hordeTimer = 0
      horde.append(
        Lemming(x: data.start.x, y: data.start.y, mask: mask, level: art))
    }

    hordePhase += 1
    guard hordePhase >= 6 else { return }
    hordePhase = 0

    var index = 0
    while index < horde.count {
      let lemming = horde[index]
      lemming.updateImage()
      if lemming.dead || lemming.exited() {
        horde.remove(at: index)
        continue
      }
      lemming.move()
      index += 1
    }
  }

  /// Landing on one squashes it and bounces the player — the one bit of this
  /// that is pure slapstick.
  private func stompCheck() {
    guard vy > 1 else { return }
    for lemming in horde where !lemming.dead && !lemming.dying {
      let lx = Double(lemming.xPos)
      let ly = Double(lemming.yPos)
      let lw = Double(lemming.curImage.width)
      let overlapsX = px + Double(Dash.boxW) > lx + 4 && px < lx + lw - 4
      let feet = py + Double(Dash.boxH)
      let onHead = feet > ly && feet < ly + 18
      if overlapsX && onHead {
        lemming.dying = true
        vy = Dash.jumpSpeed * 0.72
        jumpCutArmed = false
        return
      }
    }
  }

  // MARK: - Camera

  private var viewWidth: Double { Double(Level.canvasWidth) / Dash.zoom }
  private var viewHeight: Double { Double(Level.canvasHeight - Dash.hudHeight) / Dash.zoom }

  private func targetCamera() -> (Double, Double) {
    let cx = px + Double(Dash.boxW) / 2 - viewWidth / 2
    let cy = py + Double(Dash.boxH) / 2 - viewHeight / 2
    return (
      min(max(cx, 0), max(0, Double(art.width) - viewWidth)),
      min(max(cy, 0), max(0, Double(art.height) - viewHeight))
    )
  }

  private func snapCamera() {
    (camX, camY) = targetCamera()
  }

  /// Eased, so the view slides after the player rather than snapping to them.
  private func followCamera() {
    let (tx, ty) = targetCamera()
    camX += (tx - camX) * 0.16
    camY += (ty - camY) * 0.16
  }

  // MARK: - Inspection (for the headless playtest)

  var debugState:
    (x: Int, y: Int, vx: Double, vy: Double, onGround: Bool, deaths: Int, won: Bool,
     bombs: Int, horde: Int)
  {
    (Int(px), Int(py), vx, vy, onGround, deaths, finished, bombs.count, horde.count)
  }

  /// Speed added by the most recent blast, whichever way it threw the player.
  private(set) var debugLastKick = 0.0

  func debugHold(_ key: GameKey) { held.insert(Dash.normalize(key)) }
  func debugRelease(_ key: GameKey) { held.remove(Dash.normalize(key)) }
  func debugReleaseAll() { held.removeAll() }

  // MARK: - Input

  func keyDown(_ key: GameKey) {
    let normalized = Dash.normalize(key)
    held.insert(normalized)

    switch normalized {
    case .char("b"):
      throwBomb()
    case .char("r"):
      if finished { load(levelOffset: 0) } else { die() }
    case .char("n"):
      load(levelOffset: 1)
    case .char("p"):
      load(levelOffset: -1)
    case .enter where finished:
      load(levelOffset: 1)
    case .escape:
      wantsOut = true
    default:
      break
    }
  }

  func keyUp(_ key: GameKey) {
    held.remove(Dash.normalize(key))
  }

  /// Case-folds letters so shift does not break the controls.
  static func normalize(_ key: GameKey) -> GameKey {
    if case .char(let c) = key {
      return .char(Character(c.lowercased()))
    }
    return key
  }
}

/// A thrown bomb. Separate from the puzzle game's `Bomblet` because the two run
/// at different rates — this one is stepped 60 times a second, not 10.
final class DashBomb {
  var x: Double
  var y: Double
  var vx: Double
  var vy: Double
  var fuse: Int
  var age = 0

  init(x: Double, y: Double, vx: Double, vy: Double, fuse: Int) {
    self.x = x
    self.y = y
    self.vx = vx
    self.vy = vy
    self.fuse = fuse
  }
}

// MARK: - Drawing

extension Dash {

  /// Converts a point in the level into a point on the canvas.
  private func toScreen(_ lx: Double, _ ly: Double) -> (x: Int, y: Int) {
    (
      Int((lx - camX) * Dash.zoom),
      Dash.hudHeight + Int((ly - camY) * Dash.zoom)
    )
  }

  private func scaled(_ value: Int) -> Int { Int(Double(value) * Dash.zoom) }

  func draw(_ g: Graphics) {
    g.setFont(size: 12)

    // The level, scrolled under the camera.
    g.setColor(AWTColor.black)
    g.fillRect(0, 0, Level.canvasWidth, Level.canvasHeight)
    let origin = toScreen(0, 0)
    g.drawImage(art, origin.x, origin.y, scaled(art.width), scaled(art.height))

    drawHorde(g)
    drawBombs(g)
    drawPlayer(g)
    drawHUD(g)

    if finished { drawFinished(g) }
    if flash > 0 {
      // A red wash on death, fading over the next few frames.
      g.setColor(AWTColor.red)
      let band = flash * 3
      g.fillRect(0, Dash.hudHeight, Level.canvasWidth, band)
      g.fillRect(0, Level.canvasHeight - band, Level.canvasWidth, band)
    }
  }

  private func drawHorde(_ g: Graphics) {
    for lemming in horde {
      let point = toScreen(Double(lemming.xPos), Double(lemming.yPos))
      g.drawImage(
        lemming.curImage, point.x, point.y,
        scaled(lemming.curImage.width), scaled(lemming.curImage.height))
    }
  }

  private func drawBombs(_ g: Graphics) {
    for bomb in bombs {
      let point = toScreen(bomb.x, bomb.y)
      let size = scaled(11)
      // Flashes faster as the fuse runs down.
      let blink = bomb.fuse < 24 && (bomb.fuse / 3) % 2 == 0
      g.setColor(blink ? AWTColor.white : AWTColor.packed(0xFF1A1A1A))
      g.fillOval(point.x - size / 2, point.y - size / 2, size, size)
      g.setColor(AWTColor.orange)
      g.fillOval(point.x - size / 6, point.y - size / 2 - size / 3, size / 3, size / 3)
    }

    for blast in blasts {
      let spread = blast.radius + (Blast.duration - blast.life) * 8
      let point = toScreen(Double(blast.x), Double(blast.y))
      let outer = scaled(spread)
      let inner = outer / 2
      g.setColor(blast.life > Blast.duration / 2 ? AWTColor.white : AWTColor.orange)
      g.fillOval(point.x - outer, point.y - outer, outer * 2, outer * 2)
      g.setColor(AWTColor.yellow)
      g.fillOval(point.x - inner, point.y - inner, inner * 2, inner * 2)
    }
  }

  private func drawPlayer(_ g: Graphics) {
    let sprites = Sprites.shared
    let sprite: Bitmap

    if digging {
      sprite = (animTick / 5) % 2 == 0 ? sprites.digRight : sprites.digLeft
    } else if !onGround {
      sprite = facingRight ? sprites.fallingRight : sprites.fallingLeft
    } else if abs(vx) > 0.4 {
      let step = (animTick / 5) % 3
      if facingRight {
        sprite = step == 0 ? sprites.rightMid : (step == 1 ? sprites.rightFront : sprites.rightBack)
      } else {
        sprite = step == 0 ? sprites.leftMid : (step == 1 ? sprites.leftFront : sprites.leftBack)
      }
    } else {
      sprite = facingRight ? sprites.rightMid : sprites.leftMid
    }

    // The sprite is wider than the collision box, so it is centred on it and
    // stood on its bottom edge.
    let drawX = px + Double(Dash.boxW) / 2 - Double(sprite.width) / 2
    let drawY = py + Double(Dash.boxH) - Double(sprite.height)
    let point = toScreen(drawX, drawY)
    g.drawImage(
      sprite, point.x, point.y, scaled(sprite.width), scaled(sprite.height))

    // A marker while bashing, so it is clear where the damage is going.
    if bashing {
      let reach = facingRight ? Dash.boxW + 10 : -10
      let hit = toScreen(px + Double(reach), py + Double(Dash.boxH) / 2)
      let r = scaled(Dash.bashRadius)
      g.setColor(AWTColor.yellow)
      g.drawOval(hit.x - r, hit.y - r, r * 2, r * 2)
    }
  }

  private func drawHUD(_ g: Graphics) {
    g.setColor(AWTColor.packed(0xFF101018))
    g.fillRect(0, 0, Level.canvasWidth, Dash.hudHeight)
    g.setColor(AWTColor.packed(0xFF3A3A4A))
    g.fillRect(0, Dash.hudHeight - 2, Level.canvasWidth, 2)

    g.setFont(size: 15, bold: true)
    g.setColor(AWTColor.packed(0xFFF2D23A))
    g.drawString("LEMMING DASH", 12, 26)

    g.setFont(size: 13)
    g.setColor(AWTColor.white)
    g.drawString("\(levelIndex + 1)/\(chooser.levelCount)  \(data.file)", 160, 26)

    let seconds = frames / 60
    g.drawString(
      String(format: "%d:%02d", seconds / 60, seconds % 60), 330, 26)
    g.setColor(deaths > 0 ? AWTColor.packed(0xFFE8663A) : AWTColor.white)
    g.drawString("deaths \(deaths)", 400, 26)

    g.setColor(AWTColor.packed(0xFF8A8A9A))
    g.setFont(size: 11)
    g.drawString(
      "arrows/WASD move  .  space jump  .  S dig  .  X bash  .  B bomb"
        + "  .  R reset  .  N/P level  .  esc out", 500, 25)
  }

  private func drawFinished(_ g: Graphics) {
    g.setColor(AWTColor.packed(0xFF101018))
    g.fillRect(180, 190, 440, 190)
    g.setColor(AWTColor.packed(0xFFF2D23A))
    g.drawRect(180, 190, 440, 190)

    g.setFont(size: 26, bold: true)
    g.drawString("OUT!", 370, 240)

    g.setFont(size: 14)
    g.setColor(AWTColor.white)
    let seconds = frames / 60
    g.drawString(
      String(format: "%@ in %d:%02d", data.file, seconds / 60, seconds % 60), 240, 285)
    g.drawString("deaths: \(deaths)", 240, 310)
    g.setColor(AWTColor.packed(0xFF8A8A9A))
    g.drawString("enter or N for the next level  .  R to run it again", 240, 345)
  }
}
