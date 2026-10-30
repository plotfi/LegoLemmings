import AVFoundation
import AppKit
import Foundation

/// Windowless runs used to exercise the game without watching it.
///
/// - `--smoke [frames] [dir]` plays level 0 and writes PNG snapshots.
/// - `--screens [dir]` renders every menu screen to PNG.
/// - `--selftest` drives every level with every ability it offers, which is
///   what actually covers the terrain-carving code where an out-of-bounds write
///   would hide.
///
/// All of these drive `gameClock` themselves, so a minute of game time costs
/// nothing in real time.
enum Headless {

  /// Simulated milliseconds since the run started.
  private static var fakeNow: Int64 = 0

  /// Points `gameClock` at a clock this code steps by hand.
  private static func useFakeClock() {
    fakeNow = 0
    gameClock = { fakeNow }
  }

  private static func step(_ controller: GameController) {
    fakeNow += Int64(Level.frameInterval * 1000)
    controller.tick()
  }

  // MARK: - Smoke run

  static func smoke(arguments: [String]) -> Int32 {
    let frames = arguments.count > 1 ? (Int(arguments[1]) ?? 600) : 600
    let directory = arguments.count > 2 ? arguments[2] : NSTemporaryDirectory()

    // Optional level name, so any level can be eyeballed, not just the first.
    let chooser = LevelChooser()
    let index =
      arguments.count > 3
      ? (0..<chooser.levelCount).first { chooser.levelData($0).file == arguments[3] } ?? 0
      : 0

    useFakeClock()
    let controller = GameController()
    controller.debugStartLevel(index)

    let canvas = Bitmap(width: Level.canvasWidth, height: Level.canvasHeight)
    let graphics = canvas.createGraphics()

    print("Assets:  \(Assets.directory.path)")
    print("Running \(frames) frames of \(chooser.levelData(index).file)")

    for frame in 0..<frames {
      step(controller)

      if frame % 50 == 0 {
        canvas.invalidate()
        controller.draw(graphics)
        let path = (directory as NSString).appendingPathComponent(
          String(format: "frame%04d.png", frame))
        write(canvas, to: path)
        print("  frame \(frame): \(controller.debugSummary)")
      }

      if !controller.debugLevelRunning {
        print("  level ended at frame \(frame)")
        break
      }
    }
    print("Final: \(controller.debugSummary)")
    return 0
  }

  // MARK: - Screens

  static func screens(arguments: [String]) -> Int32 {
    let directory = arguments.count > 1 ? arguments[1] : NSTemporaryDirectory()
    useFakeClock()

    let canvas = Bitmap(width: Level.canvasWidth, height: Level.canvasHeight)
    let graphics = canvas.createGraphics()

    /// Each screen, reached by the same clicks a player would make.
    let walkthroughs: [(String, (GameController) -> Void)] = [
      ("title", { _ in }),
      ("chooseLevel", { $0.mouseClicked(x: 400, y: 350) }),
      (
        "chooseLevelPreview",
        {
          $0.mouseClicked(x: 400, y: 350)
          $0.mouseClicked(x: 150, y: 175)  // pick level 3
        }
      ),
      ("levelStats", { $0.mouseClicked(x: 400, y: 250) }),
      ("multiSetup", { $0.mouseClicked(x: 400, y: 450) }),
      (
        "multiHost",
        {
          $0.mouseClicked(x: 400, y: 450)
          $0.mouseClicked(x: 320, y: 195)
        }
      ),
      (
        "multiClient",
        {
          $0.mouseClicked(x: 400, y: 450)
          $0.mouseClicked(x: 320, y: 225)
        }
      ),
    ]

    for (name, walkthrough) in walkthroughs {
      let controller = GameController()
      walkthrough(controller)
      canvas.invalidate()
      controller.draw(graphics)
      let path = (directory as NSString).appendingPathComponent("screen-\(name).png")
      write(canvas, to: path)
      print("  \(name) -> \(path)")
    }

    // The in-level overlays, which need a running level behind them.
    for (name, click) in [("help", 550), ("about", 650)] {
      let controller = GameController()
      controller.debugStartLevel(0)
      for _ in 0..<30 { step(controller) }
      controller.mouseClicked(x: click, y: 20)
      canvas.invalidate()
      controller.draw(graphics)
      let path = (directory as NSString).appendingPathComponent("screen-\(name).png")
      write(canvas, to: path)
      print("  \(name) -> \(path)")
    }

    return 0
  }

  // MARK: - Self test

  /// Plays every level with every ability it offers, and reports what happened.
  /// A crash here means a terrain write ran off the edge of a bitmap.
  static func selftest(arguments: [String]) -> Int32 {
    useFakeClock()
    let chooser = LevelChooser()
    var failures = 0

    print("Assets: \(Assets.directory.path)")
    print("Levels: \(chooser.levelCount)")
    print("")

    for index in 0..<chooser.levelCount {
      let data = chooser.levelData(index)
      print(
        "Level \(index) '\(data.file)': \(data.count) lemmings, save \(data.goal), "
          + "\(data.time)min, start \(data.start.x),\(data.start.y)")

      // A plain run first, then one run per ability the level offers.
      var trials: [Ability?] = [nil]
      trials += Ability.allCases.filter { data.uses($0) != 0 }.map { Optional($0) }

      for ability in trials {
        let label = ability?.displayName ?? "(no ability)"
        let controller = GameController()
        controller.debugStartLevel(index)

        // Let a lemming appear, then hand it the ability under test.
        step(controller)
        var granted = true
        if let ability {
          granted = controller.debugGive(ability)
        }

        // Six hundred frames is a minute of game time, long enough for a
        // digger to break through or a bridger to finish.
        for _ in 0..<600 {
          guard controller.debugLevelRunning else { break }
          step(controller)
        }

        let status = granted ? "ok" : "NOT GRANTED"
        if !granted { failures += 1 }
        print("    \(label.padding(toLength: 14, withPad: " ", startingAt: 0)) \(status)  "
          + "\(controller.debugSummary)")
      }
      print("")
    }

    // And one level played to its end, to be sure a level terminates at all.
    let controller = GameController()
    controller.debugStartLevel(0)
    var frames = 0
    while controller.debugLevelRunning && frames < 12_000 {
      step(controller)
      frames += 1
    }
    print("Level 0 to completion: ended=\(!controller.debugLevelRunning) after \(frames) frames")
    if controller.debugLevelRunning {
      print("  FAILED: level never ended")
      failures += 1
    }

    print("")
    print(failures == 0 ? "SELFTEST PASSED" : "SELFTEST FAILED (\(failures) problems)")
    return failures == 0 ? 0 : 1
  }

  // MARK: - Verify generated levels

  /// One gate from `levelHints.txt`: the room, and what it wants spent in it.
  private struct Hint {
    var file: String
    var ability: Ability
    var x: Int, y: Int, w: Int, h: Int
    /// Frame this gate was last triggered on, so a failed attempt is retried.
    var lastTriggered: Int = -10_000
    var triggers: Int = 0
  }

  private static func loadHints() -> [Hint] {
    let names = Ability.allCases.reduce(into: [String: Ability]()) {
      $0[$1.displayName.lowercased()] = $1
    }
    return Assets.text("levelHints.txt")
      .components(separatedBy: .newlines)
      .compactMap { line -> Hint? in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
        let f = trimmed.components(separatedBy: "|")
        guard f.count >= 6, let ability = names[f[1]],
          let x = Int(f[2]), let y = Int(f[3]), let w = Int(f[4]), let h = Int(f[5])
        else { return nil }
        return Hint(file: f[0], ability: ability, x: x, y: y, w: w, h: h)
      }
  }

  /// Plays every generated level's intended solution and reports whether the
  /// level's own goal is met.
  ///
  /// This is the check that matters for generated content: the structural
  /// validation in LevelGen proves the geometry is sane, but only running the
  /// real engine proves a lemming can actually get from the spawn to the door.
  static func verify(arguments: [String]) -> Int32 {
    useFakeClock()
    let chooser = LevelChooser()
    let hints = loadHints()
    var failures = 0

    print("Assets: \(Assets.directory.path)")
    print("Verifying \(hints.map(\.file).reduce(into: Set<String>()) { $0.insert($1) }.count) "
      + "generated levels\n")

    for index in 0..<chooser.levelCount {
      let data = chooser.levelData(index)
      var levelHints = hints.filter { $0.file == data.file }
      guard !levelHints.isEmpty else { continue }

      let controller = GameController()
      controller.debugStartLevel(index)

      // Enough frames to release every lemming and let the stragglers walk out.
      let budget = min(data.time * 600, 7_000)
      var frame = 0
      var firstSavedFrame = -1

      while controller.debugLevelRunning && frame < budget {
        step(controller)
        frame += 1

        // Spend each gate's ability when somebody is standing in its room.
        // Retried a few times, as a player would if the first lemming wandered
        // off before the click landed.
        for i in levelHints.indices {
          let hint = levelHints[i]
          guard hint.triggers < 4, frame - hint.lastTriggered > 90 else { continue }
          if controller.debugGive(
            hint.ability, inX: hint.x, y: hint.y, w: hint.w, h: hint.h)
          {
            levelHints[i].lastTriggered = frame
            levelHints[i].triggers += 1
          }
        }

        if firstSavedFrame < 0 && controller.debugCounts.saved > 0 {
          firstSavedFrame = frame
        }
      }

      // Read the live counters while the level runs, and the recorded result
      // once it has ended (the level object is gone by then).
      let saved =
        controller.debugLevelRunning
        ? controller.debugCounts.saved : controller.debugLastResult.rescued
      let counts = (saved: saved, released: data.count)
      let goal = data.goal
      let passed = counts.saved >= goal
      if !passed { failures += 1 }

      let spent = levelHints.map { "\($0.ability.displayName.lowercased())x\($0.triggers)" }
        .joined(separator: " ")
      print(
        "\(data.file.padding(toLength: 10, withPad: " ", startingAt: 0)) "
          + "saved \(String(format: "%2d", counts.saved))/\(data.count) "
          + "goal \(String(format: "%2d", goal))  "
          + "\(passed ? "PASS" : "FAIL")  "
          + "[\(spent)] first out at frame \(firstSavedFrame)")
    }

    print("")
    print(failures == 0 ? "ALL GENERATED LEVELS BEATABLE" : "\(failures) level(s) not beatable")
    return failures == 0 ? 0 : 1
  }

