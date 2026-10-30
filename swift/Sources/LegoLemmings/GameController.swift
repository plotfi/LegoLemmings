import AppKit
import CoreGraphics
import Foundation

/// The whole game outside of a running level: the menus, the level chooser, the
/// multiplayer setup screens, and the between-level results.
///
/// This folds together the original `LemmingCanvas` (which drew each screen once
/// with `frame.getGraphics()` the moment it was entered) and `StartListener`
/// (which tracked which screen was showing with seven parallel booleans). AppKit
/// repaints on demand rather than letting a one-shot draw sit in the window, so
/// the screen is state here and `draw(_:)` renders whatever is current.
final class GameController {

  enum Screen {
    case title
    case chooseLevel
    case levelStats
    case playing
    case levelFinished
    case multiSetup
    case multiHost
    case multiClient
    case gameOver
    /// The side-scroller.
    case dash
    /// The first-person one.
    case doom
    /// The horde-defence one.
    case siege
  }

  private(set) var screen: Screen = .title
  private let chooser = LevelChooser()

  /// The level that will be played next, 0-based.
  private var nextLevel = 0
  /// The level highlighted on the chooser screen.
  private var chosenLevel = 0
  /// Which level's minimap to show, if any.
  private var previewLevel: Int?
  private var previewCache: [Int: Bitmap] = [:]

  private var level: Level?
  private var dash: Dash?
  private var doom: Doommings?
  private var siege: Siege?
  /// Counts 60Hz frames so the puzzle game still steps at its own 10Hz.
  private var frameDivider = 0
  private var net: NetPeer?

  // Results of the level just played, captured when it ends so that drawing
  // stays free of side effects (the original incremented the level counter from
  // inside its draw call).
  private var lastRescued = 0
  private var lastNeeded = 0
  private var lastMax = 0
  private var lastBeaten = false
  private var beatenLevelNumber = 0

  // Multiplayer setup fields.
  private var port = 0
  private var hostName = ""
  private var typingHost = false

  /// Set when the player asks to quit from the game-over screen.
  private(set) var wantsToQuit = false

  // MARK: - Frame

  /// Called 60 times a second by the view.
  ///
  /// The side-scroller wants every one of those frames. The puzzle game is
  /// built around a 10Hz step — its movement constants, release rates and fall
  /// distances are all tuned to it — so it still gets one step in six, and
  /// `tick()` stays exactly what it always was for the headless harnesses.
  func tickFrame() {
    if screen == .dash {
      dash?.tick()
      if dash?.wantsOut == true {
        dash = nil
        screen = .title
      }
      return
    }
    if screen == .doom {
      doom?.tick()
      if doom?.wantsOut == true {
        doom = nil
        screen = .title
      }
      return
    }
    if screen == .siege {
      siege?.tick()
      if siege?.wantsOut == true {
        siege = nil
        screen = .title
      }
      return
    }

    frameDivider += 1
    guard frameDivider >= 6 else { return }
    frameDivider = 0
    tick()
  }

  func tick() {
    guard screen == .playing, let level else { return }
    level.tick()
    if !level.running { levelDidFinish() }
  }

  private func levelDidFinish() {
    guard let level else { return }

    let data = chooser.levelData(nextLevel)
    lastRescued = level.saved
    lastNeeded = data.goal
    lastMax = data.count
    lastBeaten = lastRescued >= lastNeeded

    if lastBeaten {
      nextLevel += 1
      beatenLevelNumber = nextLevel
    }

    net?.close()
    net = nil
    self.level = nil
    screen = .levelFinished
  }

  // MARK: - Drawing

  func draw(_ g: Graphics) {
    switch screen {
    case .title: drawTitle(g)
    case .chooseLevel: drawChooseLevel(g)
    case .levelStats: drawLevelStats(g)
    case .playing: level?.draw(g)
    case .levelFinished: drawLevelFinished(g)
    case .multiSetup: drawMultiSetup(g)
    case .multiHost: drawMultiHost(g)
    case .multiClient: drawMultiClient(g)
    case .gameOver: drawGameOver(g)
    case .dash: dash?.draw(g)
    case .doom: doom?.draw(g)
    case .siege: siege?.draw(g)
    }
  }

