import CoreGraphics
import Foundation

/// DOOMMINGS — a first-person shooter played inside a Lemmings level.
///
/// The trick is that a level mask is already exactly what a raycaster wants: a
/// 2D grid of solid and empty. So the side-on cross-section of a Lemmings level
/// gets read as a floor plan and walked through from the inside. The platforms
/// you used to drop lemmings off become the walls of a maze.
///
/// Nothing here is new art. Walls are coloured from the level painting, the
/// wanderers are the lemming sprites billboarded, and the map in the corner is
/// the collision mask drawn directly. And because the mask is the world, the
/// walls are destructible for free: blow a hole in one and the renderer sees it
/// on the very next frame, because it is reading the same pixels.
final class Doommings {

  // MARK: - Tuning

  /// Mask pixels per grid cell. Larger means chunkier walls and a smaller map
  /// in cell units — which matters more than it sounds, because wall height on
  /// screen is inverse to distance *in cells*. At 10 the open sky of a level
  /// put every wall 40 cells away and two pixels tall; 16 brings the world in
  /// to roughly Wolfenstein proportions.
  static let cellSize = 16

  /// Multiplies projected wall height — in effect, how tall the ceilings are.
  static let wallHeight = 1.5

  /// The world is rendered at this size and scaled up, which keeps the pixel
  /// count sane and looks right for the period.
  static let renderWidth = 400
  static let renderHeight = 280
  static let hudHeight = 40

  /// Half-width of the camera plane. 0.66 gives the classic ~66° field.
  static let planeLength = 0.66

  static let moveSpeed = 4.6 / 60.0  // cells per frame
  static let runMultiplier = 1.9
  static let turnSpeed = 2.4 / 60.0  // radians per frame
  /// Keeps the player's shoulders out of the walls.
  static let playerRadius = 0.28

  static let bombSpeed = 14.0 / 60.0
  static let bombRadius = 34  // in mask pixels
  static let maxBombs = 4

  // MARK: - What a cell is

  enum Cell: UInt8 {
    case open = 0
    case dirt = 1  // wall, diggable
    case rock = 2  // wall, indestructible
    case hazard = 3  // floor, lethal
    case exit = 4  // floor, the way out

    var isWall: Bool { self == .dirt || self == .rock }
  }

  // MARK: - World

  private let chooser: LevelChooser
  private(set) var levelIndex: Int
  private var data: LevelData
  private var art: Bitmap
  private var mask: Bitmap

  private var grid: [Cell] = []
  private var gridWidth = 0
  private var gridHeight = 0

  // MARK: - Camera

  private var posX = 0.0
  private var posY = 0.0
  private var dirX = 1.0
  private var dirY = 0.0
  private var planeX = 0.0
  private var planeY = Doommings.planeLength

  // MARK: - Contents

  private var bombs: [FPSBomb] = []
  private var wanderers: [Wanderer] = []
  private var fireballs: [Fireball] = []
  private var blastFlash = 0
  /// Frames left on the muzzle flash.
  private var muzzle = 0
  private(set) var kills = 0
  /// Drives the weapon bob while walking.
  private var bobPhase = 0.0

  // MARK: - Run state

  private let frame: Bitmap
  private var zBuffer: [Double]
  private var held: Set<GameKey> = []
  private(set) var deaths = 0
  private var frames = 0
  private var finished = false
  private var hurtFlash = 0
  private(set) var wantsOut = false

  // MARK: - Setup

  init(chooser: LevelChooser, levelIndex: Int) {
    self.chooser = chooser
    self.levelIndex = levelIndex
    self.data = chooser.levelData(levelIndex)
    self.art = Assets.bitmap("\(data.file).png")
    self.mask = Assets.bitmap("\(data.file)mask.png")
    self.frame = Bitmap(width: Doommings.renderWidth, height: Doommings.renderHeight)
    self.zBuffer = Array(repeating: 0, count: Doommings.renderWidth)
    buildGrid()
    spawn()
  }

  func load(levelOffset: Int) {
    levelIndex = (levelIndex + levelOffset + chooser.levelCount) % chooser.levelCount
    data = chooser.levelData(levelIndex)
    art = Assets.bitmap("\(data.file).png")
    mask = Assets.bitmap("\(data.file)mask.png")
    bombs.removeAll()
    wanderers.removeAll()
    deaths = 0
    frames = 0
    finished = false
    buildGrid()
    spawn()
  }

  // MARK: - The floor plan