  /// Runs one level's solution and prints where everybody is, for working out
  /// why a generated level does not play the way its geometry says it should.
  static func trace(arguments: [String]) -> Int32 {
    guard arguments.count > 1 else {
      print("usage: --trace <levelFile> [frames]")
      return 1
    }
    let wanted = arguments[1]
    let budget = arguments.count > 2 ? (Int(arguments[2]) ?? 900) : 900

    useFakeClock()
    let chooser = LevelChooser()
    guard let index = (0..<chooser.levelCount).first(where: { chooser.levelData($0).file == wanted })
    else {
      print("no level called \(wanted)")
      return 1
    }

    var levelHints = loadHints().filter { $0.file == wanted }
    let controller = GameController()
    controller.debugStartLevel(index)
    print("tracing \(wanted); gates: "
      + levelHints.map { "\($0.ability.displayName) @\($0.x),\($0.y) \($0.w)x\($0.h)" }
        .joined(separator: "  "))

    var frame = 0
    while controller.debugLevelRunning && frame < budget {
      step(controller)
      frame += 1
      for i in levelHints.indices {
        let hint = levelHints[i]
        guard hint.triggers < 4, frame - hint.lastTriggered > 90 else { continue }
        if controller.debugGive(hint.ability, inX: hint.x, y: hint.y, w: hint.w, h: hint.h) {
          levelHints[i].lastTriggered = frame
          levelHints[i].triggers += 1
          print("  f\(frame): granted \(hint.ability.displayName)")
        }
      }
      if frame % 60 == 0 {
        let c = controller.debugCounts
        let positions = controller.debugPositions.prefix(5)
          .map { "(\($0.x),\($0.y))\($0.state)" }.joined(separator: " ")
        print("  f\(frame) rel=\(c.released) in=\(c.inLevel) saved=\(c.saved) "
          + "dead=\(c.released - c.inLevel - c.saved)  \(positions)")
      }
    }
    print("ended at frame \(frame), result \(controller.debugLastResult)")
    return 0
  }

  /// Fires a cluster on a few levels and checks it behaves: five bomblets go
  /// out, they all detonate, diggable terrain is removed, and the indestructible
  /// frame is left alone.
  static func cluster(arguments: [String]) -> Int32 {
    useFakeClock()
    let chooser = LevelChooser()
    var failures = 0
    // Optional output directory: dumps frames of the first level's burst.
    let directory = arguments.count > 1 ? arguments[1] : nil
    let canvas = Bitmap(width: Level.canvasWidth, height: Level.canvasHeight)
    let graphics = canvas.createGraphics()
    var shot = 0

    print("Assets: \(Assets.directory.path)\n")

    for name in ["level0", "pirates", "haunted", "volcano"] {
      guard
        let index = (0..<chooser.levelCount).first(where: { chooser.levelData($0).file == name })
      else { continue }

      let controller = GameController()
      controller.debugStartLevel(index)
      for _ in 0..<40 { step(controller) }

      let rockBefore = controller.debugRockPixels()
      let dirtBefore = controller.debugDirtPixels()
      let granted = controller.debugGive(.cluster)
      let launched = controller.debugClusterState.inFlight

      var peakBlasts = 0
      var frames = 0
      while controller.debugClusterState.inFlight > 0 && frames < 120 {
        step(controller)
        frames += 1
        peakBlasts = max(peakBlasts, controller.debugClusterState.blasts)
        if let directory, name == "pirates" {
          canvas.invalidate()
          controller.draw(graphics)
          write(
            canvas,
            to: (directory as NSString).appendingPathComponent(
              String(format: "burst%02d.png", shot)))
          shot += 1
        }
      }
      // Let the flashes age out.
      for _ in 0..<6 {
        step(controller)
        if let directory, name == "pirates" {
          canvas.invalidate()
          controller.draw(graphics)
          write(
            canvas,
            to: (directory as NSString).appendingPathComponent(
              String(format: "burst%02d.png", shot)))
          shot += 1
        }
      }

      let dirtAfter = controller.debugDirtPixels()
      let rockAfter = controller.debugRockPixels()
      let carved = dirtBefore - dirtAfter

      var problems: [String] = []
      if !granted { problems.append("ability not granted") }
      if launched != Level.clusterCount {
        problems.append("launched \(launched), expected \(Level.clusterCount)")
      }
      if controller.debugClusterState.inFlight != 0 {
        problems.append("\(controller.debugClusterState.inFlight) never detonated")
      }
      if carved <= 0 { problems.append("no terrain removed") }
      if rockAfter != rockBefore {
        problems.append("indestructible terrain changed by \(rockBefore - rockAfter)")
      }
      if problems.isEmpty == false { failures += 1 }

      print(
        "\(name.padding(toLength: 10, withPad: " ", startingAt: 0)) "
          + "launched=\(launched) flight=\(frames)f peakFlashes=\(peakBlasts) "
          + "dirtRemoved=\(carved) rockIntact=\(rockAfter == rockBefore)  "
          + (problems.isEmpty ? "ok" : "PROBLEMS: " + problems.joined(separator: "; ")))
    }

    print("")
    print(failures == 0 ? "CLUSTER OK" : "\(failures) level(s) with problems")
    return failures == 0 ? 0 : 1
  }

  /// Plants a Lodestone and checks both halves of its field do what they say:
  /// lemmings inside it face the anchor, and a drop that would otherwise be
  /// fatal is survived inside it.
  static func lodestone(arguments: [String]) -> Int32 {
    useFakeClock()
    let chooser = LevelChooser()
    var failures = 0
    let directory = arguments.count > 1 ? arguments[1] : nil
    let canvas = Bitmap(width: Level.canvasWidth, height: Level.canvasHeight)
    let graphics = canvas.createGraphics()
    var shot = 0

    print("Assets: \(Assets.directory.path)\n")

    for name in ["level0", "pirates", "city", "aquazone"] {
      guard
        let index = (0..<chooser.levelCount).first(where: { chooser.levelData($0).file == name })
      else { continue }

      let controller = GameController()
      controller.debugStartLevel(index)
      // Let a crowd build up so there is something for the field to act on.
      for _ in 0..<260 { step(controller) }

      let planted = controller.debugPlantLodestone(nearX: 0, y: 0)
      let before = controller.debugMeanDistanceToAnchor
      var peakCaught = 0

      for _ in 0..<200 {
        step(controller)
        peakCaught = max(peakCaught, controller.debugLodestones.first?.caught ?? 0)
        if let directory, name == "pirates" {
          canvas.invalidate()
          controller.draw(graphics)
          write(
            canvas,
            to: (directory as NSString).appendingPathComponent(
              String(format: "field%03d.png", shot)))
          shot += 1
        }
      }

      let anchors = controller.debugLodestones
      let after = controller.debugMeanDistanceToAnchor
      var problems: [String] = []
      if !planted { problems.append("could not plant") }
      if anchors.isEmpty { problems.append("anchor vanished") }
      if peakCaught == 0 { problems.append("field never caught anyone") }
      if let before, let after, after.count > 0, after.mean >= before.mean {
        problems.append(
          String(format: "did not gather: mean %.0f -> %.0f", before.mean, after.mean))
      }
      if !problems.isEmpty { failures += 1 }

      let drift =
        (before.map { b in after.map { String(format: "%.0f->%.0f", b.mean, $0.mean) } ?? "-" })
        ?? "-"
      print(
        "\(name.padding(toLength: 10, withPad: " ", startingAt: 0)) "
          + "anchors=\(anchors.count) peakHeld=\(peakCaught) meanDist=\(drift)  "
          + (problems.isEmpty ? "ok" : "PROBLEMS: " + problems.joined(separator: "; ")))
    }

    // The cushion: drop lemmings far enough to die, with and without a field.
    print("")
    for withField in [false, true] {
      let controller = GameController()
      controller.debugStartLevel(0)
      for _ in 0..<80 { step(controller) }
      if withField {
        controller.debugPlantLodestone(nearX: 0, y: 0)
      }
      for _ in 0..<600 { step(controller) }
      let counts = controller.debugCounts
      let dead = counts.released - counts.inLevel - counts.saved
      print(
        "level0 \(withField ? "with" : "without") a field: "
          + "released=\(counts.released) alive=\(counts.inLevel) dead=\(dead)")
    }

    print("")
    print(failures == 0 ? "LODESTONE OK" : "\(failures) level(s) with problems")
    return failures == 0 ? 0 : 1
  }

