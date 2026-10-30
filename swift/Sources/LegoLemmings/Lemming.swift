import CoreGraphics
import Foundation

/// One lemming.
///
/// A lemming carries two kinds of flags, and the distinction matters:
/// *attributes* (`isDigger`, `isClimber`, ...) are the abilities the player has
/// assigned and are permanent until the ability gives out, while *actions*
/// (`digging`, `climbing`, ...) say what the lemming is doing on this frame and
/// are recomputed constantly. The terrain is read and written through the two
/// shared bitmaps: `mask` for collision, `level` for the visible art.
final class Lemming {

  private let mask: Bitmap
  private let level: Bitmap
  private let sprites = Sprites.shared

  /// The frame currently being displayed. Its width and height feed most of
  /// the geometry below, which is why the 41x36 climb frames behave differently
  /// from the 36x41 walk frames.
  var curImage: Bitmap

  // MARK: Position

  var xPos: Int
  var yPos: Int

  /// Walking right when true. `noDir` pins the lemming in place (blockers, and
  /// the pause at the end of a bridge).
  var rightDir = true
  var noDir = false

  // MARK: Actions in progress

  /// Never set by the original: the kernel's call to `explode()` sat behind an
  /// `if (false)`. Kept because several animation branches test it.
  private var exploding = false
  var digging = false
  var blocking = false
  var mining = false
  var climbing = false
  var falling = false

  // MARK: Assigned abilities

  var isDigger = false
  var isBlocker = false
  var isExploder = false
  var isFloater = false
  var isBasher = false
  var isMiner = false
  var isClimber = false
  var isBridger = false
  /// Set when the lemming has been burst into a cluster, so the ability cannot
  /// be spent on it twice in the frames before it finishes dying.
  var isCluster = false

  /// Planted as a magnetic anchor. Unlike every other ability this one never
  /// clears itself — the field stays up for the rest of the level.
  var isLodestone = false

  // MARK: Death and exit

  var dead = false
  var dying = false
  /// Fell far enough that landing will be fatal.
  var fallDying = false
  /// The exploder's fuse has burned down.
  var explodeDie = false
  private var die1Shown = false
  private var die2Shown = false

  /// When the exploder was lit, in milliseconds; the fuse is five seconds.
  var explodeTime: Int64 = 0

  /// Holds the lemming still for a few frames after finishing a bridge.
  var bridgePause = false
  var pauseCounter = 0

  // MARK: Animation counters

  private var digCounter = 0
  private(set) var fallCounter = 0
  private var climbCounter = 0
  private var time: Int64 = 0

  /// Extra pixels per step while the player holds the game in fast mode.
  private(set) var speedUp = 0
  private var speed = false

  init(x: Int, y: Int, mask: Bitmap, level: Bitmap) {
    self.xPos = x
    self.yPos = y
    self.mask = mask
    self.level = level
    self.curImage = Sprites.shared.rightMid
  }

  // MARK: - Reading the mask around the lemming

  /// Mask color just past the lemming's right edge, at mid height.
  var rightUpColor: UInt32 {
    mask.getRGB(xPos + curImage.width, yPos + curImage.height / 2)
  }

  /// Mask color at the lemming's left edge, at mid height.
  var leftUpColor: UInt32 {
    mask.getRGB(xPos, yPos + curImage.height / 2)
  }

  /// Mask color at the lemming's bottom right, where its leading foot lands.
  var rightColor: UInt32 {
    mask.getRGB(xPos + curImage.width - 2, yPos + curImage.height - 2)
  }

  /// Mask color at the lemming's bottom left.
  var leftColor: UInt32 {
    mask.getRGB(xPos + 2, yPos + curImage.height - 2)
  }

  /// Mask color `offset` pixels below the lemming's feet.
  func bottomColor(_ offset: Int) -> UInt32 {
    mask.getRGB(xPos + curImage.width / 2, yPos + curImage.height + offset)
  }

  /// Mask color directly above the lemming's head.
  var topColor: UInt32 {
    mask.getRGB(xPos + curImage.width / 2, yPos)
  }

  /// The color the terrain art is repainted with where it gets carved away:
  /// the sky pixel at (200, 200) of the level art.
  private var skyColor: UInt32 {
    level.getRGB(200, 200)
  }