  /// Reduces the mask to a grid of cells.
  ///
  /// A cell counts as wall if it holds any solid pixel at all, so a thin ledge
  /// still reads as a wall rather than vanishing between samples.
  private func buildGrid() {
    gridWidth = mask.width / Doommings.cellSize
    gridHeight = mask.height / Doommings.cellSize
    grid = Array(repeating: .open, count: gridWidth * gridHeight)
    for cy in 0..<gridHeight {
      for cx in 0..<gridWidth {
        grid[cy * gridWidth + cx] = classify(cellX: cx, cellY: cy)
      }
    }
  }

  private func classify(cellX: Int, cellY: Int) -> Cell {
    var dirt = 0
    var rock = 0
    var hazard = 0
    var exit = 0
    let x0 = cellX * Doommings.cellSize
    let y0 = cellY * Doommings.cellSize

    for dy in stride(from: 0, to: Doommings.cellSize, by: 2) {
      for dx in stride(from: 0, to: Doommings.cellSize, by: 2) {
        let color = mask.getRGB(x0 + dx, y0 + dy)
        if isColor(color, Mask.red) {
          dirt += 1
        } else if isColor(color, Mask.green) {
          rock += 1
        } else if isColor(color, Mask.white) {
          hazard += 1
        } else if isColor(color, Mask.blue) {
          exit += 1
        }
      }
    }

    // Walls win over floor markings; the exit wins over plain hazard so it
    // stays findable.
    if rock > dirt && rock > 0 { return .rock }
    if dirt > 0 { return .dirt }
    if exit > 0 { return .exit }
    if hazard > 0 { return .hazard }
    return .open
  }

  private func cell(_ x: Int, _ y: Int) -> Cell {
    guard x >= 0, x < gridWidth, y >= 0, y < gridHeight else { return .rock }
    return grid[y * gridWidth + x]
  }

  /// Puts the player at the level's lemming entrance, or the nearest open cell
  /// to it — in the puzzle game that point hangs in mid-air, which here is
  /// simply an empty bit of floor.
  private func spawn() {
    let startX = data.start.x / Doommings.cellSize
    let startY = data.start.y / Doommings.cellSize

    var best: (x: Int, y: Int)?
    for radius in 0..<40 where best == nil {
      for dy in -radius...radius {
        for dx in -radius...radius where abs(dx) == radius || abs(dy) == radius || radius == 0 {
          let cx = startX + dx
          let cy = startY + dy
          if !cell(cx, cy).isWall, cell(cx, cy) != .hazard, cx > 0, cy > 0 {
            best = (cx, cy)
            break
          }
        }
        if best != nil { break }
      }
    }

    let found = best ?? (x: gridWidth / 2, y: gridHeight / 2)
    posX = Double(found.x) + 0.5
    posY = Double(found.y) + 0.5
    setAngle(0)
  }

  private func setAngle(_ radians: Double) {
    dirX = cos(radians)
    dirY = sin(radians)
    planeX = -dirY * Doommings.planeLength
    planeY = dirX * Doommings.planeLength
  }

  // MARK: - Frame

  func tick() {
    frames += 1
    if hurtFlash > 0 { hurtFlash -= 1 }
    if blastFlash > 0 { blastFlash -= 1 }
    guard !finished else { return }

    if muzzle > 0 { muzzle -= 1 }
    move()
    updateBombs()
    updateWanderers()

    switch cell(Int(posX), Int(posY)) {
    case .hazard:
      deaths += 1
      hurtFlash = 14
      spawn()
    case .exit:
      finished = true
    default:
      break
    }
  }

  private func move() {
    // Shift arrives as a modifier, not a character, so it never reaches the
    // held set — R is the run key.
    let running = held.contains(.char("r"))
    let speed = Doommings.moveSpeed * (running ? Doommings.runMultiplier : 1)

    if held.contains(.left) { rotate(-Doommings.turnSpeed) }
    if held.contains(.right) { rotate(Doommings.turnSpeed) }

    var stepX = 0.0
    var stepY = 0.0
    if held.contains(.char("w")) || held.contains(.up) {
      stepX += dirX * speed
      stepY += dirY * speed
    }
    if held.contains(.char("s")) || held.contains(.down) {
      stepX -= dirX * speed
      stepY -= dirY * speed
    }
    // Strafing, which is the difference between a shooter and a walking tour.
    if held.contains(.char("a")) {
      stepX += planeX * -speed / Doommings.planeLength * 0.7
      stepY += planeY * -speed / Doommings.planeLength * 0.7
    }
    if held.contains(.char("d")) {
      stepX += planeX * speed / Doommings.planeLength * 0.7
      stepY += planeY * speed / Doommings.planeLength * 0.7
    }

    // Axis at a time, so sliding along a wall works instead of sticking.
    if !blocked(posX + stepX + (stepX > 0 ? Doommings.playerRadius : -Doommings.playerRadius), posY) {
      posX += stepX
    }
    if !blocked(posX, posY + stepY + (stepY > 0 ? Doommings.playerRadius : -Doommings.playerRadius)) {
      posY += stepY
    }
  }

