import CoreGraphics
import Foundation

/// A level in progress: the lemmings, the terrain they are chewing through, the
/// toolbar, and the player input that drives both.
///
/// The original ran this on its own `Thread` with a 100ms sleep, drawing
/// straight into an AWT `BufferStrategy` and spin-waiting on a `while (isPaused)
/// { isPaused = true; }` busy loop. Here `tick()` advances the simulation on a
/// timer and `draw(_:)` renders whatever the current state is, which is what
/// AppKit wants and also means a paused game keeps repainting instead of
/// relying on a frozen back buffer.
final class Level {

  /// Logical window size. Every coordinate in here is in these units.
  static let canvasWidth = 800
  static let canvasHeight = 600

  /// Height of the status band across the top, which is painted over the level.
  static let statusHeight = 50
  /// Top of the toolbar band, which is likewise painted over the level.
  static let toolbarTop = 490
  /// The strip of canvas the level itself is actually visible through.
  static var playfieldHeight: Int { toolbarTop - statusHeight }

  /// Width of one toolbar button. Twelve share the strip left of the minimap:
  /// ten abilities, the nuke, and the release-rate control. The original fit
  /// ten at 70px; each ability added since has narrowed them rather than
  /// stealing the minimap's corner.
  static let slotWidth = 57

  /// How far a Lodestone's field reaches, in level pixels.
  static let lodestoneRadius = 120

  /// Inside this distance a lemming is treated as having arrived, and is left
  /// alone — without it, one sitting on the anchor flips direction every frame.
  static let lodestoneDeadZone = 22

  /// How many duplicates a cluster throws.
  static let clusterCount = 15

  /// Sideways speed of the outermost duplicates, in pixels per frame. The ones
  /// nearer the middle get proportionally less.
  static let clusterSpeed = 12.0

  /// Upward launch speed of the middle duplicates. The outer ones trade some of
  /// this for their sideways travel, which flattens the fan.
  static let clusterLift = 12.0

  /// Radius of a bomblet's crater, in level pixels.
  static let blastRadius = 30

  /// Simulation period. The original slept 100ms per frame, and the movement
  /// constants (4px steps) are tuned to it, so it stays at 100ms.
  static let frameInterval: TimeInterval = 0.100

  // MARK: Terrain and art

  private let bgImage: Bitmap
  private let mask: Bitmap
  private let buttons: Bitmap

  // MARK: Level parameters

  private let levelName: String
  private let maxLem: Int
  private let toSave: Int
  private let levelTime: Int64
  private let xstrt: Int
  private let ystrt: Int
  private var rrate: Int

  /// Remaining uses per ability, indexed by `Ability.rawValue`. `-1` means the
  /// ability is not on this level.
  private var abilityCounts: [Int]

  // MARK: Runtime state

  private(set) var lemmings: [Lemming] = []
  /// Cluster submunitions in flight, and the flashes they leave behind.
  private var bomblets: [Bomblet] = []
  private var blasts: [Blast] = []
  private(set) var running = true
  private(set) var isPaused = false
  private(set) var saved = 0

  private var showHelp = false
  private var showAbout = false
  private var nuke = false

  private var xoffset = 0
  private var yoffset = 0
  private var scale = 1.0
  private var speed = false

  private var selectedAbility: Ability?
  private var mouseX = 0
  private var mouseY = 0

  // MARK: Frame bookkeeping

  private var startTime = currentTimeMillis()
  private var currentTime = currentTimeMillis()
  private var pauseStart: Int64 = 0
  private var difTime: Int64 = 0
  private var newLem: Int64 = -1
  /// Frames elapsed, used only to animate the Lodestone field rings.
  private var frameCounter = 0
  private var lemCount = 0
  private var currCount = 0

  // MARK: Minimap geometry

  private let minimapHeight: Int
  private let minimapX = 695
  private let minimapY: Int

  // MARK: Multiplayer

  private let net: NetPeer?
  var isMulti: Bool { net != nil }

  init(data: LevelData, net: NetPeer?) {
    self.levelName = data.file
    self.maxLem = data.count
    self.toSave = data.goal
    self.levelTime = Int64(data.time) * 60_000
    self.xstrt = data.start.x
    self.ystrt = data.start.y
    self.rrate = 100 - data.rate
    self.abilityCounts = data.abilities
    self.net = net

    self.bgImage = Assets.bitmap("\(data.file).png")
    self.mask = Assets.bitmap("\(data.file)mask.png")
    self.buttons = Assets.bitmap("toolbar.png")

    // Integer division, as in the original: the minimap is 100px wide and this
    // keeps its aspect ratio in whole pixels.
    self.minimapHeight = mask.height / max(mask.width / 100, 1)
    self.minimapY = 595 - minimapHeight

    fitToPlayfield()
  }