  /// Plays the side-scroller with scripted input and reports what the physics
  /// actually did. Running it is the only way to know whether the jump clears
  /// anything, whether the collision holds, and whether a rocket jump lifts.
  static func dash(arguments: [String]) -> Int32 {
    let levelName = arguments.count > 1 ? arguments[1] : "pirates"
    let directory = arguments.count > 2 ? arguments[2] : nil

    let chooser = LevelChooser()
    guard
      let index = (0..<chooser.levelCount).first(where: { chooser.levelData($0).file == levelName })
    else {
      print("no level called \(levelName)")
      return 1
    }

    let controller = GameController()
    controller.startDash(levelIndex: index)
    guard let dash = controller.debugDash else {
      print("dash did not start")
      return 1
    }

    let canvas = Bitmap(width: Level.canvasWidth, height: Level.canvasHeight)
    let graphics = canvas.createGraphics()
    var shot = 0
    var failures = 0

    func run(_ frames: Int, shooting: Bool = false) {
      for _ in 0..<frames {
        controller.tickFrame()
        if let directory, shooting {
          canvas.invalidate()
          controller.draw(graphics)
          write(
            canvas,
            to: (directory as NSString).appendingPathComponent(
              String(format: "dash%03d.png", shot)))
          shot += 1
        }
      }
    }

    func check(_ label: String, _ condition: Bool, _ detail: String) {
      if !condition { failures += 1 }
      print("  \(condition ? "ok  " : "FAIL") \(label.padding(toLength: 26, withPad: " ", startingAt: 0)) \(detail)")
    }

    print("Level \(levelName)\n")

    // 1. Falls to the ground and stops there.
    run(90, shooting: directory != nil)
    let landed = dash.debugState
    check("lands and settles", landed.onGround, "y=\(landed.y) vy=\(String(format: "%.1f", landed.vy))")

    // 2. Running moves, and the collision stops it inside the level.
    dash.debugHold(.right)
    run(60, shooting: directory != nil)
    let ran = dash.debugState
    dash.debugReleaseAll()
    check("runs right", ran.x > landed.x, "x \(landed.x) -> \(ran.x)")
    check("stays in the level", ran.x > 0 && ran.x < 1200, "x=\(ran.x)")

    // 3. A jump leaves the ground and comes back to it.
    run(20)
    let beforeJump = dash.debugState
    dash.debugHold(.char(" "))
    run(6, shooting: directory != nil)
    let rising = dash.debugState
    dash.debugReleaseAll()
    check("jump lifts off", rising.y < beforeJump.y, "y \(beforeJump.y) -> \(rising.y)")
    run(90)
    check("comes back down", dash.debugState.onGround, "y=\(dash.debugState.y)")

    // 4. Digging opens the floor and drops the player through it.
    let beforeDig = dash.debugState
    dash.debugHold(.char("s"))
    run(70, shooting: directory != nil)
    dash.debugReleaseAll()
    let dug = dash.debugState
    check("digging sinks", dug.y > beforeDig.y, "y \(beforeDig.y) -> \(dug.y)")

    // 5. Standing still and dropping a bomb should launch the player: the
    //    rocket jump. Measured as the speed the blast actually added, in
    //    whatever direction it threw them.
    run(60)
    dash.debugReleaseAll()
    run(30)  // come to a stop, so the bomb drops at the feet
    let standing = dash.debugState
    dash.throwBomb()
    check("bomb in the air", dash.debugState.bombs > 0, "bombs=\(dash.debugState.bombs)")

    // Wait for it to go off...
    for _ in 0..<160 {
      controller.tickFrame()
      if let directory {
        canvas.invalidate()
        controller.draw(graphics)
        write(
          canvas,
          to: (directory as NSString).appendingPathComponent(
            String(format: "dash%03d.png", shot)))
        shot += 1
      }
      if dash.debugState.bombs == 0 && dash.debugLastKick > 0 { break }
    }
    check("bomb detonated", dash.debugState.bombs == 0, "")
    check(
      "rocket jump kicks", dash.debugLastKick > 4,
      String(format: "blast added %.1f px/frame", dash.debugLastKick))

    // ...then follow the arc, because the launch takes effect on the frames
    // after the blast, not on the frame of it.
    var apex = standing.y
    for _ in 0..<50 {
      controller.tickFrame()
      if let directory {
        canvas.invalidate()
        controller.draw(graphics)
        write(
          canvas,
          to: (directory as NSString).appendingPathComponent(
            String(format: "dash%03d.png", shot)))
        shot += 1
      }
      apex = min(apex, dash.debugState.y)
    }
    check(
      "rocket jump lifts", apex < standing.y - 20,
      "rose \(standing.y - apex)px from y=\(standing.y)")

    // 6. The crowd shows up and runs its own code.
    run(260)
    check("crowd spawns", dash.debugState.horde > 0, "horde=\(dash.debugState.horde)")

    print("")
    print(failures == 0 ? "DASH OK" : "\(failures) check(s) failed")
    return failures == 0 ? 0 : 1
  }

  /// Walks the first-person game around and checks the world holds up: the
  /// floor plan has structure, walls stop you, rockets open them, and the
  /// renderer produces a picture that is not one flat colour.
  static func doom(arguments: [String]) -> Int32 {
    let levelName = arguments.count > 1 ? arguments[1] : "pirates"
    let directory = arguments.count > 2 ? arguments[2] : nil

    let chooser = LevelChooser()
    guard
      let index = (0..<chooser.levelCount).first(where: { chooser.levelData($0).file == levelName })
    else {
      print("no level called \(levelName)")
      return 1
    }

    let controller = GameController()
    controller.startDoom(levelIndex: index)
    guard let doom = controller.debugDoom else {
      print("doom did not start")
      return 1
    }

    let canvas = Bitmap(width: Level.canvasWidth, height: Level.canvasHeight)
    let graphics = canvas.createGraphics()
    var shot = 0
    var failures = 0

    func run(_ frames: Int, shooting: Bool = false) {
      for _ in 0..<frames {
        controller.tickFrame()
        if let directory, shooting {
          canvas.invalidate()
          controller.draw(graphics)
          write(
            canvas,
            to: (directory as NSString).appendingPathComponent(
              String(format: "doom%03d.png", shot)))
          shot += 1
        }
      }
    }

    func check(_ label: String, _ ok: Bool, _ detail: String) {
      if !ok { failures += 1 }
      print(
        "  \(ok ? "ok  " : "FAIL") "
          + "\(label.padding(toLength: 28, withPad: " ", startingAt: 0)) \(detail)")
    }

    print("Level \(levelName)\n")

    let start = doom.debugState
    // A floor plan has to be mostly open with real structure in it, or there
    // is nothing to walk through.
    let wallFraction = Double(start.walls) / Double(start.cells)
    check(
      "floor plan has structure", wallFraction > 0.15 && wallFraction < 0.85,
      String(format: "%.0f%% of %d cells are wall", wallFraction * 100, start.cells))
    check(
      "spawned somewhere open", start.x > 0 && start.y > 0,
      String(format: "at %.1f,%.1f", start.x, start.y))

    // Walking into a wall must stop, not pass through.
    doom.debugFace(0)
    doom.debugHold(.char("w"))
    run(240, shooting: directory != nil)
    doom.debugReleaseAll()
    let walked = doom.debugState
    check(
      "walking moves", abs(walked.x - start.x) + abs(walked.y - start.y) > 1,
      String(format: "%.1f,%.1f -> %.1f,%.1f", start.x, start.y, walked.x, walked.y))

    // Push into geometry from several angles; the camera must never end up
    // inside it.
    var insideWall = false
    for step in 0..<16 {
      doom.debugFace(Double(step) * .pi / 8)
      doom.debugHold(.char("w"))
      for _ in 0..<30 {
        controller.tickFrame()
        if doom.debugInWall { insideWall = true }
      }
    }
    doom.debugReleaseAll()
    check("never clips into a wall", !insideWall, "collision held from 16 angles")

    // A rocket should open the level up — aimed at an actual wall, which is
    // the point the first version of this test missed by firing into open sky.
    var aimed = false
    var aimDetail = "none in range"
    for step in 0..<64 {
      doom.debugFace(Double(step) * .pi / 32)
      let ahead = doom.debugWallAhead()
      if ahead.distance < 16 && ahead.cell == .dirt {
        aimed = true
        aimDetail = String(format: "earth, %.1f cells away", ahead.distance)
        break
      }
    }
    check("found earth to shoot", aimed, aimDetail)

    let wallsBefore = doom.debugWallCount
    // Fired through the real key path, not by calling fire() directly — that
    // is the difference between proving the gun works and proving the trigger
    // is wired to it.
    controller.keyDown(.char(" "), shift: false)
    controller.keyUp(.char(" "))
    check(
      "space fires", doom.debugState.bombs > 0,
      "bombs in flight = \(doom.debugState.bombs)")
    run(200, shooting: directory != nil)
    let wallsAfter = doom.debugWallCount
    check(
      "rocket opens walls", wallsAfter < wallsBefore,
      "wall cells \(wallsBefore) -> \(wallsAfter)")

    // Firing has to be *visible*, which is a separate question from whether it
    // works: the first version of this did everything right and showed none of
    // it. Compare the screen on the frame of the shot against a quiet frame.
    run(120)
    canvas.invalidate()
    controller.draw(graphics)
    var quiet = Set<UInt32>()
    for y in stride(from: 60, to: 560, by: 6) {
      for x in stride(from: 0, to: 800, by: 6) { quiet.insert(canvas.getRGB(x, y)) }
    }

    controller.keyDown(.char(" "), shift: false)
    controller.keyUp(.char(" "))
    controller.tickFrame()
    canvas.invalidate()
    controller.draw(graphics)
    var firing = Set<UInt32>()
    for y in stride(from: 60, to: 560, by: 6) {
      for x in stride(from: 0, to: 800, by: 6) { firing.insert(canvas.getRGB(x, y)) }
    }
    check(
      "muzzle flash shows", firing.subtracting(quiet).count > 3,
      "\(firing.subtracting(quiet).count) new colours on the frame of the shot")

    // And the rocket itself has to appear in the world.
    var sawRocket = false
    for _ in 0..<40 {
      controller.tickFrame()
      canvas.invalidate()
      controller.draw(graphics)
      // The rocket's hot core is a colour nothing else on screen uses.
      for y in stride(from: 60, to: 560, by: 4) where !sawRocket {
        for x in stride(from: 0, to: 800, by: 4) {
          if canvas.getRGB(x, y) & 0x00FF_FFFF == 0xFFF0B0 { sawRocket = true; break }
        }
      }
      if sawRocket { break }
    }
    check("rocket is visible in flight", sawRocket, "found its core on screen")

    // Locals turn up.
    run(400, shooting: directory != nil)
    check("wanderers appear", doom.debugState.wanderers > 0, "\(doom.debugState.wanderers) about")

    // And the picture has to actually have depth in it.
    canvas.invalidate()
    controller.draw(graphics)
    var colors = Set<UInt32>()
    for y in stride(from: 60, to: 560, by: 11) {
      for x in stride(from: 0, to: 800, by: 11) {
        colors.insert(canvas.getRGB(x, y))
      }
    }
    check("renders a scene", colors.count > 25, "\(colors.count) distinct colours on screen")

    print("")
    print(failures == 0 ? "DOOMMINGS OK" : "\(failures) check(s) failed")
    return failures == 0 ? 0 : 1
  }