  private func clear(_ g: Graphics) {
    g.setColor(AWTColor.blue)
    g.fillRect(0, 0, Level.canvasWidth, Level.canvasHeight)
    g.setColor(AWTColor.green)
  }

  private func drawTitle(_ g: Graphics) {
    clear(g)
    g.setFont(size: 20, bold: true)
    g.drawString("WELCOME TO LEGO LEMMINGS!!!!", 200, 100)
    g.setFont(size: 16)
    g.drawString("Start Game", 300, 250)
    g.drawString("Choose Level", 300, 350)
    g.drawString("MulitPlayer Game", 300, 450)
    g.drawRect(200, 200, 400, 100)
    g.drawRect(200, 300, 400, 100)
    g.drawRect(200, 400, 400, 100)

    // Three games that are not Lemmings at all. Two lines each at a smaller
    // size, because one line of label overflowed its box and ran into the next.
    g.setFont(size: 13)
    g.setColor(AWTColor.packed(0xFFF2D23A))
    g.drawString("LEMMING DASH", 251, 524)
    g.drawString("side-scroller", 256, 541)
    g.drawRect(200, 505, 190, 45)

    g.setColor(AWTColor.packed(0xFFE8663A))
    g.drawString("DOOMMINGS", 471, 524)
    g.drawString("first person", 470, 541)
    g.drawRect(410, 505, 190, 45)

    g.setColor(AWTColor.packed(0xFFE8563A))
    g.drawString("LEMMING SIEGE", 655, 524)
    g.drawString("horde defence", 657, 541)
    g.drawRect(610, 505, 180, 45)
  }

  private func drawChooseLevel(_ g: Graphics) {
    clear(g)
    g.setFont(size: 12)
    for i in 0..<chooser.levelCount {
      g.drawString(chooser.levelData(i).file, 100, 110 + 20 * i)
    }
    g.drawString("Load Level", 700, 500)
    g.drawRect(698, 485, 70, 20)
    drawPreview(g)
  }

  private func drawLevelStats(_ g: Graphics) {
    clear(g)
    let data = chooser.levelData(nextLevel)

    g.setFont(size: 20, bold: true)
    g.drawString("On To Level \(nextLevel + 1)", 300, 50)

    g.setFont(size: 14)
    for ability in Ability.allCases {
      g.drawString(
        "\(ability.displayName): \(data.usesLabel(ability))", 300,
        100 + 20 * ability.rawValue)
    }
    let percent = data.count > 0 ? data.goal * 100 / data.count : 0
    // Below the ten ability lines, which now run to y=280.
    g.drawString("% you need to save: \(percent)", 275, 308)
  }

  private func drawLevelFinished(_ g: Graphics) {
    clear(g)
    g.setFont(size: 12)
    let percent = lastMax > 0 ? lastRescued * 100 / lastMax : 0
    g.drawString("% Lemmings Saved: \(percent)", 300, 400)

    g.setFont(size: 24, bold: true)
    if lastBeaten {
      g.drawString("CONGRATULATIONS!!!", 200, 100)
      g.drawString("LEVEL \(beatenLevelNumber) BEATEN", 200, 200)
    } else {
      g.drawString("LEVEL FAILED", 200, 100)
    }
  }

  private func drawGameOver(_ g: Graphics) {
    clear(g)
    g.setFont(size: 20, bold: true)
    g.drawString("GAME OVER, MAN!!!", 300, 50)
    g.setFont(size: 14)
    g.drawString("You beat every level. Click to quit.", 300, 100)
  }