  /// A one-line dump of the level counters, for the headless smoke run.
  var summary: String {
    "released=\(lemCount) inLevel=\(currCount) saved=\(saved) "
      + "elapsed=\(difTime / 1000)s lemmings=\(lemmings.count)"
  }

  /// How many lemmings have been released so far, and how many got out.
  var debugCounts: (released: Int, saved: Int, inLevel: Int) {
    (lemCount, saved, currCount)
  }

  /// Plants a Lodestone on the lemming nearest a point, for the self-test.
  @discardableResult
  func debugPlantLodestone(nearX x: Int, y: Int) -> Bool {
    let candidates = lemmings.filter { !$0.dead && !$0.dying && !$0.isLodestone }
    guard
      let pick = candidates.min(by: {
        let a = ($0.xPos - x) * ($0.xPos - x) + ($0.yPos - y) * ($0.yPos - y)
        let b = ($1.xPos - x) * ($1.xPos - x) + ($1.yPos - y) * ($1.yPos - y)
        return a < b
      })
    else { return false }
    apply(.lodestone, to: pick)
    return true
  }

  /// Where the anchors are, and how many lemmings each is currently holding.
  var debugLodestones: [(x: Int, y: Int, caught: Int)] {
    lemmings.filter { $0.isLodestone && !$0.dead }.map { anchor in
      let ax = anchor.xPos + anchor.curImage.width / 2
      let ay = anchor.yPos + anchor.curImage.height / 2
      let caught = lemmings.filter { other in
        guard other !== anchor, !other.dead else { return false }
        let dx = other.xPos + other.curImage.width / 2 - ax
        let dy = other.yPos + other.curImage.height / 2 - ay
        return dx * dx + dy * dy <= Level.lodestoneRadius * Level.lodestoneRadius
      }.count
      return (ax, ay, caught)
    }
  }

  /// Mean horizontal distance from the first anchor to every other live
  /// lemming. The field's job is to bring this down, which is a claim worth
  /// measuring; asserting that everyone inside the field faces the anchor is
  /// not, because terrain legitimately overrides the steering — a lemming
  /// pointed at the anchor still turns around when it walks into a wall.
  var debugMeanDistanceToAnchor: (count: Int, mean: Double)? {
    guard let anchor = lemmings.first(where: { $0.isLodestone && !$0.dead }) else { return nil }
    let ax = anchor.xPos + anchor.curImage.width / 2
    let others = lemmings.filter { $0 !== anchor && !$0.dead && !$0.dying }
    guard !others.isEmpty else { return (0, 0) }
    let total = others.reduce(0.0) {
      $0 + abs(Double($1.xPos + $1.curImage.width / 2 - ax))
    }
    return (others.count, total / Double(others.count))
  }

  /// Bomblets in flight and craters pending, for the cluster self-test.
  var debugClusterState: (inFlight: Int, blasts: Int) {
    (bomblets.count, blasts.count)
  }

  /// How many mask pixels are still diggable terrain. A detonation lowers this,
  /// which is how the test confirms a crater actually appeared.
  func debugDirtPixels() -> Int {
    var count = 0
    var y = 0
    while y < mask.height {
      var x = 0
      while x < mask.width {
        if isColor(mask.getRGB(x, y), Mask.red) { count += 1 }
        x += 4
      }
      y += 4
    }
    return count
  }

  /// How many mask pixels are indestructible terrain. A cluster must never
  /// change this.
  func debugRockPixels() -> Int {
    var count = 0
    var y = 0
    while y < mask.height {
      var x = 0
      while x < mask.width {
        if isColor(mask.getRGB(x, y), Mask.green) { count += 1 }
        x += 4
      }
      y += 4
    }
    return count
  }

  /// Where everyone currently is, for tracing a level that misbehaves.
  var debugPositions: [(x: Int, y: Int, state: String)] {
    lemmings.map { lemming in
      var state = lemming.rightDir ? ">" : "<"
      if lemming.isDigger { state += "dig" }
      if lemming.isBasher { state += "bash" }
      if lemming.falling { state += "fall" }
      if lemming.dying || lemming.dead { state += "dead" }
      return (lemming.xPos, lemming.yPos, state)
    }
  }

  /// Zooms out far enough to show the whole level, and centres it in the strip
  /// of canvas between the status band and the toolbar.
  ///
  /// The original always opened at 1:1, which on a 1200x750 level meant seeing
  /// about a third of it and scrolling blind for the exit.
  func fitToPlayfield() {
    let viewWidth = Double(Level.canvasWidth)
    let viewHeight = Double(Level.playfieldHeight)

    scale = min(viewWidth / Double(bgImage.width), viewHeight / Double(bgImage.height))

    // xoffset/yoffset are in level pixels — draw multiplies them by the scale —
    // so the centring margins are divided back out here.
    let drawnWidth = Double(bgImage.width) * scale
    let drawnHeight = Double(bgImage.height) * scale
    xoffset = Int((viewWidth - drawnWidth) / 2 / scale)
    yoffset = Int((Double(Level.statusHeight) + (viewHeight - drawnHeight) / 2) / scale)
  }