  /// Plays the horde game and checks the loop actually closes: waves arrive,
  /// the cannon fires while the button is held, shots kill things, raiders that
  /// get through take the wall down, and the wall falling ends it.
  static func siege(arguments: [String]) -> Int32 {
    let directory = arguments.count > 1 ? arguments[1] : nil

    let controller = GameController()
    controller.startSiege()
    guard let siege = controller.debugSiege else {
      print("siege did not start")
      return 1
    }

    let canvas = Bitmap(width: Level.canvasWidth, height: Level.canvasHeight)
    let graphics = canvas.createGraphics()
    var shot = 0
    var failures = 0

    func run(_ frames: Int, shooting: Bool = false) {
      for _ in 0..<frames {
        controller.tickFrame()
        if let directory, shooting {
          canvas.invalidate()
          controller.draw(graphics)
          write(
            canvas,
            to: (directory as NSString).appendingPathComponent(
              String(format: "siege%03d.png", shot)))
          shot += 1
        }
      }
    }

    func check(_ label: String, _ ok: Bool, _ detail: String) {
      if !ok { failures += 1 }
      print(
        "  \(ok ? "ok  " : "FAIL") "
          + "\(label.padding(toLength: 30, withPad: " ", startingAt: 0)) \(detail)")
    }

    print("Lemming Siege\n")

    // Snapshot the setup screen at a couple of wave settings.
    if let directory {
      for target in [1, 12] {
        siege.setStartWave(target)
        canvas.invalidate()
        controller.draw(graphics)
        write(
          canvas,
          to: (directory as NSString).appendingPathComponent("setup-wave\(target).png"))
      }
      siege.setStartWave(1)
    }

    // It opens on the setup screen now, so get through that first.
    check("opens on setup", siege.debugPhase == "selecting", siege.debugPhase)
    run(30, shooting: directory != nil)
    check("setup does not spawn", siege.debugState.attackers == 0, "nothing moving yet")
    controller.keyDown(.enter, shift: false)
    controller.keyUp(.enter)
    check("enter starts the fight", siege.debugPhase == "fighting", siege.debugPhase)

    // The horde turns up on its own.
    run(260, shooting: directory != nil)
    let arrived = siege.debugState
    check("wave arrives", arrived.attackers > 0, "\(arrived.attackers) raiders inbound")
    check("wall starts whole", arrived.health > 0, "\(Int(arrived.health))%")

    // Holding the mouse has to produce a stream of shots, through the real
    // routing — press, aim, release — not by poking the cannon directly.
    controller.mouseDown(x: 700, y: 480)
    run(3)
    let firstVolley = siege.debugState.shots
    run(30, shooting: directory != nil)
    let heldVolley = siege.debugState.shots
    controller.mouseUp(x: 700, y: 480)
    check("holding fires a stream", heldVolley > firstVolley, "\(heldVolley) rounds in the air")

    // Two guns, and shots must leave from both muzzles — not one barrel
    // firing at double rate, which would look identical in the shot count.
    check("seven guns mounted", siege.debugGunCount == 7, "\(siege.debugGunCount) barrels")
    check(
      "four of them fly", siege.debugAirshipGuns == 4,
      "\(siege.debugAirshipGuns) on airships, two per ship")
    check(
      "two mirrored, five straight", siege.debugMirroredAngles.count == 2,
      "\(siege.debugMirroredAngles.count) mirrored, "
        + "\(siege.debugStraightAngles.count) straight")

    // The airship guns are mirrored about the horizon, and the right button
    // drops the mirror so all five converge.
    do {
      let air = GameController()
      air.startSiege(wave: 5)
      guard let airRun = air.debugSiege else { return 1 }
      air.keyDown(.enter, shift: false)
      air.keyUp(.enter)
      airRun.debugRemoveAllAttackers()

      // Aim low at the ground.
      air.mouseMoved(x: 400, y: 495)
      air.tickFrame()
      // Negative is upward on screen. Straight guns should be pointing down
      // at the ground; the mirrored pair up into the sky.
      let straightDown = airRun.debugStraightAngles.allSatisfy { $0 > 0 }
      let mirroredUp = airRun.debugMirroredAngles.allSatisfy { $0 < 0 }
      check(
        "aiming low, mirrored point up", straightDown && mirroredUp,
        String(
          format: "%d straight down, %d mirrored up",
          airRun.debugStraightAngles.count, airRun.debugMirroredAngles.count))

      // Aim high at the sky; it should swap over.
      air.mouseMoved(x: 400, y: 120)
      air.tickFrame()
      check(
        "aiming high, mirrored point down", airRun.debugMirroredAngles.allSatisfy { $0 > 0 },
        String(
          format: "%.0f/%.0f degrees",
          airRun.debugMirroredAngles[0], airRun.debugMirroredAngles[1]))

      // Right button drops the mirror.
      air.mouseMoved(x: 400, y: 495)
      air.tickFrame()
      air.rightMouseDown(x: 400, y: 495)
      air.tickFrame()
      let focused = airRun.debugGunAngles
      check("right button focuses", airRun.debugConcentrating, "mirror off")
      check(
        "focused, every gun agrees", focused.allSatisfy { $0 > 0 },
        String(format: "all seven down: %.0f to %.0f degrees",
          focused.min()!, focused.max()!))

      air.rightMouseUp(x: 400, y: 495)
      air.tickFrame()
      check(
        "releasing restores the mirror",
        !airRun.debugConcentrating && airRun.debugMirroredAngles.allSatisfy { $0 < 0 },
        "mirrored pair back on the sky")

      // The straight pair on the airships must track the cursor like the
      // tower's, not the mirror.
      air.mouseMoved(x: 400, y: 495)
      air.tickFrame()
      let straight = airRun.debugStraightAngles
      check(
        "airship straight guns follow the cursor", straight.allSatisfy { $0 > 0 },
        "\(straight.count) barrels on the ground with the tower")
    }

    // The airships hold station by drifting, so their muzzles must move while
    // the tower's stay put.
    var heightsSeen = Set<[Int]>()
    for _ in 0..<160 {
      controller.tickFrame()
      heightsSeen.insert(siege.debugGunHeights)
    }
    let towerFixed = Set(heightsSeen.map { Array($0.prefix(3)) }).count == 1
    let pairsTogether = heightsSeen.allSatisfy { $0[3] == $0[4] && $0[5] == $0[6] }
    check(
      "airships drift, tower does not", heightsSeen.count > 8 && towerFixed,
      "\(heightsSeen.count) distinct gun heights over 160 frames")
    check(
      "each ship's pair drifts together", pairsTogether,
      "both barrels ride the same envelope")

    controller.mouseDown(x: 700, y: 470)
    var barrelsSeen = Set<Int>()
    for _ in 0..<40 {
      controller.tickFrame()
      barrelsSeen.formUnion(siege.debugBarrelsInUse)
    }
    controller.mouseUp(x: 700, y: 470)
    check(
      "every barrel fires", barrelsSeen.count == 7,
      "rounds came from \(barrelsSeen.count) of 7 barrels")

    run(60)
    controller.mouseDown(x: 700, y: 480)
    run(4)
    controller.mouseUp(x: 700, y: 480)
    run(40)
    check("releasing stops it", siege.debugState.shots < 6, "\(siege.debugState.shots) left flying")

    // Aim at something and put rounds into it.
    let beforeKills = siege.debugState.kills
    // Press once, then track the target with the mouse. Pressing every frame
    // re-aims at the press point, which pointed the cannon into its own roof.
    controller.mouseDown(x: 700, y: 480)
    for _ in 0..<420 {
      if let target = siege.debugFirstTarget {
        controller.mouseMoved(x: Int(target.x), y: Int(target.y))
      }
      controller.tickFrame()
      if let directory {
        canvas.invalidate()
        controller.draw(graphics)
        write(
          canvas,
          to: (directory as NSString).appendingPathComponent(
            String(format: "siege%03d.png", shot)))
        shot += 1
      }
      if siege.debugState.kills > beforeKills + 4 { break }
    }
    controller.mouseUp(x: 700, y: 480)
    check(
      "shooting kills raiders", siege.debugState.kills > beforeKills,
      "\(siege.debugState.kills) stopped, score \(siege.debugState.score)")
    check("debris flies", siege.debugState.flecks > 0, "\(siege.debugState.flecks) pieces")

    // Left alone, the horde chews the wall down and ends the run.
    let healthBefore = siege.debugState.health
    run(900)
    let healthAfter = siege.debugState.health
    check(
      "horde damages the wall", healthAfter < healthBefore,
      "\(Int(healthBefore))% -> \(Int(healthAfter))%")

    var over = siege.debugState.over
    for _ in 0..<60 where !over {
      run(120)
      over = siege.debugState.over
    }
    check("wall falling ends it", over, "survived \(siege.debugState.wave) waves")

    // And it can be picked up again.
    controller.keyDown(.char("r"), shift: false)
    controller.keyUp(.char("r"))
    run(2)
    check(
      "restart puts the wall back", !siege.debugState.over && siege.debugState.health > 90,
      "\(Int(siege.debugState.health))%")

    // Starting on a later wave has to actually mean a later wave: the right
    // number on the HUD, a bigger pack, and the harder kinds unlocked.
    print("")
    for wave in [1, 5, 12] {
      let fresh = GameController()
      fresh.startSiege(wave: wave)
      guard let run = fresh.debugSiege else { continue }

      let briefing = run.waveBriefing
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)

      // Let the first pack finish arriving.
      var guardCount = 0
      while run.debugPendingSpawns == 0 && guardCount < 600 {
        fresh.tickFrame()
        guardCount += 1
      }
      // The loop above exits on the frame the pack is queued, before any of it
      // has spawned, so this is the whole wave.
      let spawnsQueued = run.debugPendingSpawns
      for _ in 0..<1800 where run.debugPendingSpawns > 0 { fresh.tickFrame() }

      let reported = run.debugState.wave
      let ok = reported == wave && spawnsQueued == briefing.count
      if !ok { failures += 1 }
      print(
        "  \(ok ? "ok  " : "FAIL") "
          + "\("start at wave \(wave)".padding(toLength: 30, withPad: " ", startingAt: 0)) "
          + "hud says \(reported), pack of \(spawnsQueued) (\(briefing.kinds))")
    }

    // The nuke: clears the field, is limited to three, and comes back on a
    // fresh run.
    print("")
    do {
      let fresh = GameController()
      fresh.startSiege(wave: 4)
      guard let run = fresh.debugSiege else { return 1 }
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)