  // MARK: - Movement

  func move() {
    LiteKernel.move(self)
  }

  // MARK: - Animation

  /// Advances the animation one frame and picks `curImage`.
  ///
  /// The branches are ordered by priority: falling beats digging beats dying
  /// beats exploding beats blocking beats climbing beats walking. `timer` cycles
  /// 0-1-2 through each three-frame animation.
  func updateImage() {
    time += 1
    let timer = time % 3

    if dead { return }

    if falling && !isDigger && !exploding {
      if isFloater {
        fallCounter = 0
        curImage = sprites.floater
      } else {
        if timer == 0 { curImage = sprites.fallingRight }
        if timer == 1 { curImage = sprites.fallingLeft }
        if timer == 2 {
          curImage = fallCounter % 2 == 0 ? sprites.fallingRight : sprites.fallingLeft
        }
        fallCounter += 1
      }
      falling = false

    } else if isDigger && digging && !exploding {
      if timer == 0 { curImage = sprites.digRight }
      if timer == 1 { curImage = sprites.digLeft }
      if timer == 2 {
        curImage = digCounter % 2 == 0 ? sprites.digRight : sprites.digLeft
      }
      digCounter += 1
      digging = false

    } else if dying {
      advanceDeathAnimation(timer)

    } else if isExploder && explodeDie {
      advanceDeathAnimation(timer)
      if dead { blowHole() }

    } else if isBlocker && blocking {
      curImage = sprites.blocker

    } else if isClimber && climbing {
      if timer == 0 { curImage = rightDir ? sprites.rightMidClimb : sprites.leftMidClimb }
      if timer == 1 { curImage = rightDir ? sprites.rightFrontClimb : sprites.leftFrontClimb }
      if timer == 2 { curImage = rightDir ? sprites.rightBackClimb : sprites.leftBackClimb }

    } else {
      if timer == 0 { curImage = rightDir ? sprites.rightMid : sprites.leftMid }
      if timer == 1 { curImage = rightDir ? sprites.rightFront : sprites.leftFront }
      if timer == 2 { curImage = rightDir ? sprites.rightBack : sprites.leftBack }
    }
  }

  /// The three-frame death animation, gated so the frames always play in order
  /// however the 0-1-2 timer happens to line up.
  private func advanceDeathAnimation(_ timer: Int64) {
    if timer == 0 {
      curImage = sprites.die1
      die1Shown = true
    }
    if timer == 1 && die1Shown {
      curImage = sprites.die2
      die2Shown = true
    }
    if timer == 2 && die2Shown {
      curImage = sprites.die3
      dead = true
    }
  }

  /// Punches a 60px crater through terrain and art where the exploder died.
  private func blowHole() {
    let levelGraphics = level.createGraphics()
    let maskGraphics = mask.createGraphics()
    levelGraphics.setColor(AWTColor.packed(skyColor))
    maskGraphics.setColor(AWTColor.black)
    levelGraphics.fillOval(xPos - 2, yPos - 2, 60, 60)
    maskGraphics.fillOval(xPos - 2, yPos - 2, 60, 60)
  }

  // MARK: - Abilities

  /// Digs straight down, clearing three rows per frame.
  func dig() {
    let yOffset = curImage.height / 2
    guard isColor(bottomColor(0), Mask.red) else { return }

    digging = true
    for j in 0..<curImage.width {
      if !isColor(leftColor, Mask.red) || !isColor(rightColor, Mask.red) {
        for row in 0...2 {
          level.setRGB(xPos + j, yPos + 2 * yOffset + row, skyColor)
          mask.setRGB(xPos + j, yPos + 2 * yOffset + row, Mask.black)
        }
      } else {
        level.setRGB(xPos + j, yPos, skyColor)
        mask.setRGB(xPos + j, yPos, Mask.black)
      }
    }
  }

  /// Paints the lemming's own footprint green in the mask, which is what makes
  /// other lemmings turn around at it.
  func block() {
    guard !isColor(bottomColor(0), Mask.black) else { return }

    blocking = true
    for i in 0..<curImage.height {
      for j in 0..<curImage.width {
        mask.setRGB(xPos + j, yPos + i, Mask.green)
      }
    }
  }