  // MARK: - Simulation

  func tick() {
    guard running, !isPaused else { return }

    currentTime = currentTimeMillis()
    difTime = currentTime - startTime

    frameCounter += 1
    releaseLemming()
    applyLodestoneFields()

    if levelTime - difTime <= 0 { running = false }
    if currCount == 0 && lemCount >= maxLem { running = false }
    if nuke && currCount == 0 { running = false }

    // Index-based with an unconditional increment, matching the original: a
    // lemming removed on this frame costs the next one its turn.
    var i = 0
    while i < lemmings.count {
      let lemming = lemmings[i]
      lemming.updateImage()

      if lemming.isExploder && fuseRemaining(lemming) <= 0 {
        lemming.explodeDie = true
      }

      if lemming.dead {
        lemmings.remove(at: i)
        currCount -= 1
      } else if lemming.exited() {
        lemmings.remove(at: i)
        saved += 1
        currCount -= 1
      }

      lemming.move()
      i += 1
    }

    updateBomblets()

    if let net {
      net.sendStats(
        released: lemCount, out: currCount, saved: saved, dead: lemCount - currCount, nuke: false)
    }
  }

  /// Drops in a new lemming once the release interval has elapsed.
  private func releaseLemming() {
    guard lemCount < maxLem, !nuke else { return }

    let interval = Int64(max(rrate, 1) * 100)
    guard newLem < difTime / interval else { return }

    newLem = difTime / interval
    let lemming = Lemming(x: xstrt, y: ystrt, mask: mask, level: bgImage)
    if speed { lemming.toggleSpeed() }
    lemmings.append(lemming)
    lemCount += 1
    currCount += 1
  }

  /// Seconds left on an exploder's fuse.
  private func fuseRemaining(_ lemming: Lemming) -> Int {
    max(0, 5 - Int((currentTime - lemming.explodeTime) / 1000))
  }

  // MARK: - Drawing

  func draw(_ g: Graphics) {
    let txoffset = Int(Double(xoffset) * scale)
    let tyoffset = Int(Double(yoffset) * scale)

    g.setFont(size: 12)
    g.setColor(AWTColor.blue)
    g.fillRect(0, 0, Level.canvasWidth, Level.canvasHeight)
    g.drawImage(
      bgImage, txoffset, tyoffset,
      Int(scale * Double(bgImage.width)), Int(scale * Double(bgImage.height)))

    drawLodestoneFields(g, txoffset, tyoffset)
    drawLemmings(g, txoffset, tyoffset)
    drawCluster(g, txoffset, tyoffset)
    drawMinimap(g, txoffset, tyoffset)
    drawToolbar(g)
    drawStatusBar(g)

    if showAbout { drawAbout(g) }
    if showHelp { drawHelp(g) }
  }

  /// The pulsing field around every planted Lodestone, drawn under the
  /// lemmings so they stay readable on top of it.
  private func drawLodestoneFields(_ g: Graphics, _ txoffset: Int, _ tyoffset: Int) {
    let pulse = frameCounter % 12
    for anchor in lemmings where anchor.isLodestone && !anchor.dead {
      let cx = Int(
        Double(anchor.xPos + anchor.curImage.width / 2) * scale + Double(txoffset))
      let cy = Int(
        Double(anchor.yPos + anchor.curImage.height / 2) * scale + Double(tyoffset))

      for step in 0..<3 {
        // Rings travel outward and fade as they go.
        let reach = (Level.lodestoneRadius * (pulse + step * 4)) / 12
        guard reach > 6 else { continue }
        let r = Int(Double(reach) * scale)
        g.setColor(step == 0 ? AWTColor.white : AWTColor.packed(0xFF4EA8D8))
        g.drawOval(cx - r, cy - r, r * 2, r * 2)
      }

      let edge = Int(Double(Level.lodestoneRadius) * scale)
      g.setColor(AWTColor.packed(0xFF2E6A9A))
      g.drawOval(cx - edge, cy - edge, edge * 2, edge * 2)
    }
  }

  private func drawLemmings(_ g: Graphics, _ txoffset: Int, _ tyoffset: Int) {
    var chosen = false

    for lemming in lemmings {
      let xtem = Int(Double(lemming.xPos) * scale + Double(txoffset))
      let ytem = Int(Double(lemming.yPos) * scale + Double(tyoffset))

      g.drawImage(
        lemming.curImage, xtem, ytem,
        Int(Double(lemming.curImage.width) * scale),
        Int(Double(lemming.curImage.height) * scale))

      if lemming.isExploder {
        g.setColor(AWTColor.red)
        g.drawString("\(fuseRemaining(lemming))", xtem + 15, ytem - 5)
      }

      // Outline the lemming under the cursor, so the player can see what a
      // click would land on.
      if !chosen && isChosen(xtem, ytem) {
        g.setColor(AWTColor.green)
        g.drawRect(xtem, ytem, Int(40 * scale), Int(40 * scale))
        chosen = true
      }
    }
  }