  private func blocked(_ x: Double, _ y: Double) -> Bool {
    cell(Int(x), Int(y)).isWall
  }

  private func rotate(_ amount: Double) {
    let cosA = cos(amount)
    let sinA = sin(amount)
    let oldDirX = dirX
    dirX = dirX * cosA - dirY * sinA
    dirY = oldDirX * sinA + dirY * cosA
    let oldPlaneX = planeX
    planeX = planeX * cosA - planeY * sinA
    planeY = oldPlaneX * sinA + planeY * cosA
  }

  // MARK: - Bombs

  func fire() {
    guard !finished, bombs.count < Doommings.maxBombs else { return }
    // Spawned a little way down the barrel. Launched from the camera itself it
    // would sit at zero depth and project to the size of the whole screen on
    // its first frame.
    bombs.append(
      FPSBomb(x: posX + dirX * 1.3, y: posY + dirY * 1.3, dx: dirX, dy: dirY, life: 150))
    muzzle = 5
  }

  private func updateBombs() {
    var index = 0
    while index < bombs.count {
      let bomb = bombs[index]
      bomb.life -= 1
      let nextX = bomb.x + bomb.dx * Doommings.bombSpeed
      let nextY = bomb.y + bomb.dy * Doommings.bombSpeed

      if cell(Int(nextX), Int(nextY)).isWall || bomb.life <= 0 {
        detonate(atCellX: nextX, cellY: nextY)
        bombs.remove(at: index)
        continue
      }
      bomb.x = nextX
      bomb.y = nextY
      index += 1
    }
  }

  /// Blows a hole in the mask and rebuilds the cells it touched.
  ///
  /// Only diggable earth goes; rock stays. Because the grid is derived from the
  /// mask rather than stored separately, the wall is gone from the renderer's
  /// point of view the instant the pixels change.
  private func detonate(atCellX x: Double, cellY y: Double) {
    let maskX = Int(x * Double(Doommings.cellSize))
    let maskY = Int(y * Double(Doommings.cellSize))
    let radius = Doommings.bombRadius
    let sky = art.getRGB(200, 200)

    for dy in -radius...radius {
      let py = maskY + dy
      guard py >= 0, py < mask.height else { continue }
      let span = Int(Double(radius * radius - dy * dy).squareRoot())
      for dx in -span...span {
        let px = maskX + dx
        guard px >= 0, px < mask.width else { continue }
        if isColor(mask.getRGB(px, py), Mask.red) {
          mask.setRGB(px, py, Mask.black)
          art.setRGB(px, py, sky)
        }
      }
    }

    let pad = radius / Doommings.cellSize + 2
    let cx = maskX / Doommings.cellSize
    let cy = maskY / Doommings.cellSize
    for gy in max(0, cy - pad)...min(gridHeight - 1, cy + pad) {
      for gx in max(0, cx - pad)...min(gridWidth - 1, cx + pad) {
        grid[gy * gridWidth + gx] = classify(cellX: gx, cellY: gy)
      }
    }

    blastFlash = 6
    fireballs.append(Fireball(x: x, y: y, life: Fireball.duration))

    for wanderer in wanderers where wanderer.dying == 0 {
      let ddx = wanderer.x - x
      let ddy = wanderer.y - y
      let reach = Double(radius) / Double(Doommings.cellSize)
      if ddx * ddx + ddy * ddy < reach * reach {
        // Let it play a death before it goes, so a hit reads as a hit.
        wanderer.dying = Wanderer.deathFrames
        kills += 1
      }
    }
  }

  // MARK: - The locals