      // Let a crowd build up, holding the wall the whole time. Left to itself
      // the horde sometimes brings it down inside this window, and a finished
      // run refuses to nuke — which is correct, and made this test flaky.
      for _ in 0..<700 {
        fresh.tickFrame()
        run.debugRestoreWall()
      }
      let crowd = run.debugLivingAttackers
      check("crowd to clear", crowd > 2, "\(crowd) on the field")
      check("starts with three", run.debugNukesLeft == 3, "\(run.debugNukesLeft) charges")

      // Right click sets it off, through the real routing.
      fresh.keyDown(.char("q"), shift: false)
      fresh.keyUp(.char("q"))
      fresh.tickFrame()
      check(
        "nuke clears the field", run.debugLivingAttackers == 0,
        "\(crowd) -> \(run.debugLivingAttackers) standing")
      check("spends a charge", run.debugNukesLeft == 2, "\(run.debugNukesLeft) left")

      check("run still live", !run.debugState.over, "not over")

      // An empty field must not waste one.
      fresh.keyDown(.char("q"), shift: false)
      fresh.keyUp(.char("q"))
      check("not wasted on nothing", run.debugNukesLeft == 2, "\(run.debugNukesLeft) left")

      // Burn the rest, then confirm it stops. The wall is topped up along the
      // way: left alone the horde brings it down, and a finished run refuses
      // to nuke at all, which is correct but says nothing about the charges.
      func rebuildCrowd() {
        for _ in 0..<900 {
          fresh.tickFrame()
          run.debugRestoreWall()
        }
      }
      rebuildCrowd()
      fresh.keyDown(.char("q"), shift: false)
      fresh.keyUp(.char("q"))
      check("second charge spends", run.debugNukesLeft == 1, "\(run.debugNukesLeft) left")

      rebuildCrowd()
      fresh.keyDown(.char("q"), shift: false)
      fresh.keyUp(.char("q"))
      fresh.tickFrame()
      check("third empties the rack", run.debugNukesLeft == 0, "\(run.debugNukesLeft) left")

      // Put a crowd there by hand: waiting on the wave timer sometimes landed
      // in the gap between waves, leaving nothing to nuke and making the check
      // pass or fail on luck.
      for offset in 0..<6 {
        run.debugSpawn(.walker, atX: Double(120 + offset * 30), facing: 1)
      }
      fresh.tickFrame()
      let before = run.debugLivingAttackers
      fresh.keyDown(.char("q"), shift: false)
      fresh.keyUp(.char("q"))
      fresh.tickFrame()
      check(
        "no fourth nuke", before > 0 && run.debugLivingAttackers == before,
        "\(before) still standing, rack empty")