  /// The lodestone button: an anchored figure with field rings around it.
  private func drawLodestoneButton(_ g: Graphics, x: Int, y: Int, w: Int, h: Int) {
    g.setColor(AWTColor.packed(0xFF1E2A3A))
    g.fillRect(x, y, w, h)
    g.setColor(AWTColor.packed(0xFF5A7A9A))
    g.drawRect(x, y, w - 1, h - 1)

    let centreX = x + w / 2
    let centreY = y + 54
    for (index, ring) in [34, 24, 15].enumerated() {
      g.setColor(index == 0 ? AWTColor.packed(0xFF2E6A9A) : AWTColor.packed(0xFF4EA8D8))
      g.drawOval(centreX - ring, centreY - ring, ring * 2, ring * 2)
    }

    // The anchor itself.
    g.setColor(AWTColor.packed(0xFFF2D23A))
    g.fillOval(centreX - 10, centreY - 18, 20, 20)
    g.setColor(AWTColor.packed(0xFF1A1A1A))
    g.fillOval(centreX - 5, centreY - 12, 3, 3)
    g.fillOval(centreX + 2, centreY - 12, 3, 3)
    g.setColor(AWTColor.packed(0xFF4EA8D8))
    g.fillRect(centreX - 9, centreY + 2, 18, 14)
    g.setColor(AWTColor.packed(0xFFE8E8F0))
    g.fillRect(centreX - 14, centreY + 16, 28, 5)
  }

  /// Bomblets in flight, and the flashes where they landed.
  private func drawCluster(_ g: Graphics, _ txoffset: Int, _ tyoffset: Int) {
    for bomblet in bomblets {
      let sprite =
        bomblet.vx >= 0 ? Sprites.shared.fallingRight : Sprites.shared.fallingLeft
      let width = Int(Double(sprite.width) * scale)
      let height = Int(Double(sprite.height) * scale)
      let x = Int(bomblet.x * scale + Double(txoffset)) - width / 2
      let y = Int(bomblet.y * scale + Double(tyoffset)) - height / 2
      g.drawImage(sprite, x, y, width, height)
    }

    for blast in blasts {
      // Grows and cools over the few frames it lasts.
      let spread = blast.radius + (Blast.duration - blast.life) * 7
      let x = Int(Double(blast.x) * scale + Double(txoffset))
      let y = Int(Double(blast.y) * scale + Double(tyoffset))
      let outer = Int(Double(spread) * scale)
      let inner = outer / 2
      g.setColor(blast.life > Blast.duration / 2 ? AWTColor.white : AWTColor.orange)
      g.fillOval(x - outer, y - outer, outer * 2, outer * 2)
      g.setColor(AWTColor.yellow)
      g.fillOval(x - inner, y - inner, inner * 2, inner * 2)
    }
  }

  private func drawMinimap(_ g: Graphics, _ txoffset: Int, _ tyoffset: Int) {
    g.setColor(AWTColor.blue)
    g.fillRect(0, 490, Level.canvasWidth, 200)
    g.drawImage(mask, minimapX, minimapY, 100, minimapHeight)

    // The slice of the level currently on screen, clipped to the minimap: once
    // the whole level fits on screen this box is larger than the map itself.
    g.setColor(AWTColor.green)
    let boxX = Int(Double(minimapX) - Double(txoffset * 100) / scale / Double(mask.width))
    let boxY = Int(
      Double(minimapY) - Double((tyoffset - Level.statusHeight) * minimapHeight) / scale
        / Double(mask.height))
    let boxW = Int(Double(Level.canvasWidth) * 100.0 / scale / Double(mask.width))
    let boxH = Int(
      Double(Level.playfieldHeight) * Double(minimapHeight) / scale / Double(mask.height))
    let clampedX = min(max(boxX, minimapX), minimapX + 100)
    let clampedY = min(max(boxY, minimapY), minimapY + minimapHeight)
    g.drawRect(
      clampedX, clampedY,
      min(boxW, minimapX + 100 - clampedX),
      min(boxH, minimapY + minimapHeight - clampedY))

    g.setColor(AWTColor.yellow)
    for lemming in lemmings {
      g.fillOval(
        lemming.xPos * 100 / mask.width + minimapX,
        (lemming.yPos + 10) * minimapHeight / mask.height + minimapY,
        2, 2)
    }
  }