  private func updateWanderers() {
    if frames % 50 == 0 && wanderers.count < 14 {
      // Drop one in somewhere open and out of sight.
      for _ in 0..<30 {
        let cx = Int.random(in: 1..<max(gridWidth - 1, 2))
        let cy = Int.random(in: 1..<max(gridHeight - 1, 2))
        guard cell(cx, cy) == .open else { continue }
        let dx = Double(cx) + 0.5 - posX
        let dy = Double(cy) + 0.5 - posY
        guard dx * dx + dy * dy > 36 else { continue }
        wanderers.append(
          Wanderer(x: Double(cx) + 0.5, y: Double(cy) + 0.5, angle: Double.random(in: 0..<6.28)))
        break
      }
    }

    for wanderer in wanderers {
      wanderer.step += 1
      if wanderer.dying > 0 {
        wanderer.dying -= 1
        continue
      }
      let speed = 1.6 / 60.0
      let nx = wanderer.x + cos(wanderer.angle) * speed
      let ny = wanderer.y + sin(wanderer.angle) * speed
      if cell(Int(nx), Int(ny)).isWall {
        // Pick a new heading when it walks into something.
        wanderer.angle += Double.random(in: 1.8...4.4)
      } else {
        wanderer.x = nx
        wanderer.y = ny
      }
    }
    wanderers.removeAll { $0.dying == 0 && !$0.alive }
    wanderers.removeAll { $0.dying < 0 }

    for i in fireballs.indices { fireballs[i].life -= 1 }
    fireballs.removeAll { $0.life <= 0 }
  }

  // MARK: - Input

  func keyDown(_ key: GameKey) {
    let normalized = Doommings.normalize(key)
    held.insert(normalized)
    switch normalized {
    case .char(" "), .char("f"):
      fire()
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
    held.remove(Doommings.normalize(key))
  }

  static func normalize(_ key: GameKey) -> GameKey {
    if case .char(let c) = key { return .char(Character(c.lowercased())) }
    return key
  }

  // MARK: - Inspection, for the headless test

  var debugState:
    (x: Double, y: Double, cells: Int, walls: Int, bombs: Int, wanderers: Int, deaths: Int,
     won: Bool)
  {
    (posX, posY, grid.count, grid.filter { $0.isWall }.count, bombs.count, wanderers.count,
      deaths, finished)
  }

  func debugHold(_ key: GameKey) { held.insert(Doommings.normalize(key)) }
  func debugRelease(_ key: GameKey) { held.remove(Doommings.normalize(key)) }
  func debugReleaseAll() { held.removeAll() }
  func debugFace(_ radians: Double) { setAngle(radians) }
  var debugWallCount: Int { grid.filter { $0.isWall }.count }

  /// True if the camera is standing inside solid geometry, which it never
  /// should be.
  var debugInWall: Bool { cell(Int(posX), Int(posY)).isWall }

  /// Distance in cells to the first wall straight ahead, and what it is made
  /// of — rock is meant to shrug off rockets, so a test that wants to prove
  /// they work has to find earth.
  func debugWallAhead() -> (distance: Double, cell: Cell) {
    var t = 0.0
    while t < 60 {
      t += 0.25
      let here = cell(Int(posX + dirX * t), Int(posY + dirY * t))
      if here.isWall { return (t, here) }
    }
    return (.infinity, .open)
  }
}

/// A rocket in flight. It travels flat across the floor plan, which is all the
/// world has.
final class FPSBomb {
  var x: Double
  var y: Double
  let dx: Double
  let dy: Double
  var life: Int

  init(x: Double, y: Double, dx: Double, dy: Double, life: Int) {
    self.x = x
    self.y = y
    self.dx = dx
    self.dy = dy
    self.life = life
  }
}

/// The ball of fire left where a rocket landed.
struct Fireball {
  var x: Double
  var y: Double
  var life: Int

  static let duration = 16
}

/// A lemming going about its business in three dimensions.
final class Wanderer {
  var x: Double
  var y: Double
  var angle: Double
  var step = 0
  var alive = true
  /// Counts down while it plays out being hit; 0 means alive and well.
  var dying = 0

  static let deathFrames = 22

  init(x: Double, y: Double, angle: Double) {
    self.x = x
    self.y = y
    self.angle = angle
  }
}

// MARK: - Rendering

extension Doommings {

  /// Darkens a packed colour toward black.
  private func shade(_ argb: UInt32, _ factor: Double) -> UInt32 {
    let f = min(max(factor, 0), 1)
    let r = UInt32(Double((argb >> 16) & 0xFF) * f)
    let g = UInt32(Double((argb >> 8) & 0xFF) * f)
    let b = UInt32(Double(argb & 0xFF) * f)
    return 0xFF00_0000 | (r << 16) | (g << 8) | b
  }