  private func drawMultiSetup(_ g: Graphics) {
    clear(g)
    g.setFont(size: 20, bold: true)
    g.drawString("Multi-Player Game", 300, 50)
    g.setFont(size: 18, bold: true)
    g.drawString("Please Select if you will be hosting or connecting.", 200, 100)
    g.setFont(size: 14)
    g.drawString("Hosting", 300, 200)
    g.drawString("Connecting", 300, 230)
    g.drawRect(298, 188, 54, 14)
    g.drawRect(298, 218, 84, 14)
  }

  private func drawMultiHost(_ g: Graphics) {
    clear(g)
    g.setFont(size: 20, bold: true)
    g.drawString("Multi-Player Game", 300, 50)
    g.setFont(size: 18, bold: true)
    g.drawString("Please Select Port Number and Level.", 200, 100)
    g.setFont(size: 14)
    g.drawString("PORT : \(port)", 250, 150)
    g.drawRect(248, 135, 100, 20)
    for i in 0..<chooser.levelCount {
      g.drawString(chooser.levelData(i).file, 250, 210 + 20 * i)
    }
    g.drawString("Start", 700, 500)
    g.drawRect(675, 450, 75, 100)
    drawPreview(g)
  }

  private func drawMultiClient(_ g: Graphics) {
    clear(g)
    g.setFont(size: 20, bold: true)
    g.drawString("Multi-Player Game", 300, 50)
    g.setFont(size: 18, bold: true)
    g.drawString("Please Select Port Number and Level.", 200, 100)
    g.setFont(size: 14)
    g.drawString("PORT : \(port)", 250, 150)
    g.drawString("HOST: \(hostName)", 250, 200)
    g.drawRect(248, 135, 100, 20)
    g.drawRect(248, 185, 300, 20)
    // Caret hint: which field typing goes into.
    g.drawString(typingHost ? "<- typing host (enter to finish)" : "<- typing port (enter for host)",
                 560, typingHost ? 200 : 150)
    for i in 0..<chooser.levelCount {
      g.drawString(chooser.levelData(i).file, 50, 210 + 20 * i)
    }
    g.drawString("Start", 700, 500)
    g.drawRect(675, 450, 75, 100)
    drawPreview(g)
  }

  /// The selected level's art, shrunk into a thumbnail. Decoded once per level
  /// and kept, since this runs on every repaint.
  private func drawPreview(_ g: Graphics) {
    guard let previewLevel, previewLevel < chooser.levelCount else { return }

    if previewCache[previewLevel] == nil {
      let name = chooser.levelData(previewLevel).file
      guard let miniMap = Bitmap(contentsOf: Assets.url("\(name).png")) else {
        FileHandle.standardError.write(Data("Error: level not found: \(name).png\n".utf8))
        return
      }
      previewCache[previewLevel] = miniMap
    }

    if let miniMap = previewCache[previewLevel] {
      g.drawImage(miniMap, 250, 350, 400, 200)
    }
  }

  // MARK: - Input

  func mouseClicked(x: Int, y: Int) {
    switch screen {
    case .playing:
      level?.mouseClicked(x: x, y: y)

    case .title:
      // The bottom row runs the full width of the screen, so it is tested
      // before the original three — whose x guard, written when they were the
      // only buttons, stops at 600 and swallowed everything to the right of it.
      if y > 505 && y < 550 {
        if x > 200 && x < 390 {
          startDash(levelIndex: 0)
        } else if x > 410 && x < 600 {
          startDoom(levelIndex: 0)
        } else if x > 610 && x < 790 {
          startSiege()
        }
        return
      }

      guard x > 200, x < 600 else { return }
      if y > 200 && y < 300 {
        showLevelStats(0)
      } else if y > 300 && y < 400 {
        previewLevel = nil
        screen = .chooseLevel
      } else if y > 400 && y < 500 {
        screen = .multiSetup
      }

    case .chooseLevel:
      if x > 100 && x < 200 {
        selectLevel((y - 100) / 20)
      }
      if x > 698 && x < 768 && y > 485 && y < 505 {
        showLevelStats(chosenLevel)
      }

    case .levelStats:
      startLevel(nextLevel)

    case .levelFinished:
      showLevelStats(nextLevel)

    case .multiSetup:
      if x > 298 && x < 352 && y > 188 && y < 202 {
        screen = .multiHost
      } else if x > 298 && x < 382 && y > 218 && y < 232 {
        screen = .multiClient
      }

    case .multiHost:
      if x > 250 && x < 350 {
        selectLevel((y - 200) / 20)
      }
      if x > 675 && x < 750 && y > 450 && y < 550 {
        startMultiPlayerHost()
      }

    case .multiClient:
      if x > 50 && x < 150 {
        selectLevel((y - 200) / 20)
      }
      if x > 675 && x < 750 && y > 450 && y < 550 {
        startMultiPlayerClient()
      }

    case .gameOver:
      wantsToQuit = true

    case .dash, .doom, .siege:
      break
    }
  }