  private func drawToolbar(_ g: Graphics) {
    let top = Level.toolbarTop
    let slot = Level.slotWidth

    // toolbar.png holds ten buttons: the eight original abilities, then the
    // nuke and the rate control. The cluster button sits between those two
    // groups, so the artwork goes down either side of it in two pieces rather
    // than being stretched across a slot it has no button for.
    let art = buttons.cgImage
    let artButton = buttons.width / 10
    let drawn = 8  // how many of the ten art buttons are abilities
    if let head = art.cropping(
      to: CGRect(x: 0, y: 0, width: artButton * drawn, height: buttons.height))
    {
      g.drawImage(head, 0, top, slot * drawn, 100)
    }
    drawClusterButton(g, x: slot * Ability.cluster.slot, y: top, w: slot, h: 100)
    drawLodestoneButton(g, x: slot * Ability.lodestone.slot, y: top, w: slot, h: 100)
    if let tail = art.cropping(
      to: CGRect(x: artButton * drawn, y: 0, width: artButton * 2, height: buttons.height))
    {
      g.drawImage(tail, slot * Ability.allCases.count, top, slot * 2, 100)
    }

    // Yellow, because the original never reset the color after the minimap's
    // lemming dots and this box inherited it.
    if let selectedAbility {
      g.setColor(AWTColor.yellow)
      g.drawRect(selectedAbility.slot * slot, top, slot, 100)
    }

    // Uses remaining under each button; unavailable abilities are painted out.
    for ability in Ability.allCases {
      let x = ability.slot * slot
      let remaining = abilityCounts[ability.rawValue]
      if remaining == -1 {
        g.setColor(AWTColor.blue)
        g.fillRect(x, top, slot, 100)
        g.setColor(AWTColor.black)
        g.drawRect(x, top, slot, 100)
      } else {
        g.setColor(AWTColor.green)
        g.drawString(remaining == Ability.unlimited ? "oo" : "\(remaining)", x + 21, 590)
      }
    }
  }

  /// The cluster button, drawn rather than cut from toolbar.png: a lemming head
  /// with five duplicates fanning away from it.
  private func drawClusterButton(_ g: Graphics, x: Int, y: Int, w: Int, h: Int) {
    g.setColor(AWTColor.packed(0xFF2A2A3A))
    g.fillRect(x, y, w, h)
    g.setColor(AWTColor.packed(0xFF6A6A8A))
    g.drawRect(x, y, w - 1, h - 1)

    let centreX = x + w / 2
    let fan = [(-20, 30), (-11, 18), (0, 13), (11, 18), (20, 30)]
    for (dx, dy) in fan {
      g.setColor(AWTColor.packed(0xFFE8A23A))
      g.fillOval(centreX + dx - 5, y + dy - 5, 10, 10)
      g.setColor(AWTColor.packed(0xFFFFE07A))
      g.fillOval(centreX + dx - 2, y + dy - 2, 4, 4)
    }

    // The carrier.
    g.setColor(AWTColor.packed(0xFFF2D23A))
    g.fillOval(centreX - 11, y + 52, 22, 22)
    g.setColor(AWTColor.packed(0xFF1A1A1A))
    g.fillOval(centreX - 6, y + 59, 3, 3)
    g.fillOval(centreX + 3, y + 59, 3, 3)
    g.setColor(AWTColor.white)
    g.fillRect(centreX - 8, y + 74, 16, 12)
  }

  private func drawStatusBar(_ g: Graphics) {
    g.setColor(AWTColor.blue)
    g.fillRect(0, 0, Level.canvasWidth, 50)
    g.setColor(AWTColor.red)

    let remaining = (levelTime - difTime + 1000) / 1000
    g.drawString(" \(remaining / 60):\((remaining % 60) / 10)\((remaining % 60) % 10)", 750, 35)
    g.drawString("release rate: \(100 - rrate)", 10, 35)
    g.drawString("released: \(lemCount)", 150, 35)
    g.drawString("escaped %: \(maxLem > 0 ? saved * 100 / maxLem : 0)", 250, 35)
    g.drawString("in level: \(currCount)", 350, 35)
    g.setColor(AWTColor.green)
    g.drawString("|      help      |", 500, 35)
    g.drawString("|      about     |", 600, 35)

    // The opponent's numbers, on a green band under our own.
    if let net {
      let stats = net.opponent
      g.setColor(AWTColor.green)
      g.fillRect(0, 40, Level.canvasWidth, 30)
      g.setColor(AWTColor.red)
      g.drawString("released: \(stats.released)", 150, 60)
      g.drawString("saved: \(stats.saved)", 250, 60)
      g.drawString("in level: \(stats.out)", 350, 60)
      g.drawString("dead: \(stats.dead)", 450, 60)
    }
  }