  func draw(_ g: Graphics) {
    renderWorld()
    g.drawImage(
      frame, 0, Doommings.hudHeight,
      Level.canvasWidth, Level.canvasHeight - Doommings.hudHeight)
    drawWeapon(g)
    drawCrosshair(g)
    drawMinimap(g)
    drawHUD(g)
    if finished { drawFinished(g) }
  }

  /// One pass of raycasting: ceiling and floor bands, then a wall strip per
  /// screen column, then the sprites sorted back to front against the z-buffer
  /// the walls just filled in.
  private func renderWorld() {
    let width = Doommings.renderWidth
    let height = Doommings.renderHeight
    let sky = art.getRGB(200, 200)
    let horizon = height / 2

    // Ceiling fades toward the level's own sky colour; floor toward its earth.
    for y in 0..<horizon {
      let t = Double(y) / Double(horizon)
      frame.fillRow(y, from: 0, to: width - 1, shade(sky, 0.30 + t * 0.45))
    }
    for y in horizon..<height {
      let t = Double(y - horizon) / Double(height - horizon)
      frame.fillRow(y, from: 0, to: width - 1, shade(0x7A6A52, 0.32 + t * 0.62))
    }

    for column in 0..<width {
      let cameraX = 2.0 * Double(column) / Double(width) - 1.0
      let rayDirX = dirX + planeX * cameraX
      let rayDirY = dirY + planeY * cameraX

      var mapX = Int(posX)
      var mapY = Int(posY)

      let deltaX = rayDirX == 0 ? 1e30 : abs(1 / rayDirX)
      let deltaY = rayDirY == 0 ? 1e30 : abs(1 / rayDirY)

      var stepX = 1
      var stepY = 1
      var sideDistX: Double
      var sideDistY: Double

      if rayDirX < 0 {
        stepX = -1
        sideDistX = (posX - Double(mapX)) * deltaX
      } else {
        sideDistX = (Double(mapX) + 1.0 - posX) * deltaX
      }
      if rayDirY < 0 {
        stepY = -1
        sideDistY = (posY - Double(mapY)) * deltaY
      } else {
        sideDistY = (Double(mapY) + 1.0 - posY) * deltaY
      }

      // Digital differential analysis: step cell to cell until a wall.
      var side = 0
      var hit = Cell.open
      var guardCount = 0
      while guardCount < 512 {
        guardCount += 1
        if sideDistX < sideDistY {
          sideDistX += deltaX
          mapX += stepX
          side = 0
        } else {
          sideDistY += deltaY
          mapY += stepY
          side = 1
        }
        let here = cell(mapX, mapY)
        if here.isWall {
          hit = here
          break
        }
      }

      let perpDist =
        side == 0
        ? (Double(mapX) - posX + Double(1 - stepX) / 2) / rayDirX
        : (Double(mapY) - posY + Double(1 - stepY) / 2) / rayDirY
      let distance = max(perpDist, 0.0001)
      zBuffer[column] = distance

      let lineHeight = Int(Double(height) * Doommings.wallHeight / distance)
      let top = max(-lineHeight / 2 + horizon, 0)
      let bottom = min(lineHeight / 2 + horizon, height - 1)

      // Colour the wall from the level painting at the point the ray struck,
      // so every level keeps its own palette.
      var wallX =
        side == 0
        ? posY + distance * rayDirY
        : posX + distance * rayDirX
      wallX -= wallX.rounded(.down)

      let sampleX: Int
      let sampleY: Int
      if side == 0 {
        sampleX = mapX * Doommings.cellSize + Doommings.cellSize / 2
        sampleY = Int((Double(mapY) + wallX) * Double(Doommings.cellSize))
      } else {
        sampleX = Int((Double(mapX) + wallX) * Double(Doommings.cellSize))
        sampleY = mapY * Doommings.cellSize + Doommings.cellSize / 2
      }
      var base = art.getRGB(
        min(max(sampleX, 0), art.width - 1), min(max(sampleY, 0), art.height - 1))
      if hit == .rock { base = shade(base, 0.82) }

      // Distance fog, plus a flat face/side difference so corners read.
      // Falls off gently and never reaches black, or the far side of a level
      // is just a void.
      var light = min(1.35 / (1.0 + distance * 0.085), 1.15)
      if side == 1 { light *= 0.74 }
      // A seam at each cell edge gives the walls some grain.
      if wallX < 0.04 || wallX > 0.96 { light *= 0.7 }
      light = max(light, 0.22)

      frame.fillColumn(column, from: top, to: bottom, shade(base, light))
    }

    drawSprites()
    drawOrdnance()
  }