  /// Pressing and releasing are separate for the siege, which fires while the
  /// button is held. Menus still act on release, as they always did.
  func mouseDown(x: Int, y: Int) {
    if screen == .siege {
      siege?.mouseDown(atX: x, y: y)
    }
  }

  func mouseUp(x: Int, y: Int) {
    if screen == .siege {
      siege?.mouseUp(atX: x, y: y)
      return
    }
    mouseClicked(x: x, y: y)
  }

  func rightMouseDown(x: Int, y: Int) {
    if screen == .siege { siege?.rightMouseDown(atX: x, y: y) }
  }

  func rightMouseUp(x: Int, y: Int) {
    if screen == .siege { siege?.rightMouseUp(atX: x, y: y) }
  }

  func keyUp(_ key: GameKey) {
    if screen == .dash { dash?.keyUp(key) }
    if screen == .doom { doom?.keyUp(key) }
    if screen == .siege { siege?.keyUp(key) }
  }

  func keyDown(_ key: GameKey, shift: Bool) {
    switch screen {
    case .dash:
      dash?.keyDown(key)

    case .doom:
      doom?.keyDown(key)

    case .siege:
      siege?.keyDown(key)

    case .playing:
      level?.keyDown(key, shift: shift)
    case .multiHost:
      editPort(key)
    case .multiClient:
      typingHost ? editHost(key) : editPort(key)
    default:
      break
    }
  }

  /// Digits build up the port number; enter moves on to the host field.
  ///
  /// The original tested `temchar > VK_0 && temchar < VK_9`, which quietly
  /// rejected the digits 0 and 9 and made most port numbers untypable. All ten
  /// digits are accepted here.
  private func editPort(_ key: GameKey) {
    switch key {
    case .char(let c) where c.isNumber:
      port = port * 10 + Int(String(c))!
      if port > 65535 { port = 65535 }
    case .backspace:
      port /= 10
    case .enter:
      typingHost = true
    default:
      break
    }
  }

  private func editHost(_ key: GameKey) {
    switch key {
    case .enter:
      typingHost = false
    case .backspace:
      if !hostName.isEmpty { hostName.removeLast() }
    case .char(let c):
      hostName.append(c)
    default:
      break
    }
  }

  func scrollWheel(delta: Int, shift: Bool) {
    guard screen == .playing else { return }
    level?.scrollWheel(delta: delta, shift: shift)
  }

  func mouseMoved(x: Int, y: Int) {
    if screen == .siege {
      siege?.aim(atX: x, y: y)
      return
    }
    guard screen == .playing else { return }
    level?.mouseMoved(x: x, y: y)
  }

  // MARK: - Transitions

  private func selectLevel(_ index: Int) {
    guard index >= 0, index < chooser.levelCount else { return }
    chosenLevel = index
    previewLevel = index
  }

  /// Shows the pre-level briefing, or the end of the game if there is no level
  /// left to brief.
  private func showLevelStats(_ index: Int) {
    guard index < chooser.levelCount else {
      screen = .gameOver
      return
    }
    nextLevel = index
    previewLevel = nil
    screen = .levelStats
  }

  private func startLevel(_ index: Int) {
    level = Level(data: chooser.levelData(index), net: nil)
    screen = .playing
  }