  private func drawHelp(_ g: Graphics) {
    g.setColor(AWTColor.blue)
    g.fillRect(300, 50, 500, 340)
    g.setColor(AWTColor.red)

    let lines: [(String, Int)] = [
      ("Welcome to Lego Brand Lemmings!", 60),
      ("The goal of this game is to save all of the lemmings.", 90),
      ("The tool bar above includes information on how many lemmings have been saved,", 105),
      ("how many are left to save, and how much time is left to save them in.", 120),
      ("The tool bar at the bottom allows you to select abilities to give the lemmings,", 135),
      ("as well as the ability to increase their release rate and a mini-map of the level.", 150),
      ("To give a lemming an ability, select the ability, and then select the lemming you", 165),
      ("want to have that ability.", 180),
      ("Beware: you have a limited number of uses for each ability.", 195),
      ("Keys:", 220),
      ("'p' pauses/unpauses the game.", 235),
      ("'s' speeds up the rate of movement.", 250),
      ("'-'/'=' decrease/ increase the rate of release of the lemmings.", 265),
      ("the arrow keys, and the mouse scroll wheel*, scroll the level.", 280),
      ("'F1' / 'F2' zoom in and out ('z' / 'x' also work).", 295),
      ("'f' refits the whole level back into the window.", 310),
      ("*normally the level scrolls with the wheel, but by holding down the shift key,", 325),
      ("it instead scrolls left/right.", 340),
      ("hit 'p' to continue game.", 370),
    ]
    for (text, y) in lines {
      g.drawString(text, 305, y)
    }
  }

  private func drawAbout(_ g: Graphics) {
    g.setColor(AWTColor.blue)
    g.fillRect(500, 50, 300, 120)
    g.setColor(AWTColor.red)
    g.drawString("Lego Lemmings", 505, 60)
    g.drawString("Our Team Consists of:", 505, 80)

    let team = [
      ("Joseph Earle", "gtg210b", 95),
      ("Puyan Lotfi", "gtg945h", 110),
      ("David Figlar", "gtg247i", 125),
      ("Freddy Stroud", "gtgg833a", 140),
    ]
    for (name, id, y) in team {
      g.drawString(name, 505, y)
      g.drawString("--", 605, y)
      g.drawString(id, 655, y)
    }
    g.drawString("hit 'p' to continue game.", 505, 160)
  }

  // MARK: - Input

  func mouseClicked(x: Int, y: Int) {
    // Any click dismisses a pause (and with it the help/about overlays).
    if isPaused {
      setPaused(false)
      return
    }

    if y < 35 {
      if x > 500 && x < 600 {
        displayHelp()
      } else if x > 600 && x < 700 {
        displayAbout()
      }
    } else if y < 490 {
      assignAbility(atX: x, y: y)
    } else {
      toolbarClicked(x: x, y: y)
    }
  }

  /// Gives the selected ability to the first lemming under the click.
  private func assignAbility(atX x: Int, y: Int) {
    guard let ability = selectedAbility else { return }

    for lemming in lemmings {
      let lemX = Int(scale * Double(lemming.xPos) + scale * Double(xoffset))
      let lemY = Int(scale * Double(lemming.yPos) + scale * Double(yoffset))
      guard hitTest(x, y, lemX, lemY) else { continue }

      guard abilityCounts[ability.rawValue] > 0, !has(ability, lemming) else { break }
      apply(ability, to: lemming)
      spend(ability)
      break
    }
  }

  /// Docks one use, unless the ability has no limit.
  private func spend(_ ability: Ability) {
    guard abilityCounts[ability.rawValue] != Ability.unlimited else { return }
    abilityCounts[ability.rawValue] -= 1
  }

  private func has(_ ability: Ability, _ lemming: Lemming) -> Bool {
    switch ability {
    case .digger: return lemming.isDigger
    case .blocker: return lemming.isBlocker
    case .floater: return lemming.isFloater
    case .exploder: return lemming.isExploder
    case .bridger: return lemming.isBridger
    case .climber: return lemming.isClimber
    case .miner: return lemming.isMiner
    case .basher: return lemming.isBasher
    case .cluster: return lemming.isCluster
    case .lodestone: return lemming.isLodestone
    }
  }

  private func apply(_ ability: Ability, to lemming: Lemming) {
    switch ability {
    case .digger: lemming.isDigger = true
    case .blocker: lemming.isBlocker = true
    case .floater: lemming.isFloater = true
    case .exploder:
      lemming.isExploder = true
      lemming.explodeTime = currentTimeMillis()
    case .bridger: lemming.isBridger = true
    case .climber: lemming.isClimber = true
    case .miner: lemming.isMiner = true
    case .basher: lemming.isBasher = true
    case .cluster: releaseCluster(from: lemming)
    case .lodestone:
      lemming.isLodestone = true
      // Plants itself. The kernel reads `noDir` every frame, so the field
      // update below keeps re-asserting it rather than setting it once.
      lemming.noDir = true
    }
  }