  /// Rockets in flight and the fireballs they leave.
  private func drawOrdnance() {
    for bomb in bombs {
      // Trail first: drawn after the rocket it simply painted over the hot
      // core, which is what made the projectile read as a brown blob.
      drawDisc(
        atX: bomb.x - bomb.dx * 0.5, y: bomb.y - bomb.dy * 0.5, worldRadius: 0.05,
        rings: [(1.0, 0xFF88_6650)])
      drawDisc(
        atX: bomb.x, y: bomb.y, worldRadius: 0.09,
        rings: [(1.0, 0xFF50_2A14), (0.74, 0xFFFF_8A2A), (0.42, 0xFFFF_F0B0)])
    }

    for ball in fireballs {
      let age = Double(Fireball.duration - ball.life) / Double(Fireball.duration)
      let radius = 0.8 + age * 1.9
      // Cools from white through orange to smoke as it expands.
      let rings: [(Double, UInt32)]
      if age < 0.35 {
        rings = [(1.0, 0xFFFF_A02A), (0.65, 0xFFFF_E07A), (0.3, 0xFFFF_FFFF)]
      } else if age < 0.7 {
        rings = [(1.0, 0xFF8A_3A1A), (0.6, 0xFFFF_8A2A), (0.25, 0xFFFF_D06A)]
      } else {
        rings = [(1.0, 0xFF4A_3A32), (0.5, 0xFF6A_5248)]
      }
      drawDisc(atX: ball.x, y: ball.y, worldRadius: radius, rings: rings)
    }
  }

  /// Projects a world point into the view. Returns nil behind the camera.
  private func project(_ wx: Double, _ wy: Double) -> (screenX: Int, depth: Double)? {
    let relX = wx - posX
    let relY = wy - posY
    let inverse = 1.0 / (planeX * dirY - dirX * planeY)
    let transformX = inverse * (dirY * relX - dirX * relY)
    let transformY = inverse * (-planeY * relX + planeX * relY)
    guard transformY > 0.25 else { return nil }
    return (
      Int(Double(Doommings.renderWidth) / 2 * (1 + transformX / transformY)), transformY
    )
  }

  /// Draws a set of concentric discs at a world position — the rockets and
  /// their fireballs, which have no sprite of their own.
  private func drawDisc(
    atX wx: Double, y wy: Double, worldRadius: Double, rings: [(Double, UInt32)]
  ) {
    guard let shot = project(wx, wy) else { return }
    let horizon = Doommings.renderHeight / 2
    let full = Double(Doommings.renderHeight) * Doommings.wallHeight * worldRadius / shot.depth
    // Too small to see, or so close it is effectively inside the camera.
    guard full >= 1, full < Double(Doommings.renderHeight) else { return }

    for (scale, color) in rings {
      let radius = Int(full * scale)
      guard radius >= 1 else { continue }
      for dy in -radius...radius {
        let y = horizon + dy
        guard y >= 0, y < Doommings.renderHeight else { continue }
        let span = Int((Double(radius * radius - dy * dy)).squareRoot())
        guard span >= 0 else { continue }
        for x in (shot.screenX - span)...(shot.screenX + span) {
          guard x >= 0, x < Doommings.renderWidth else { continue }
          // Behind a wall? Then it is not seen.
          guard shot.depth < zBuffer[x] else { continue }
          frame.fillColumn(x, from: y, to: y, color)
        }
      }
    }
  }