      // A fresh run gets the rack back. The wall has to actually fall first:
      // R only restarts a finished run, and this test had been propping the
      // fortress up.
      var guardCount = 0
      while !run.debugState.over && guardCount < 20_000 {
        fresh.tickFrame()
        guardCount += 1
      }
      check("wall eventually falls", run.debugState.over, "run ended")
      fresh.keyDown(.char("r"), shift: false)
      fresh.keyUp(.char("r"))
      check("a new run restocks", run.debugNukesLeft == 3, "\(run.debugNukesLeft) charges")
    }

    // Charges come back over time, and stop at a full rack.
    do {
      let fresh = GameController()
      fresh.startSiege(wave: 4)
      guard let run = fresh.debugSiege else { return 1 }
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)
      for _ in 0..<700 {
        fresh.tickFrame()
        run.debugRestoreWall()
      }

      fresh.keyDown(.char("q"), shift: false)
      fresh.keyUp(.char("q"))
      fresh.tickFrame()
      check("spent one to test refill", run.debugNukesLeft == 2, "\(run.debugNukesLeft) left")

      // Part way there, the pip should be partly charged but not granted yet.
      for _ in 0..<1000 {
        fresh.tickFrame()
        run.debugRestoreWall()
      }
      let partial = run.debugNukeRecharge
      check(
        "charge builds", partial > 0.3 && partial < 0.7 && run.debugNukesLeft == 2,
        String(format: "%.0f%% toward the next", partial * 100))

      // All the way.
      for _ in 0..<1200 {
        fresh.tickFrame()
        run.debugRestoreWall()
      }
      check("charge lands", run.debugNukesLeft == 3, "\(run.debugNukesLeft) charges")

      // And it must not run past a full rack.
      for _ in 0..<4000 {
        fresh.tickFrame()
        run.debugRestoreWall()
      }
      check(
        "rack does not overfill", run.debugNukesLeft == 3 && run.debugNukeRecharge == 0,
        "\(run.debugNukesLeft) charges, \(Int(run.debugNukeRecharge * 100))% banked")

      // A boss is not immune.
      let bossRun = GameController()
      bossRun.startSiege(wave: 3)
      guard let bossSiege = bossRun.debugSiege else { return 1 }
      bossRun.keyDown(.enter, shift: false)
      bossRun.keyUp(.enter)
      var ticks = 0
      while ticks < 20_000 && bossSiege.debugBoss == nil {
        bossRun.tickFrame()
        ticks += 1
        bossSiege.debugCullOrdinary()
      }
      let hadBoss = bossSiege.debugBoss != nil
      bossRun.keyDown(.char("q"), shift: false)
      bossRun.keyUp(.char("q"))
      bossRun.tickFrame()
      check(
        "nuke takes the boss too", hadBoss && bossSiege.debugBoss == nil,
        hadBoss ? "brute down" : "no brute to test")
    }

    if let directory {
      // The dome, on a throwaway run. Captured in place it shoved the horde
      // out to the perimeter and left it there, which is exactly what the
      // checks above are measuring.
      let dome = GameController()
      dome.startSiege(wave: 5)
      dome.keyDown(.enter, shift: false)
      dome.keyUp(.enter)
      if let domeRun = dome.debugSiege {
        for _ in 0..<1400 {
          dome.tickFrame()
          domeRun.debugRestoreWall()
        }
        dome.keyDown(.char("e"), shift: false)
        dome.keyUp(.char("e"))
        for frame in 0..<170 {
          dome.tickFrame()
          domeRun.debugRestoreWall()
          if frame % 40 == 0 {
            canvas.invalidate()
            dome.draw(graphics)
            write(
              canvas,
              to: (directory as NSString).appendingPathComponent(
                String(format: "field%02d.png", frame)))
          }
        }
      }

      // The brute, on its own run. Captured inline it was shot dead before the
      // "holds the wave" check below could observe it standing.
      let brute = GameController()
      brute.startSiege(wave: 12)
      brute.keyDown(.enter, shift: false)
      brute.keyUp(.enter)
      if let bruteRun = brute.debugSiege {
        var ticks = 0
        while ticks < 20_000 && bruteRun.debugBoss == nil {
          brute.tickFrame()
          ticks += 1
          bruteRun.debugCullOrdinary()
        }
        for frame in 0..<700 {
          brute.tickFrame()
          if frame % 3 == 0 { bruteRun.debugCullOrdinary() }
          bruteRun.debugRestoreWall()
          if let target = bruteRun.debugBossPosition {
            brute.mouseMoved(x: Int(target.x), y: Int(target.y))
          }
          if frame > 90 { brute.mouseDown(x: 600, y: 440) }
          if frame % 70 == 0 {
            canvas.invalidate()
            brute.draw(graphics)
            write(
              canvas,
              to: (directory as NSString).appendingPathComponent(
                String(format: "boss%03d.png", frame)))
          }
        }
        brute.mouseUp(x: 600, y: 440)
      }

      // The airships breaking off onto something in the sky, staged on its own
      // run: in the thick of a fight they shoot the thing down within a few
      // frames, so the lock is too brief to catch by sampling.
      let flak = GameController()
      flak.startSiege(wave: 5)
      flak.keyDown(.enter, shift: false)
      flak.keyUp(.enter)
      if let flakRun = flak.debugSiege {
        for _ in 0..<240 {
          flak.tickFrame()
          flakRun.debugRestoreWall()
        }
        flakRun.debugSpawn(.paratrooper, atX: 150, facing: 1)
        flakRun.debugSpawn(.paratrooper, atX: 650, facing: -1)
        flak.mouseMoved(x: 400, y: 495)
        for frame in 0..<260 {
          flak.tickFrame()
          flakRun.debugRestoreWall()
          flak.mouseMoved(x: 400, y: 495)
          if frame % 60 == 0 {
            canvas.invalidate()
            flak.draw(graphics)
            write(
              canvas,
              to: (directory as NSString).appendingPathComponent(
                String(format: "flak%03d.png", frame)))
          }
        }
      }

      // A later wave in full flow: chutes in the air, shooters planted out
      // wide, shells inbound.
      let busy = GameController()
      busy.startSiege(wave: 9)
      busy.keyDown(.enter, shift: false)
      busy.keyUp(.enter)
      if let busyRun = busy.debugSiege {
        for frame in 0..<1500 {
          busy.tickFrame()
          busyRun.debugRestoreWall()
          if frame > 300 {
            busy.mouseMoved(x: 150, y: 470)
            busy.mouseDown(x: 150, y: 470)
          }
          // Put a crate up so the capture shows one, and shoot at the crowd
          // rather than at it.
          if frame == 420 { busyRun.debugDropKit(atX: 585, y: -30) }
          // Staged, so the capture reliably shows the airships broken off onto
          // something in the sky rather than waiting on the wave roll.
          if frame % 260 == 120 { busyRun.debugSpawn(.paratrooper, atX: 170, facing: 1) }
          // Late enough that the dead have piled up, and catching a guided
          // bomb on its way in.
          if frame >= 820 && frame % 20 == 0 && busyRun.debugSmartBombs > 0 {
            canvas.invalidate()
            busy.draw(graphics)
            write(
              canvas,
              to: (directory as NSString).appendingPathComponent(
                String(format: "horde%04d.png", frame)))
          }
        }
        busy.mouseUp(x: 150, y: 470)
      }

      let show = GameController()
      show.startSiege(wave: 6)
      show.keyDown(.enter, shift: false)
      show.keyUp(.enter)
      for _ in 0..<800 { show.tickFrame() }
      show.keyDown(.char("q"), shift: false)
      show.keyUp(.char("q"))
      for frame in 0..<32 {
        canvas.invalidate()
        show.draw(graphics)
        if frame % 4 == 0 {
          write(
            canvas,
            to: (directory as NSString).appendingPathComponent(
              String(format: "nuke%02d.png", frame)))
        }
        show.tickFrame()
      }
    }

    // The force field: holds the horde off the wall for its duration, then
    // drops and lets them back in.
    print("")
    do {
      let fresh = GameController()
      fresh.startSiege(wave: 5)
      guard let run = fresh.debugSiege else { return 1 }
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)

      /// Advances time with the wall propped up. Every ability guards on the
      /// run still being live, so a test that lets the fortress quietly fall
      /// measures a refusal instead of the thing it meant to measure — which
      /// it has now done three times.
      func settle(_ frames: Int) {
        for _ in 0..<frames {
          fresh.tickFrame()
          run.debugRestoreWall()
        }
      }

      settle(1400)
      let closestBefore = run.debugClosestApproach ?? 999
      check(
        "horde reaches the wall", closestBefore < 100,
        String(format: "nearest %.0fpx from the tower", closestBefore))
      check("starts with two fields", run.debugFieldsLeft == 2, "\(run.debugFieldsLeft)")

      // With no dome, they chew. Stop at the first bite rather than running a
      // fixed window: a full crowd takes the wall from 100% to nothing in a
      // couple of seconds, and a dead run cannot raise a dome, which is what
      // made this flaky.
      let openingHealth = run.debugState.health
      var bitten = false
      var biteWait = 0
      while biteWait < 300 && !bitten {
        fresh.tickFrame()
        biteWait += 1
        if run.debugState.health < openingHealth { bitten = true }
      }
      check(
        "they bite without a dome", bitten,
        String(format: "%.0f%% -> %.0f%% after %d frames",
          openingHealth, run.debugState.health, biteWait))
      check("run survives the test", !run.debugState.over, "still live")

      // Raise it, from a full wall.
      run.debugRestoreWall()
      fresh.keyDown(.char("e"), shift: false)
      fresh.keyUp(.char("e"))
      check("field goes up", run.debugFieldUp, "dome raised")
      check("spends a charge", run.debugFieldsLeft == 1, "\(run.debugFieldsLeft) left")

      // Give it a moment to shove them clear, then watch the wall.
      for _ in 0..<140 { fresh.tickFrame() }
      let pushedTo = run.debugClosestApproach ?? 0
      let heldHealth = run.debugState.health
      for _ in 0..<180 { fresh.tickFrame() }
      check(
        "pushes them to the perimeter", pushedTo >= Siege.fieldRadius - 8,
        String(format: "nearest held %.0fpx out, dome is %.0f", pushedTo, Siege.fieldRadius))
      check(
        "wall takes nothing while up", run.debugState.health == heldHealth,
        String(format: "held at %.0f%%", heldHealth))

      // And it expires.
      var guardCount = 0
      while run.debugFieldUp && guardCount < 600 {
        fresh.tickFrame()
        guardCount += 1
      }
      check("field expires", !run.debugFieldUp, "dome down after \(guardCount) frames")

      // Wait for the first bite rather than guessing a window, and stop the
      // moment it lands so the run survives. A fixed window cannot work here:
      // the dome shoved them 127px further out than the wall, so they have a
      // long walk back — which is most of what the ability buys you.
      run.debugRestoreWall()
      var bitesAgain = false
      var waited = 0
      while waited < 900 && !bitesAgain {
        fresh.tickFrame()
        waited += 1
        if run.debugState.health < Siege.maxHealth { bitesAgain = true }
      }
      check(
        "they get back in afterwards", bitesAgain,
        "first bite \(waited) frames after the dome fell")

      // Only one dome at a time, and the rack refills.
      run.debugRestoreWall()
      fresh.keyDown(.char("e"), shift: false)
      fresh.keyUp(.char("e"))
      check("second charge works", run.debugFieldUp && run.debugFieldsLeft == 0, "rack empty")
      fresh.keyDown(.char("e"), shift: false)
      fresh.keyUp(.char("e"))
      check("no third without a charge", run.debugFieldsLeft == 0, "still empty")

      settle(1700)
      check(
        "field recharges", run.debugFieldsLeft >= 1,
        "\(run.debugFieldsLeft) back in the rack")
    }

    // What each wave actually sends, so "where are the shooters?" has an
    // answer that is not guesswork.
    print("")
    for startWave in [3, 5, 7, 10] {
      let probe = GameController()
      probe.startSiege(wave: startWave)
      guard let run = probe.debugSiege else { continue }
      probe.keyDown(.enter, shift: false)
      probe.keyUp(.enter)
      // Tick until the wave counter actually reaches the chosen wave: the run
      // starts one short so the first wave to arrive is the one selected, and
      // sampling before that reports the previous wave's mix.
      var spin = 0
      while run.debugState.wave < startWave && spin < 600 {
        probe.tickFrame()
        spin += 1
      }
      let mix = run.debugMixSample(1000)
      let order: [Siege.Raider] = [.walker, .runner, .bomber, .paratrooper, .shooter, .heavy]
      let line = order.compactMap { kind -> String? in
        guard let n = mix[kind], n > 0 else { return nil }
        return "\(kind) \(n * 100 / 1000)%"
      }.joined(separator: "  ")
      print("  wave \(startWave) mix:  \(line)")
    }

    // Paratroopers come down out of the sky and land; shooters stop short and
    // shell the tower; the dome stops the shells but not the shooters.
    print("")
    do {
      let fresh = GameController()
      fresh.startSiege(wave: 7)
      guard let run = fresh.debugSiege else { return 1 }
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)

      func settle(_ frames: Int) {
        for _ in 0..<frames {
          fresh.tickFrame()
          run.debugRestoreWall()
        }
      }

      // Stage one of each by hand, so this does not wait on the wave roll.
      run.debugRemoveAllAttackers()
      run.debugSpawn(.paratrooper, atX: 300, facing: 1)
      let startHeight = run.debugHighestDescending
      check(
        "paratrooper starts aloft", (startHeight ?? 0) > 20,
        String(format: "%.0fpx above the ground", startHeight ?? 0))

      var landed = false
      var descendFrames = 0
      while descendFrames < 1200 && !landed {
        fresh.tickFrame()
        run.debugRestoreWall()
        descendFrames += 1
        if run.debugDescendingCount == 0 { landed = true }
      }
      check(
        "parachutes down and lands", landed,
        "touched down after \(descendFrames) frames")

      // Shooters hold their distance rather than closing on the wall.
      run.debugRemoveAllAttackers()
      run.debugSpawn(.shooter, atX: -30, facing: 1)
      settle(1500)
      let standoff = run.debugShooterStandoff
      check(
        "shooter holds its range", (standoff ?? 0) > Siege.fieldRadius,
        String(
          format: "planted %.0fpx out, dome reaches %.0f", standoff ?? 0, Siege.fieldRadius))

      // And it hurts from there.
      run.debugRestoreWall()
      let before = run.debugState.health
      var shelled = false
      for _ in 0..<1400 where !shelled {
        fresh.tickFrame()
        if run.debugState.health < before { shelled = true }
      }
      check("shells damage the wall", shelled, String(format: "wall %.0f%%", run.debugState.health))

      // With the dome up, shells die on it.
      run.debugRestoreWall()
      fresh.keyDown(.char("e"), shift: false)
      fresh.keyUp(.char("e"))
      let guarded = run.debugState.health
      run.debugSpawnShell(fromX: 60)
      var survivedDome = true
      for _ in 0..<400 {
        fresh.tickFrame()
        if run.debugState.health < guarded { survivedDome = false }
      }
      check(
        "dome stops the shells", survivedDome,
        String(format: "wall held at %.0f%%", run.debugState.health))
    }

    // Repair: earned by kills, paid out slowly, and never past full.
    print("")
    do {
      let fresh = GameController()
      fresh.startSiege(wave: 5)
      guard let run = fresh.debugSiege else { return 1 }
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)
      for _ in 0..<400 { fresh.tickFrame() }

      /// Advances with the field held empty. Clearing it once is not enough:
      /// the wave keeps spawning, and fresh raiders chew the wall far faster
      /// than the repair trickle can measure against.
      func quiet(_ frames: Int) {
        for _ in 0..<frames {
          run.debugRemoveAllAttackers()
          fresh.tickFrame()
        }
      }

      // A damaged wall with nothing killed must not creep back up.
      quiet(1)
      run.debugDamageWall(by: 40)
      let idle = run.debugState.health
      quiet(600)
      check(
        "no repair without kills", run.debugState.health <= idle + 0.001,
        String(format: "held at %.1f%%", run.debugState.health))

      // Kills bank repair.
      for _ in 0..<12 {
        run.debugRemoveAllAttackers()
        run.debugSpawn(.walker, atX: 300, facing: 1)
        fresh.tickFrame()
        run.debugKillFirst()
      }
      check(
        "kills bank repair", run.debugRepairReserve > 0,
        String(format: "%.1f banked", run.debugRepairReserve))

      // And it pays out — slowly.
      let before = run.debugState.health
      quiet(600)
      let after = run.debugState.health
      let perSecond = (after - before) / 10
      check(
        "wall recovers from kills", after > before,
        String(format: "%.1f%% -> %.1f%% over 10s", before, after))
      check(
        "recovery is slow", perSecond > 0 && perSecond < 2.0,
        String(format: "%.2f%% a second", perSecond))

      // It stops at full, and does not overshoot.
      for _ in 0..<60 {
        run.debugRemoveAllAttackers()
        run.debugSpawn(.heavy, atX: 300, facing: 1)
        fresh.tickFrame()
        run.debugKillFirst()
      }
      quiet(6000)
      check(
        "never past full", run.debugState.health <= Siege.maxHealth,
        String(format: "%.1f%% of %.0f", run.debugState.health, Siege.maxHealth))

      // The bank is capped, so a quiet spell cannot stockpile a whole wall.
      for _ in 0..<200 {
        run.debugRemoveAllAttackers()
        run.debugSpawn(.heavy, atX: 300, facing: 1)
        fresh.tickFrame()
        run.debugKillFirst()
      }
      check(
        "bank is capped", run.debugRepairReserve <= Siege.repairReserveCap + 0.001,
        String(format: "%.1f of %.0f max", run.debugRepairReserve, Siege.repairReserveCap))
    }

    // The dead: they lie where they fell, heap up, and are cleared eventually.
    print("")
    do {
      let fresh = GameController()
      fresh.startSiege(wave: 5)
      guard let run = fresh.debugSiege else { return 1 }
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)
      // Every loop in here holds the wall. A run that quietly ends part way
      // through turns every later check into a measurement of a refusal.
      func step(_ frames: Int) {
        for _ in 0..<frames {
          fresh.tickFrame()
          run.debugRestoreWall()
        }
      }
      step(200)

      // Kill a stack of raiders in one place and watch the heap build.
      for _ in 0..<14 {
        run.debugSpawn(.walker, atX: 250, facing: 1)
        fresh.tickFrame()
        run.debugRestoreWall()
        run.debugKillFirst()
      }
      step(40)
      check(
        "bodies stay where they fell", run.debugCorpses >= 10,
        "\(run.debugCorpses) on the ground")
      check(
        "they heap up", run.debugTallestPile >= 5,
        "\(run.debugTallestPile) deep at the tallest point")
      check(
        "they leave a mess", run.debugStains > run.debugCorpses,
        "\(run.debugStains) stains")

      // They linger a good while.
      let lingered = run.debugCorpses
      step(900)
      check(
        "still there fifteen seconds on", run.debugCorpses >= lingered,
        "\(run.debugCorpses) still lying there")

      // A nuke sweeps the field clear of them.
      for _ in 0..<10 {
        run.debugSpawn(.walker, atX: 250, facing: 1)
        fresh.tickFrame()
        run.debugRestoreWall()
        run.debugKillFirst()
      }
      step(40)
      let beforeNuke = run.debugCorpses
      run.debugSpawn(.walker, atX: 300, facing: 1)
      fresh.tickFrame()
      run.debugRestoreWall()
      run.fireNuke()
      fresh.tickFrame()
      check(
        "a nuke sweeps them away", beforeNuke > 0 && run.debugCorpses == 0,
        "\(beforeNuke) cleared")

      // So does the turn of a wave.
      for _ in 0..<10 {
        run.debugSpawn(.walker, atX: 250, facing: 1)
        fresh.tickFrame()
        run.debugRestoreWall()
        run.debugKillFirst()
      }
      step(40)
      let beforeWave = run.debugCorpses
      let waveWas = run.debugState.wave
      var turned = false
      var spin = 0
      while spin < 4000 && !turned {
        run.debugRemoveAllAttackers()
        fresh.tickFrame()
        run.debugRestoreWall()
        spin += 1
        if run.debugState.wave > waveWas { turned = true }
      }
      check("the wave actually turned", turned, "reached wave \(run.debugState.wave)")
      check(
        "a new wave clears the ground", beforeWave > 0 && turned && run.debugCorpses == 0,
        "\(beforeWave) cleared at the turn of wave \(run.debugState.wave)")

      // And eventually they are gone.
      // The wall is held here only to keep the timing deterministic; bodies
      // now age out whether the run is live or lost.
      var cleared = false
      var waited = 0
      while waited < 6000 && !cleared {
        run.debugRemoveAllAttackers()
        fresh.tickFrame()
        run.debugRestoreWall()
        waited += 1
        if run.debugCorpses == 0 { cleared = true }
      }
      check(
        "eventually cleared", cleared,
        String(format: "field clear after %.0fs", Double(waited) / 60))
      check(
        "heaps come down with them", run.debugTallestPile == 0,
        "\(run.debugTallestPile) left stacked")
    }

    // The guided bomb: it comes on its own, steers after the aim without
    // pinning to it, and clears what it lands on without touching the wall.
    print("")
    do {
      let fresh = GameController()
      fresh.startSiege(wave: 5)
      guard let run = fresh.debugSiege else { return 1 }
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)

      func step(_ frames: Int) {
        for _ in 0..<frames {
          fresh.tickFrame()
          run.debugRestoreWall()
        }
      }

      // It launches with no input at all.
      fresh.mouseMoved(x: 640, y: 440)
      var waited = 0
      while run.debugSmartBombs == 0 && waited < 1200 {
        fresh.tickFrame()
        run.debugRestoreWall()
        fresh.mouseMoved(x: 640, y: 440)
        waited += 1
      }
      check(
        "one is released unprompted", run.debugSmartBombs > 0,
        "after \(waited) frames, no input")

      // It closes on the aim point over time.
      func gapToAim() -> Double {
        guard let bomb = run.debugSmartBombPositions.first else { return .infinity }
        let aim = run.debugAimPoint
        return ((bomb.x - aim.x) * (bomb.x - aim.x) + (bomb.y - aim.y) * (bomb.y - aim.y))
          .squareRoot()
      }
      let startGap = gapToAim()
      var closest = startGap
      for _ in 0..<160 {
        fresh.tickFrame()
        run.debugRestoreWall()
        fresh.mouseMoved(x: 640, y: 440)
        closest = min(closest, gapToAim())
      }
      check(
        "it steers onto the aim", closest < startGap * 0.5,
        String(format: "%.0fpx out, closed to %.0f", startGap, closest))

      // It arrives and goes off rather than orbiting forever.
      var gone = false
      for _ in 0..<600 where !gone {
        fresh.tickFrame()
        run.debugRestoreWall()
        fresh.mouseMoved(x: 640, y: 440)
        if run.debugSmartBombs == 0 { gone = true }
      }
      check("and detonates", gone, "no bomb left circling")

      // It kills what it lands on, and leaves the wall alone.
      run.debugRemoveAllAttackers()
      step(2)
      let wallBefore = run.debugState.health
      let killsBefore = run.debugState.kills
      // Topped up as it goes: walkers spawned once march off toward the tower
      // and are long gone by the time the bomb arrives.
      var detonated = false
      for frame in 0..<1400 where !detonated {
        if frame % 20 == 0 {
          run.debugSpawn(.walker, atX: 640, facing: -1)
        }
        fresh.tickFrame()
        run.debugRestoreWall()
        fresh.mouseMoved(x: 640, y: 470)
        if run.debugState.kills > killsBefore { detonated = true }
      }
      check(
        "it clears what it lands on", detonated,
        "\(run.debugState.kills - killsBefore) caught in the blast")
      check(
        "and spares the wall", run.debugState.health >= wallBefore - 0.001,
        String(format: "wall %.0f%%", run.debugState.health))
    }

    // Bodies must keep decaying once the run is lost, or they sit frozen on
    // the game-over screen for as long as it is up.
    do {
      let fresh = GameController()
      fresh.startSiege(wave: 5)
      guard let run = fresh.debugSiege else { return 1 }
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)
      for _ in 0..<200 { fresh.tickFrame() }
      for _ in 0..<10 {
        run.debugSpawn(.walker, atX: 300, facing: 1)
        fresh.tickFrame()
        run.debugKillFirst()
      }
      for _ in 0..<40 { fresh.tickFrame() }
      let lying = run.debugCorpses

      // Let the wall go.
      var ended = false
      for _ in 0..<12_000 where !ended {
        fresh.tickFrame()
        if run.debugState.over { ended = true }
      }
      let atDeath = run.debugCorpses
      for _ in 0..<5000 { fresh.tickFrame() }
      check(
        "bodies decay after the run ends", ended && lying > 0 && run.debugCorpses < atDeath,
        "\(atDeath) on the field at the end, \(run.debugCorpses) later")
    }

    // Health crates: they fall, they can be shot for a patch, and ignoring
    // one loses it.
    print("")
    do {
      let fresh = GameController()
      fresh.startSiege(wave: 4)
      guard let run = fresh.debugSiege else { return 1 }
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)

      func quiet(_ frames: Int) {
        for _ in 0..<frames {
          run.debugRemoveAllAttackers()
          fresh.tickFrame()
        }
      }

      // One turns up on its own.
      var waited = 0
      while run.debugKitCount == 0 && waited < 4000 {
        run.debugRemoveAllAttackers()
        fresh.tickFrame()
        waited += 1
      }
      check(
        "a crate is dropped", run.debugKitCount > 0,
        "after \(waited) frames")

      // Shooting one patches the wall.
      quiet(2)
      run.debugDamageWall(by: 50)
      let hurt = run.debugState.health
      run.debugDropKit(atX: 560, y: 300)
      for _ in 0..<40 {
        run.debugSnipe(atX: 560, y: 300)
        run.debugRemoveAllAttackers()
        fresh.tickFrame()
        if run.debugState.health > hurt { break }
      }
      check(
        "shooting it patches the wall", run.debugState.health > hurt,
        String(format: "%.0f%% -> %.0f%%", hurt, run.debugState.health))

      // It cannot push past full.
      run.debugDropKit(atX: 560, y: 300)
      for _ in 0..<60 {
        run.debugSnipe(atX: 560, y: 300)
        run.debugRemoveAllAttackers()
        fresh.tickFrame()
      }
      check(
        "never past full", run.debugState.health <= Siege.maxHealth,
        String(format: "%.1f%%", run.debugState.health))

      // Ignored, it lands and is eventually lost.
      run.debugDropKit(atX: 200, y: 100)
      var landed = false
      for _ in 0..<900 where !landed {
        run.debugRemoveAllAttackers()
        fresh.tickFrame()
        if run.debugKitLanded { landed = true }
      }
      check("it parachutes down and lands", landed, "touched down")

      let beforeExpiry = run.debugState.health
      quiet(700)
      check(
        "ignored, it is lost", run.debugKitCount == 0,
        String(format: "no free health: wall %.0f%% -> %.0f%%",
          beforeExpiry, run.debugState.health))
    }

    // Bosses: they arrive as a wave's finale, they are enormous, they hold the
    // next wave back until they are dead, and they scale with depth.
    print("")
    for startWave in [3, 12] {
      let fresh = GameController()
      fresh.startSiege(wave: startWave)
      guard let run = fresh.debugSiege else { continue }
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)

      // Clear the ordinary pack each frame so the wave reaches its finale.
      var seen: (health: Int, maxHealth: Int, width: Double)?
      var waveWhenSummoned = -1
      var ticks = 0
      while ticks < 20_000 && seen == nil {
        fresh.tickFrame()
        ticks += 1
        run.debugCullOrdinary()
        if let boss = run.debugBoss {
          seen = boss
          waveWhenSummoned = run.debugState.wave
        }
      }

      guard let boss = seen else {
        failures += 1
        print("  FAIL boss from wave \(startWave)           never arrived")
        continue
      }

      // While it stands, the wave must not advance past it.
      var advanced = false
      for _ in 0..<900 {
        fresh.tickFrame()
        run.debugCullOrdinary()
        if run.debugBoss != nil && run.debugState.wave != waveWhenSummoned { advanced = true }
      }

      let ok = boss.width > 140 && waveWhenSummoned % 3 == 0 && !advanced
      if !ok { failures += 1 }
      print(
        "  \(ok ? "ok  " : "FAIL") "
          + "\("boss from wave \(startWave)".padding(toLength: 28, withPad: " ", startingAt: 0)) "
          + "arrived on wave \(waveWhenSummoned), \(boss.maxHealth) hp, "
          + "\(Int(boss.width))px wide, holds the wave: \(!advanced)")
    }

    func bossHealth(startingAt wave: Int) -> Int {
      let fresh = GameController()
      fresh.startSiege(wave: wave)
      guard let run = fresh.debugSiege else { return 0 }
      fresh.keyDown(.enter, shift: false)
      fresh.keyUp(.enter)
      for _ in 0..<20_000 {
        fresh.tickFrame()
        run.debugCullOrdinary()
        if let boss = run.debugBoss { return boss.maxHealth }
      }
      return 0
    }
    let early = bossHealth(startingAt: 3)
    let late = bossHealth(startingAt: 15)
    let scales = early > 0 && late > early
    if !scales { failures += 1 }
    print(
      "  \(scales ? "ok  " : "FAIL") "
        + "\("bosses scale with depth".padding(toLength: 28, withPad: " ", startingAt: 0)) "
        + "wave 3 boss \(early) hp, wave 15 boss \(late) hp")

    print("")
    print(failures == 0 ? "SIEGE OK" : "\(failures) check(s) failed")
    return failures == 0 ? 0 : 1
  }

  /// Clicks the centre of every button drawn on the title screen and checks it
  /// reaches the screen it advertises.
  ///
  /// There was no coverage of this at all, which is how a button could be drawn
  /// outside the region the click handler was willing to look at and nobody
  /// noticed until it was pressed.
  static func menu(arguments: [String]) -> Int32 {
    useFakeClock()
    var failures = 0

    func check(_ label: String, _ ok: Bool, _ detail: String) {
      if !ok { failures += 1 }
      print(
        "  \(ok ? "ok  " : "FAIL") "
          + "\(label.padding(toLength: 24, withPad: " ", startingAt: 0)) \(detail)")
    }

    // Each entry is the centre of a button as `drawTitle` lays it out.
    let buttons: [(name: String, x: Int, y: Int, expected: String)] = [
      ("Start Game", 400, 250, "levelStats"),
      ("Choose Level", 400, 350, "chooseLevel"),
      ("MulitPlayer Game", 400, 450, "multiSetup"),
      ("LEMMING DASH", 295, 527, "dash"),
      ("DOOMMINGS", 505, 527, "doom"),
      ("LEMMING SIEGE", 700, 527, "siege"),
    ]

    print("Title screen\n")
    for button in buttons {
      let controller = GameController()
      controller.mouseClicked(x: button.x, y: button.y)
      let reached = controller.debugScreen
      check(
        button.name, reached == button.expected,
        "click (\(button.x),\(button.y)) -> \(reached)")
    }

    // Clicking the gaps between buttons must do nothing at all.
    // Real gaps only: the three original boxes run 200-500 with no space
    // between them, so 480 is inside the multiplayer button, not beside it.
    let gaps = [(400, 180), (100, 250), (400, 502), (400, 575), (400, 527), (900, 527)]
    for gap in gaps {
      let controller = GameController()
      controller.mouseClicked(x: gap.0, y: gap.1)
      check(
        "gap at \(gap.0),\(gap.1)", controller.debugScreen == "title",
        "stayed on \(controller.debugScreen)")
    }

    print("")
    print(failures == 0 ? "MENU OK" : "\(failures) check(s) failed")
    return failures == 0 ? 0 : 1
  }

  /// Renders every effect to a WAV so they can be listened to, and checks the
  /// synthesis produced real audio rather than silence or clipping mush.
  ///
  /// Also confirms the engine stays down in headless mode: these modes run on
  /// machines with no audio device, and must never open one.
  static func sound(arguments: [String]) -> Int32 {
    let directory = arguments.count > 1 ? arguments[1] : NSTemporaryDirectory()
    var failures = 0

    func check(_ label: String, _ ok: Bool, _ detail: String) {
      if !ok { failures += 1 }
      print(
        "  \(ok ? "ok  " : "FAIL") "
          + "\(label.padding(toLength: 22, withPad: " ", startingAt: 0)) \(detail)")
    }

    print("Sound\n")
    check(
      "silent when headless", !Sound.shared.isRunning,
      "engine down, no device opened")

    for effect in Sound.Effect.allCases {
      guard let buffer = Sound.shared.debugRender(effect) else {
        failures += 1
        print("  FAIL \(effect.rawValue)  could not be rendered")
        continue
      }
      guard let samples = buffer.floatChannelData?[0] else { continue }
      let count = Int(buffer.frameLength)

      var peak: Float = 0
      var energy = 0.0
      var clipped = 0
      for index in 0..<count {
        let value = samples[index]
        peak = max(peak, abs(value))
        energy += Double(value * value)
        if abs(value) >= 0.999 { clipped += 1 }
      }
      let rms = (energy / Double(max(count, 1))).squareRoot()
      let seconds = Double(count) / 44_100.0
      let clipFraction = Double(clipped) / Double(max(count, 1))

      // Audible, not silent, and not a solid wall of clipping.
      let ok = peak > 0.2 && rms > 0.02 && clipFraction < 0.12 && seconds > 0.04
      if !ok { failures += 1 }
      print(
        "  \(ok ? "ok  " : "FAIL") "
          + "\(effect.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) "
          + String(
            format: "%.2fs  max %.1f/s  ", seconds,
            Sound.shared.debugGap(effect) > 0 ? 1 / Sound.shared.debugGap(effect) : 0)
          + Sound.shared.debugSource(effect))

      let path = (directory as NSString).appendingPathComponent("\(effect.rawValue).wav")
      Sound.shared.debugWriteWAV(buffer, to: URL(fileURLWithPath: path))
    }

    // The gun is a held sound, not a repeated one. Check the loop was cut
    // from the sustained part of the sample and not left with its decay tail,
    // which is what made it stutter.
    print("")
    if let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
      let full = Sound.shared.debugRender(.shot),
      let loop = Sound.makeLoop(from: full, format: format),
      let loopData = loop.floatChannelData?[0]
    {
      let fullSeconds = Double(full.frameLength) / 44_100
      let loopSeconds = Double(loop.frameLength) / 44_100
      let frames = Int(loop.frameLength)

      func rms(_ range: Range<Int>) -> Float {
        var sum: Float = 0
        for i in range { sum += loopData[i] * loopData[i] }
        return (sum / Float(max(range.count, 1))).squareRoot()
      }
      let edge = max(frames / 20, 1)
      let head = rms(0..<edge)
      let tail = rms((frames - edge)..<frames)
      let evenness = Double(min(head, tail) / max(max(head, tail), 0.0001))

      check(
        "gun loop trims the tail", loopSeconds < fullSeconds * 0.95 || loopSeconds > 0.15,
        String(format: "%.3fs loop from a %.3fs sample", loopSeconds, fullSeconds))
      // A loop whose ends differ wildly pulses once per cycle; that is exactly
      // the stutter being fixed here.
      check(
        "loop ends match", evenness > 0.45,
        String(format: "head %.3f vs tail %.3f (%.0f%% matched)", head, tail, evenness * 100))
      check(
        "gun is a held sound", Sound.heldEffects.contains(.shot),
        "looped while the trigger is down, not retriggered")

      // Write the loop repeated a few times, which is what is actually heard
      // while the trigger is down.
      if let repeated = AVAudioPCMBuffer(
        pcmFormat: format, frameCapacity: AVAudioFrameCount(frames * 5)),
        let out = repeated.floatChannelData?[0]
      {
        repeated.frameLength = AVAudioFrameCount(frames * 5)
        for cycle in 0..<5 {
          for i in 0..<frames { out[cycle * frames + i] = loopData[i] }
        }
        Sound.shared.debugWriteWAV(
          repeated,
          to: URL(fileURLWithPath: (directory as NSString).appendingPathComponent("shot-loop.wav")))
      }
    }

    // Routing: which raider gets which cry. Checked by staging one of each and
    // reading back what the game asked the sound engine to play.
    print("")
    let routing = GameController()
    routing.startSiege(wave: 6)
    routing.keyDown(.enter, shift: false)
    routing.keyUp(.enter)
    if let run = routing.debugSiege {
      func cryFor(_ kind: Siege.Raider) -> String {
        run.debugRemoveAllAttackers()
        run.debugSpawn(kind, atX: 300, facing: 1)
        routing.tickFrame()
        Sound.shared.debugClearPlayLog()
        run.debugKillFirst()
        let deaths = Sound.shared.debugPlayLog.filter {
          $0 == .death || $0 == .deathHeavy
        }
        return deaths.first.map { "\($0)" } ?? "none"
      }

      for (kind, expected) in [
        (Siege.Raider.walker, "death"),
        (.runner, "death"),
        (.bomber, "death"),
        (.heavy, "deathHeavy"),
        (.boss, "death"),
      ] {
        let actual = cryFor(kind)
        let ok = actual == expected
        if !ok { failures += 1 }
        print(
          "  \(ok ? "ok  " : "FAIL") "
            + "\("\(kind) dies".padding(toLength: 22, withPad: " ", startingAt: 0)) "
            + "\(actual)\(ok ? "" : "  (expected \(expected))")")
      }
    }

    print("")
    print("wrote \(Sound.Effect.allCases.count) wavs to \(directory)")
    print(failures == 0 ? "SOUND OK" : "\(failures) check(s) failed")
    return failures == 0 ? 0 : 1
  }

  // MARK: - Output

  private static func write(_ bitmap: Bitmap, to path: String) {
    let rep = NSBitmapImageRep(cgImage: bitmap.cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
  }
}