  // MARK: - Debug

  /// Jumps straight into a level, skipping the menus. Used by `--smoke`.
  func debugStartLevel(_ index: Int) {
    nextLevel = index
    startLevel(index)
  }

  var debugLevelRunning: Bool { screen == .playing }

  var debugSummary: String { level?.summary ?? "screen=\(screen)" }

  /// Hands the named ability to the first lemming in the level, so the headless
  /// run can exercise the terrain-carving code paths.
  func debugGive(_ ability: Ability) -> Bool {
    level?.debugGive(ability) ?? false
  }

  /// Plays one step of a level's intended solution: hands `ability` to a
  /// lemming waiting in the room the generator marked as that gate.
  func debugGive(_ ability: Ability, inX x: Int, y: Int, w: Int, h: Int) -> Bool {
    level?.debugGive(ability, inX: x, y: y, w: w, h: h) ?? false
  }

  var debugCounts: (released: Int, saved: Int, inLevel: Int) {
    level?.debugCounts ?? (0, 0, 0)
  }

  /// The result of the level just finished. `debugCounts` goes to zero once a
  /// level ends, because the level object is released; this survives.
  var debugLastResult: (rescued: Int, needed: Int, max: Int) {
    (lastRescued, lastNeeded, lastMax)
  }

  var debugPositions: [(x: Int, y: Int, state: String)] { level?.debugPositions ?? [] }

  var debugClusterState: (inFlight: Int, blasts: Int) {
    level?.debugClusterState ?? (0, 0)
  }

  func debugDirtPixels() -> Int { level?.debugDirtPixels() ?? 0 }

  @discardableResult
  func debugPlantLodestone(nearX x: Int, y: Int) -> Bool {
    level?.debugPlantLodestone(nearX: x, y: y) ?? false
  }

  var debugLodestones: [(x: Int, y: Int, caught: Int)] { level?.debugLodestones ?? [] }

  var debugMeanDistanceToAnchor: (count: Int, mean: Double)? {
    level?.debugMeanDistanceToAnchor
  }

  func debugRockPixels() -> Int { level?.debugRockPixels() ?? 0 }

  var debugLevelCount: Int { chooser.levelCount }

  func debugLevelData(_ index: Int) -> LevelData { chooser.levelData(index) }

  /// Drops into the side-scroller.
  func startDash(levelIndex: Int) {
    dash = Dash(chooser: chooser, levelIndex: min(levelIndex, chooser.levelCount - 1))
    screen = .dash
  }

  /// Drops into the first-person game.
  func startDoom(levelIndex: Int) {
    doom = Doommings(chooser: chooser, levelIndex: min(levelIndex, chooser.levelCount - 1))
    screen = .doom
  }

  /// Drops into the horde-defence game, backed by a suitably grim level.
  func startSiege(wave: Int = 1) {
    let backdrop =
      (0..<chooser.levelCount).first { chooser.levelData($0).file == "haunted" } ?? 0
    siege = Siege(chooser: chooser, backdropIndex: backdrop, startWave: wave)
    screen = .siege
  }

  /// Which screen is showing, for testing navigation.
  var debugScreen: String { "\(screen)" }

  func debugGoToTitle() {
    dash = nil
    doom = nil
    siege = nil
    level = nil
    screen = .title
  }

  var debugDash: Dash? { dash }
  var debugSiege: Siege? { siege }
  var debugDoom: Doommings? { doom }

  private func startMultiPlayerHost() {
    guard let peer = NetPeer(hostingOn: port) else { return }
    net = peer
    nextLevel = chosenLevel
    level = Level(data: chooser.levelData(nextLevel), net: peer)
    screen = .playing
  }

  private func startMultiPlayerClient() {
    guard let peer = NetPeer(connectingTo: hostName, port: port) else { return }
    net = peer
    nextLevel = chosenLevel
    level = Level(data: chooser.levelData(nextLevel), net: peer)
    screen = .playing
  }
}