  /// Billboards the wanderers, back to front, clipped against the z-buffer.
  private func drawSprites() {
    let width = Doommings.renderWidth
    let height = Doommings.renderHeight
    let horizon = height / 2
    let sprites = Sprites.shared

    let sorted = wanderers.sorted {
      let d0 = ($0.x - posX) * ($0.x - posX) + ($0.y - posY) * ($0.y - posY)
      let d1 = ($1.x - posX) * ($1.x - posX) + ($1.y - posY) * ($1.y - posY)
      return d0 > d1
    }

    for wanderer in sorted {
      let relX = wanderer.x - posX
      let relY = wanderer.y - posY

      // Into camera space.
      let inverse = 1.0 / (planeX * dirY - dirX * planeY)
      let transformX = inverse * (dirY * relX - dirX * relY)
      let transformY = inverse * (-planeY * relX + planeX * relY)
      guard transformY > 0.15 else { continue }

      let screenX = Int(Double(width) / 2 * (1 + transformX / transformY))
      let spriteHeight = abs(Int(Double(height) / transformY))
      let spriteWidth = spriteHeight * 36 / 41

      let image: Bitmap
      if wanderer.dying > 0 {
        // Plays the puzzle game's own death frames, so a kill is unmistakable.
        let stage = Wanderer.deathFrames - wanderer.dying
        image = stage < 7 ? sprites.die1 : (stage < 14 ? sprites.die2 : sprites.die3)
      } else {
        image = (wanderer.step / 9) % 2 == 0 ? sprites.rightMid : sprites.rightFront
      }
      let top = max(-spriteHeight / 2 + horizon, 0)
      let bottom = min(spriteHeight / 2 + horizon, height - 1)
      let left = max(screenX - spriteWidth / 2, 0)
      let right = min(screenX + spriteWidth / 2, width - 1)
      guard left <= right, top <= bottom, spriteHeight > 0 else { continue }

      let light = max(min(1.3 / (1.0 + transformY * 0.085), 1.1), 0.3)

      for sx in left...right {
        guard transformY < zBuffer[sx] else { continue }
        let u = (sx - (screenX - spriteWidth / 2)) * image.width / max(spriteWidth, 1)
        guard u >= 0, u < image.width else { continue }
        for sy in top...bottom {
          let v = (sy - (-spriteHeight / 2 + horizon)) * image.height / max(spriteHeight, 1)
          guard v >= 0, v < image.height else { continue }
          let texel = image.getRGB(u, v)
          guard (texel >> 24) > 128 else { continue }
          frame.fillColumn(sx, from: sy, to: sy, shade(texel, light))
        }
      }
    }
  }

  // MARK: - Overlay

  /// The launcher, held bottom-right, bobbing as you walk. An FPS without a
  /// weapon on screen reads as broken even when the gun works — which is
  /// exactly how this looked before it had one.
  private func drawWeapon(_ g: Graphics) {
    let moving =
      held.contains(.char("w")) || held.contains(.char("s")) || held.contains(.up)
      || held.contains(.down) || held.contains(.char("a")) || held.contains(.char("d"))
    if moving { bobPhase += 0.22 }
    let bob = moving ? Int(sin(bobPhase) * 7) : 0
    let kick = muzzle > 0 ? 10 : 0

    let baseX = 500
    let baseY = Level.canvasHeight + bob + kick

    // Barrel.
    g.setColor(AWTColor.packed(0xFF3A3A44))
    g.fillPolygon([
      (baseX + 10, baseY - 10), (baseX + 92, baseY - 10),
      (baseX + 150, baseY - 150), (baseX + 92, baseY - 172),
    ])
    g.setColor(AWTColor.packed(0xFF55555F))
    g.fillPolygon([
      (baseX + 60, baseY - 10), (baseX + 92, baseY - 10),
      (baseX + 150, baseY - 150), (baseX + 126, baseY - 160),
    ])
    // Muzzle ring.
    g.setColor(AWTColor.packed(0xFF2A2A32))
    g.fillOval(baseX + 92, baseY - 182, 62, 34)

    // Gloved hands on the grip.
    g.setColor(AWTColor.packed(0xFFF2D23A))
    g.fillOval(baseX + 24, baseY - 74, 40, 40)
    g.fillOval(baseX + 70, baseY - 116, 36, 36)
    g.setColor(AWTColor.packed(0xFFFFFFFF))
    g.fillRect(baseX + 28, baseY - 44, 32, 24)

    if muzzle > 0 {
      // Flash out of the barrel, shrinking over the few frames it lasts.
      let size = 40 + muzzle * 14
      let cx = baseX + 123
      let cy = baseY - 172
      g.setColor(AWTColor.packed(0xFFFF_8A2A))
      g.fillOval(cx - size / 2, cy - size / 2, size, size)
      g.setColor(AWTColor.packed(0xFFFF_E07A))
      g.fillOval(cx - size / 3, cy - size / 3, size * 2 / 3, size * 2 / 3)
      g.setColor(AWTColor.white)
      g.fillOval(cx - size / 6, cy - size / 6, size / 3, size / 3)
    }
  }