  /// Applies every Lodestone's field to everyone else.
  ///
  /// This is the one ability that acts continuously on other lemmings, and the
  /// one that never expires — every other ability either completes (cluster),
  /// cancels itself when there is nothing to work on (basher, miner), or is a
  /// property of the lemming holding it (climber, floater).
  ///
  /// Two effects, both for as long as the anchor stands:
  ///
  /// - **Steering.** Anyone inside the field is turned to face the anchor, so a
  ///   scattered crowd walks itself back into one place.
  /// - **Cushioning.** Their fall counter is held at zero, so a drop that lands
  ///   inside a field is survivable however far it fell. The anchor doubles as
  ///   a crash mat under a long descent.
  ///
  /// Runs before the movement pass so the direction it sets is the direction
  /// the lemming actually walks this frame.
  private func applyLodestoneFields() {
    let anchors = lemmings.filter { $0.isLodestone && !$0.dead && !$0.dying }
    guard !anchors.isEmpty else { return }

    let radius = Level.lodestoneRadius
    for anchor in anchors {
      anchor.noDir = true
      let ax = anchor.xPos + anchor.curImage.width / 2
      let ay = anchor.yPos + anchor.curImage.height / 2

      for lemming in lemmings where lemming !== anchor && !lemming.dead && !lemming.dying {
        let lx = lemming.xPos + lemming.curImage.width / 2
        let ly = lemming.yPos + lemming.curImage.height / 2
        let dx = lx - ax
        let dy = ly - ay
        guard dx * dx + dy * dy <= radius * radius else { continue }

        // Caught by the field: it cannot be killed by the landing.
        lemming.resetFallCounter()
        lemming.fallDying = false

        // Blockers are holding a wall and other anchors are planted; neither
        // should be dragged off station.
        guard !lemming.isBlocker, !lemming.isLodestone, abs(dx) > Level.lodestoneDeadZone
        else { continue }
        lemming.rightDir = dx < 0
      }
    }
  }

  /// Bursts a lemming into `clusterCount` duplicates thrown clear in a fan.
  ///
  /// The carrier goes with them — this is the cost that keeps an ability with
  /// no use limit from simply deleting every level. Outer duplicates get more
  /// sideways and less lift, which spreads the craters along the ground
  /// instead of stacking them on one spot.
  private func releaseCluster(from lemming: Lemming) {
    lemming.isCluster = true

    let originX = Double(lemming.xPos + lemming.curImage.width / 2)
    let originY = Double(lemming.yPos + lemming.curImage.height / 2)

    // The fan is described by a normalized position across the spread rather
    // than by the raw index, so changing `clusterCount` makes the fan denser
    // instead of wider. Driving it off the index directly would have thrown the
    // outermost of fifteen sideways at 42px a frame, into the nearest wall.
    let centre = Double(Level.clusterCount - 1) / 2
    let spread = max(centre, 1)

    for index in 0..<Level.clusterCount {
      let position = (Double(index) - centre) / spread  // -1 (far left) ... 1
      bomblets.append(
        Bomblet(
          x: originX, y: originY,
          vx: position * Level.clusterSpeed,
          vy: -Level.clusterLift + abs(position) * 3.0,
          // Staggered a little so they do not all go off on the same frame,
          // but not by so much that the last ones hang in the air.
          fuse: 20 + (index % 5) * 2))
    }

    lemming.dying = true
  }

  /// Steps every bomblet, detonating the ones that have arrived.
  private func updateBomblets() {
    var index = 0
    while index < bomblets.count {
      let bomblet = bomblets[index]
      bomblet.advance()

      let hitTerrain =
        bomblet.age > Bomblet.armingDelay
        && !isColor(mask.getRGB(Int(bomblet.x), Int(bomblet.y)), Mask.black)
      let offLevel =
        bomblet.x < 0 || bomblet.x >= Double(mask.width) || bomblet.y >= Double(mask.height)

      if hitTerrain || offLevel || bomblet.fuse <= 0 {
        detonate(atX: Int(bomblet.x), y: Int(bomblet.y))
        bomblets.remove(at: index)
        continue
      }
      index += 1
    }

    for i in blasts.indices { blasts[i].life -= 1 }
    blasts.removeAll { $0.life <= 0 }
  }

  /// Blows a crater and kills whatever is standing in it.
  ///
  /// Only diggable terrain is removed. Rock, hazard and the exit survive, so a
  /// cluster can open a route through earth without being able to breach the
  /// level's indestructible frame or the pillars that pen a chamber — which,
  /// with unlimited uses, it otherwise would.
  private func detonate(atX x: Int, y: Int) {
    let radius = Level.blastRadius
    let sky = bgImage.getRGB(200, 200)

    for dy in -radius...radius {
      let py = y + dy
      guard py >= 0, py < mask.height else { continue }
      let span = Int(Double(radius * radius - dy * dy).squareRoot())
      for dx in -span...span {
        let px = x + dx
        guard px >= 0, px < mask.width else { continue }
        if isColor(mask.getRGB(px, py), Mask.red) {
          mask.setRGB(px, py, Mask.black)
          bgImage.setRGB(px, py, sky)
        }
      }
    }

    blasts.append(Blast(x: x, y: y, radius: radius, life: Blast.duration))

    let lethal = radius + 8
    for lemming in lemmings where !lemming.dead && !lemming.dying {
      let lx = lemming.xPos + lemming.curImage.width / 2
      let ly = lemming.yPos + lemming.curImage.height / 2
      if (lx - x) * (lx - x) + (ly - y) * (ly - y) <= lethal * lethal {
        lemming.dying = true
      }
    }
  }