  /// Is there a wall to climb on the given side?
  func climbable(_ towardRight: Bool) -> Bool {
    isColor(towardRight ? rightUpColor : leftUpColor, Mask.red)
  }

  /// Is there diggable terrain `bashLen` pixels ahead, at foot height?
  func bashable(_ towardRight: Bool, _ bashLen: Int) -> Bool {
    let wall =
      towardRight
      ? mask.getRGB(xPos + curImage.width + bashLen, yPos + curImage.height - 4)
      : mask.getRGB(xPos - bashLen, yPos + curImage.height - 4)
    return isColor(wall, Mask.red)
  }

  /// Climbs two pixels per frame, and steps over the lip on reaching the top.
  func climb(_ towardRight: Bool) {
    if !isColor(topColor, Mask.black) {
      // Ceiling: give up and drop.
      falling = true
      climbing = false
    } else if !climbable(towardRight) {
      // Topped out. Hop onto the ledge; the width/height swap of the climb
      // frames is what makes this land the lemming upright.
      let lift = (curImage.width - curImage.height) + 5
      xPos += towardRight ? (curImage.width + 8) : -(curImage.width + 8)
      yPos -= lift
      climbing = false
    } else {
      climbing = true
      yPos -= 2
    }
  }

  func explode() {
    exploding = true
  }

  func floatt() {
    curImage = sprites.floater
  }

  /// Chews sideways through terrain, clearing from half a body behind to a
  /// quarter of a body ahead.
  func bash(_ towardRight: Bool) {
    guard climbable(towardRight) || bashable(towardRight, 7) else {
      isBasher = false
      return
    }

    let width = curImage.width
    let height = curImage.height
    let sky = skyColor

    for i in (-(width / 2))...(width / 4) {
      for j in 0..<height {
        let x = towardRight ? xPos + width + i : xPos - i
        level.setRGB(x, yPos + j, sky)
        mask.setRGB(x, yPos + j, Mask.black)
      }
    }
  }

  /// Cuts a diagonal tunnel downward in the direction of travel.
  func mine() {
    let xOffset = curImage.width / 2
    let yOffset = curImage.height / 2

    guard isColor(bottomColor(0), Mask.red) else {
      isMiner = false
      return
    }

    mining = true
    let levelGraphics = level.createGraphics()
    let maskGraphics = mask.createGraphics()
    levelGraphics.setColor(AWTColor.packed(skyColor))
    maskGraphics.setColor(AWTColor.black)

    let cutX = rightDir ? xPos - xOffset + 10 : xPos + xOffset - 10
    levelGraphics.fillRect(cutX, yPos - 5, 20, yOffset * 2)
    maskGraphics.fillRect(cutX, yPos - 5, 20, yOffset * 2)

    xPos += rightDir ? 4 : -4
    yPos += 1
  }

  /// Lays bridge, half a body width per frame, for 32 frames.
  func bridge() {
    guard !climbable(rightDir), isColor(topColor, Mask.black) else { return }

    if climbCounter < 32 {
      let levelGraphics = level.createGraphics()
      let maskGraphics = mask.createGraphics()
      levelGraphics.setColor(AWTColor.orange)
      maskGraphics.setColor(AWTColor.red)

      let width = curImage.width
      let x = rightDir ? xPos + width / 2 : xPos
      let y = yPos + curImage.height - 4
      levelGraphics.fillRect(x, y, width / 2, 12)
      maskGraphics.fillRect(x, y, width / 2, 12)

      climbCounter += 1
    } else {
      climbCounter = 0
      bridgePause = true
      isBridger = false
    }
  }

  // MARK: - State queries

  /// True once the lemming has walked into the blue exit.
  func exited() -> Bool {
    isColor(leftUpColor, Mask.blue) || isColor(rightUpColor, Mask.blue)
  }

  func resetFallCounter() {
    fallCounter = 0
  }

  /// How far a lemming may fall before landing kills it.
  var dropLen: Int {
    level.height / 4
  }

  var canvasWidth: Int { level.width }
  var canvasHeight: Int { level.height }

  func toggleSpeed() {
    speed = !speed
    speedUp += speed ? 8 : -8
  }
}