  private func drawCrosshair(_ g: Graphics) {
    let cx = Level.canvasWidth / 2
    let cy = Doommings.hudHeight + (Level.canvasHeight - Doommings.hudHeight) / 2
    g.setColor(AWTColor.packed(0xFF8AE8_8A))
    g.fillRect(cx - 11, cy - 1, 7, 2)
    g.fillRect(cx + 5, cy - 1, 7, 2)
    g.fillRect(cx - 1, cy - 11, 2, 7)
    g.fillRect(cx - 1, cy + 5, 2, 7)
  }

  private func drawMinimap(_ g: Graphics) {
    let mapW = 150
    let mapH = mapW * mask.height / mask.width
    let x = Level.canvasWidth - mapW - 10
    let y = Level.canvasHeight - mapH - 10

    g.setColor(AWTColor.black)
    g.fillRect(x - 2, y - 2, mapW + 4, mapH + 4)
    g.drawImage(mask, x, y, mapW, mapH)

    // Where everyone is.
    g.setColor(AWTColor.yellow)
    for wanderer in wanderers {
      let wx = x + Int(wanderer.x * Double(Doommings.cellSize)) * mapW / mask.width
      let wy = y + Int(wanderer.y * Double(Doommings.cellSize)) * mapH / mask.height
      g.fillRect(wx, wy, 2, 2)
    }

    let px = x + Int(posX * Double(Doommings.cellSize)) * mapW / mask.width
    let py = y + Int(posY * Double(Doommings.cellSize)) * mapH / mask.height
    g.setColor(AWTColor.white)
    g.fillRect(px - 2, py - 2, 5, 5)
    g.drawRect(px - 2 + Int(dirX * 9), py - 2 + Int(dirY * 9), 2, 2)
  }

  private func drawHUD(_ g: Graphics) {
    g.setColor(AWTColor.packed(0xFF0E0E14))
    g.fillRect(0, 0, Level.canvasWidth, Doommings.hudHeight)
    g.setColor(AWTColor.packed(0xFF8A2A2A))
    g.fillRect(0, Doommings.hudHeight - 2, Level.canvasWidth, 2)

    g.setFont(size: 15, bold: true)
    g.setColor(AWTColor.packed(0xFFE8663A))
    g.drawString("DOOMMINGS", 12, 26)

    g.setFont(size: 13)
    g.setColor(AWTColor.white)
    g.drawString("\(levelIndex + 1)/\(chooser.levelCount)  \(data.file)", 135, 26)
    let seconds = frames / 60
    g.drawString(String(format: "%d:%02d", seconds / 60, seconds % 60), 300, 26)
    g.setColor(AWTColor.packed(0xFFF2D23A))
    g.drawString("kills \(kills)", 365, 26)
    g.setColor(deaths > 0 ? AWTColor.packed(0xFFE8663A) : AWTColor.white)
    g.drawString("deaths \(deaths)", 425, 26)

    g.setColor(AWTColor.packed(0xFF7A7A8A))
    g.setFont(size: 11)
    g.drawString("WASD move . arrows turn . R run", 505, 17)
    g.drawString("space fire . N/P level . esc out", 505, 32)

    // Muzzle flash and damage tint.
    if blastFlash > 0 {
      g.setColor(AWTColor.packed(0xFFFFC24A))
      g.fillRect(0, Doommings.hudHeight, Level.canvasWidth, blastFlash * 2)
    }
    if hurtFlash > 0 {
      g.setColor(AWTColor.red)
      let band = hurtFlash * 3
      g.fillRect(0, Doommings.hudHeight, Level.canvasWidth, band)
      g.fillRect(0, Level.canvasHeight - band, Level.canvasWidth, band)
    }
  }

  private func drawFinished(_ g: Graphics) {
    g.setColor(AWTColor.packed(0xFF0E0E14))
    g.fillRect(190, 200, 420, 170)
    g.setColor(AWTColor.packed(0xFFE8663A))
    g.drawRect(190, 200, 420, 170)
    g.setFont(size: 26, bold: true)
    g.drawString("EXIT FOUND", 300, 250)
    g.setFont(size: 14)
    g.setColor(AWTColor.white)
    let seconds = frames / 60
    g.drawString(
      String(format: "%@ in %d:%02d, %d deaths", data.file, seconds / 60, seconds % 60, deaths),
      245, 295)
    g.setColor(AWTColor.packed(0xFF7A7A8A))
    g.drawString("enter or N for the next level", 245, 330)
  }
}