  /// Slots 0-8 pick an ability, 9 nukes the level, 10 changes the release rate.
  private func toolbarClicked(x: Int, y: Int) {
    switch x / Level.slotWidth {
    case let slot where slot < Ability.allCases.count:
      selectedAbility = Ability(rawValue: slot)
    case Ability.allCases.count:
      for lemming in lemmings {
        lemming.isExploder = true
        lemming.explodeTime = currentTimeMillis()
      }
      nuke = true
    case Ability.allCases.count + 1:
      rateChange(y > 540 ? 1 : -1)
    default:
      break
    }
  }

  func keyDown(_ key: GameKey, shift: Bool) {
    if case .char(let raw) = key {
      switch Character(raw.lowercased()) {
      case "p":
        setPaused(!isPaused)
      case "s":
        for lemming in lemmings { lemming.toggleSpeed() }
        speed = !speed
      case "-":
        rateChange(1)
      case "=":
        rateChange(-1)
      // F1/F2 are usually claimed by macOS for screen brightness, so z/x zoom
      // as well.
      case "z":
        zoom(1.25)
      case "x":
        zoom(0.75)
      case "f":
        fitToPlayfield()
      default:
        break
      }
      return
    }

    switch key {
    case .f1:
      zoom(1.25)
    case .f2:
      zoom(0.75)
    case .up:
      yoffset += 5
    case .down:
      yoffset -= 5
    case .left:
      xoffset += Int(5 * scale)
    case .right:
      xoffset -= Int(5 * scale)
    default:
      break
    }
  }

  /// The wheel scrolls vertically, or horizontally with shift held.
  func scrollWheel(delta: Int, shift: Bool) {
    if shift {
      xoffset += Int(4 * scale * Double(delta))
    } else {
      yoffset += Int(4 * scale * Double(delta))
    }
  }

  func mouseMoved(x: Int, y: Int) {
    mouseX = x
    mouseY = y
  }

  /// Gives an ability to a lemming standing inside `rect`, as a player aiming
  /// at a room full of lemmings would. Returns false if nobody was there or the
  /// ability has run out.
  func debugGive(
    _ ability: Ability, inX x: Int, y: Int, w: Int, h: Int
  ) -> Bool {
    guard abilityCounts[ability.rawValue] != 0 else { return false }
    for lemming in lemmings where !lemming.dead {
      guard lemming.xPos >= x, lemming.xPos <= x + w,
        lemming.yPos >= y, lemming.yPos <= y + h,
        !has(ability, lemming)
      else { continue }
      // A basher cancels itself on the next frame unless there is already
      // something to chew on, so only hand it to a lemming facing a wall —
      // which is what a player clicking at the right moment does.
      if ability == .basher,
        !(lemming.climbable(lemming.rightDir) || lemming.bashable(lemming.rightDir, 7))
      {
        continue
      }
      apply(ability, to: lemming)
      spend(ability)
      return true
    }
    return false
  }

  /// Gives an ability to the first lemming, bypassing hit testing.
  func debugGive(_ ability: Ability) -> Bool {
    guard let lemming = lemmings.first, abilityCounts[ability.rawValue] != 0 else { return false }
    apply(ability, to: lemming)
    spend(ability)
    return true
  }

  // MARK: - Commands

  func setPaused(_ paused: Bool) {
    guard paused != isPaused else { return }
    if paused {
      pauseStart = currentTimeMillis()
    } else {
      // Don't charge the player for time spent paused.
      startTime += currentTimeMillis() - pauseStart
      showHelp = false
      showAbout = false
    }
    isPaused = paused
  }

  func displayHelp() {
    showHelp = true
    setPaused(true)
  }

  func displayAbout() {
    showAbout = true
    setPaused(true)
  }

  /// Adjusts the release delay, keeping it inside 1-99.
  func rateChange(_ amount: Int) {
    rrate = min(max(rrate + amount, 1), 99)
  }

  func zoom(_ multiplier: Double) {
    scale *= multiplier
  }

  /// Is this lemming under the mouse cursor?
  private func isChosen(_ x: Int, _ y: Int) -> Bool {
    hitTest(mouseX, mouseY, x, y)
  }

  private func hitTest(_ px: Int, _ py: Int, _ lemX: Int, _ lemY: Int) -> Bool {
    let size = Int(40 * scale)
    return px > lemX && px < lemX + size && py > lemY && py < lemY + size
  }
}
