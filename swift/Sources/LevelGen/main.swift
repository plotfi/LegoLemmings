import AppKit
import Foundation

/// Generates themed levels: art, collision mask, chooser entries, and a hint
/// file naming the ability each gate wants, so the game's verifier can play the
/// intended solution back.
///
///     swift run LevelGen [assetsDirectory]

struct LevelConfig {
  var theme: Theme
  var template: Template
  /// +1 if lemmings walk right from the spawn, -1 if they walk left.
  var direction: Int
  var seed: UInt64
  var count: Int
  /// Release rate as written in the chooser file; the game uses `100 - rate`.
  var rate: Int
  /// Fraction of the lemmings that must be saved.
  var goalFraction: Double
  var minutes: Int
  /// Uses of each ability, in order: digger, blocker, floater, exploder,
  /// bridger, climber, miner, basher. `-1` means not available on this level.
  var abilities: [Int]
}

let configs: [LevelConfig] = [
  LevelConfig(
    theme: Themes.pirates, template: .cascade, direction: 1, seed: 1001,
    count: 50, rate: 55, goalFraction: 0.40, minutes: 8,
    abilities: [8, 6, 4, -1, 3, -1, -1, 4]),
  LevelConfig(
    theme: Themes.space, template: .vault, direction: -1, seed: 1002,
    count: 50, rate: 60, goalFraction: 0.50, minutes: 7,
    abilities: [10, 5, 6, 3, -1, -1, -1, -1]),
  LevelConfig(
    theme: Themes.castle, template: .gallery, direction: 1, seed: 1003,
    count: 50, rate: 58, goalFraction: 0.50, minutes: 8,
    abilities: [6, 6, -1, -1, 4, 3, -1, 6]),
  LevelConfig(
    theme: Themes.western, template: .chasm, direction: -1, seed: 1004,
    count: 45, rate: 60, goalFraction: 0.50, minutes: 7,
    abilities: [4, 5, -1, 3, 4, -1, 3, 8]),
  LevelConfig(
    theme: Themes.arctic, template: .spire, direction: 1, seed: 1005,
    count: 50, rate: 62, goalFraction: 0.50, minutes: 7,
    abilities: [6, 4, 8, -1, 3, 4, -1, -1]),
  LevelConfig(
    theme: Themes.jungle, template: .cascade, direction: -1, seed: 1006,
    count: 50, rate: 55, goalFraction: 0.40, minutes: 8,
    abilities: [8, 6, 3, -1, 5, 4, 3, 5]),
  LevelConfig(
    theme: Themes.aquazone, template: .vault, direction: 1, seed: 1007,
    count: 50, rate: 62, goalFraction: 0.50, minutes: 7,
    abilities: [9, 4, 6, -1, -1, -1, 4, 3]),
  LevelConfig(
    theme: Themes.dino, template: .chasm, direction: 1, seed: 1008,
    count: 45, rate: 65, goalFraction: 0.55, minutes: 6,
    abilities: [3, 4, -1, 3, 3, -1, -1, 7]),
  LevelConfig(
    theme: Themes.pharaoh, template: .gallery, direction: -1, seed: 1009,
    count: 50, rate: 65, goalFraction: 0.55, minutes: 6,
    abilities: [5, 3, -1, 2, -1, 3, 4, 5]),
  LevelConfig(
    theme: Themes.city, template: .spire, direction: -1, seed: 1010,
    count: 50, rate: 62, goalFraction: 0.50, minutes: 7,
    abilities: [6, 5, 6, -1, 4, -1, -1, 4]),
  LevelConfig(
    theme: Themes.ninja, template: .gallery, direction: 1, seed: 1011,
    count: 45, rate: 68, goalFraction: 0.55, minutes: 6,
    abilities: [4, 3, -1, 2, 3, 4, -1, 5]),
  LevelConfig(
    theme: Themes.train, template: .cascade, direction: 1, seed: 1012,
    count: 50, rate: 60, goalFraction: 0.45, minutes: 7,
    abilities: [7, 5, -1, -1, 5, -1, 4, 4]),
  LevelConfig(
    theme: Themes.volcano, template: .chasm, direction: -1, seed: 1013,
    count: 40, rate: 70, goalFraction: 0.55, minutes: 6,
    abilities: [3, 3, 6, 2, 3, -1, -1, 6]),
  LevelConfig(
    theme: Themes.factory, template: .vault, direction: -1, seed: 1014,
    count: 45, rate: 68, goalFraction: 0.55, minutes: 6,
    abilities: [8, 3, -1, 2, -1, -1, 3, 3]),
  LevelConfig(
    theme: Themes.haunted, template: .spire, direction: 1, seed: 1015,
    count: 45, rate: 70, goalFraction: 0.55, minutes: 6,
    abilities: [5, 3, 4, 2, 3, 3, -1, -1]),
  LevelConfig(
    theme: Themes.mars, template: .cascade, direction: -1, seed: 1016,
    count: 50, rate: 60, goalFraction: 0.45, minutes: 7,
    abilities: [7, 5, 5, -1, 4, 3, 3, -1]),
]

// MARK: - Generation

let assetsDirectory =
  CommandLine.arguments.count > 1
  ? CommandLine.arguments[1]
  : URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("assets").path

guard FileManager.default.fileExists(atPath: assetsDirectory) else {
  print("No assets directory at \(assetsDirectory)")
  exit(1)
}

print("Writing to \(assetsDirectory)\n")

/// Ability names in the order the chooser file lists them.
let abilityNames = [
  "digger", "blocker", "floater", "exploder", "bridger", "climber", "miner", "basher",
]

var chooserLines: [String] = []
var hintLines: [String] = []
var failures = 0

for (index, config) in configs.enumerated() {
  let theme = config.theme

  // Lay the level out once on a throwaway builder, purely to learn where the
  // floor ends up, so the scenery can be anchored to it. Same seed, same RNG
  // sequence, so the real pass below reproduces the identical layout.
  let probe = Builder(theme: theme, seed: config.seed, direction: config.direction)
  config.template.build(probe)
  let groundY = probe.groundTop
  let sceneryShift = min(max(groundY - Themes.nominalGround, -70), 130)

  let builder = Builder(theme: theme, seed: config.seed, direction: config.direction)
  let canvas = builder.canvas
  // Scenery draws from its own stream, so adding or changing a prop can never
  // shift the terrain the probe just measured.
  var decorRng = RNG(seed: config.seed &+ 0x5EED)

  // Sky, flat below y=200 so the color the digging code samples at (200, 200)
  // is the same color carved terrain gets painted with everywhere.
  // Flat below y=180, so the patch stamped over the sampled pixel later is
  // indistinguishable from the sky around it.
  canvas.skyGradient(top: theme.sky, bottom: theme.skyHorizon ?? theme.sky, fadeTo: 180)
  canvas.withVerticalShift(sceneryShift) {
    theme.backdrop(canvas, &decorRng, theme, groundY)
  }
  canvas.stampSkySample(color: theme.skyHorizon ?? theme.sky)

  // Indestructible frame, so nothing can be dug out of the level.
  let b = Builder.border
  canvas.fill(0, 0, Builder.width, b, .rock, art: theme.rock)
  canvas.fill(0, Builder.height - b, Builder.width, b, .rock, art: theme.rock)
  canvas.fill(0, 0, b, Builder.height, .rock, art: theme.rock)
  canvas.fill(Builder.width - b, 0, b, Builder.height, .rock, art: theme.rock)

  config.template.build(builder)

  // Finishing passes.
  canvas.speckle(
    material: .dirt, &decorRng,
    colors: [theme.dirt.darker(0.12), theme.dirt.lighter(0.12)], count: 900)
  canvas.speckle(
    material: .rock, &decorRng,
    colors: [theme.rock.darker(0.15), theme.rock.lighter(0.15)], count: 400)
  canvas.applySurfaceStripe(material: .dirt, color: theme.dirtTop, depth: 8)
  canvas.applySurfaceStripe(material: .rock, color: theme.rockEdge, depth: 5)
  canvas.applyUnderShadow(material: .dirt, color: theme.dirt.darker(0.25), depth: 3)
  builder.drawDoors()
  theme.overlay(canvas, &decorRng, theme, groundY)
  canvas.stampSkySample(color: theme.skyHorizon ?? theme.sky)

  // MARK: Validation

  var errors = builder.problems

  let legal: Set<UInt32> = [0x000000, 0xFF0000, 0x00FF00, 0x0000FF, 0xFFFFFF]
  let found = canvas.maskColors()
  let illegal = found.subtracting(legal)
  if !illegal.isEmpty {
    errors.append(
      "mask has \(illegal.count) illegal color(s): "
        + illegal.prefix(4).map { String(format: "#%06X", $0) }.joined(separator: " "))
  }

  // The dig code repaints carved terrain with the art pixel at (200, 200).
  let skyKey = UInt32(
    (theme.skyHorizon ?? theme.sky).r << 16 | (theme.skyHorizon ?? theme.sky).g << 8
      | (theme.skyHorizon ?? theme.sky).b)
  if canvas.artColor(atX: 200, y: 200) != skyKey {
    errors.append(
      String(
        format: "art(200,200) is #%06X, expected the sky color #%06X",
        canvas.artColor(atX: 200, y: 200), skyKey))
  }
  if canvas.maskColor(atX: 200, y: 200) != 0x000000 {
    errors.append("mask(200,200) is not empty space")
  }

  // The spawn has to be in open air with ground a short way below it.
  let sx = builder.start.x + 18
  let sy = builder.start.y
  if canvas.maskColor(atX: sx, y: sy + 20) != 0x000000 {
    errors.append("spawn point is inside terrain")
  }
  var dropToGround = 0
  while sy + 41 + dropToGround < Builder.height - 1,
    canvas.maskColor(atX: sx, y: sy + 41 + dropToGround) == 0x000000
  {
    dropToGround += 1
  }
  if dropToGround > 60 {
    errors.append("spawn drops \(dropToGround)px before hitting ground")
  }

  if builder.doors.isEmpty {
    errors.append("no exit was placed")
  }
  if builder.gates.isEmpty {
    errors.append("no gate was placed")
  }

  // Each door needs standing room above it and solid ground beneath it.
  for door in builder.doors {
    let dx = builder.toX(door.uCenter)
    let floor = door.floorTop
    var headroom = 0
    while floor - 50 - headroom > 0,
      canvas.maskColor(atX: dx, y: floor - 50 - headroom) == 0x000000
    {
      headroom += 1
    }
    if headroom < 30 {
      errors.append("door at \(dx),\(floor) has only \(headroom)px of headroom")
    }
    if canvas.maskColor(atX: dx, y: floor + 4) == 0x000000 {
      errors.append("door at \(dx),\(floor) has no floor under it")
    }
    if canvas.maskColor(atX: dx, y: floor - 24) != 0x0000FF {
      errors.append("door at \(dx),\(floor) is not blue at lemming eye level")
    }
  }

  // Each gate room needs air to pace in and terrain to work on.
  for gate in builder.gates {
    let gx = gate.x + gate.w / 2
    if canvas.maskColor(atX: gx, y: gate.y + 20) != 0x000000 {
      errors.append("\(gate.ability) room at \(gx) is filled in")
    }
    let floorY = gate.y + gate.h + 2
    if canvas.maskColor(atX: gx, y: floorY) != 0xFF0000 {
      errors.append("\(gate.ability) room at \(gx) has no diggable floor")
    }
  }

  // Make sure the level actually grants the abilities its gates need.
  var abilities = config.abilities
  for gate in builder.gates {
    guard let slot = abilityNames.firstIndex(of: gate.ability) else { continue }
    let needed = max(4, builder.gates.filter { $0.ability == gate.ability }.count + 2)
    if abilities[slot] < needed {
      abilities[slot] = needed
    }
  }

  // MARK: Output

  let artPath = "\(assetsDirectory)/\(theme.file).png"
  let maskPath = "\(assetsDirectory)/\(theme.file)mask.png"
  try canvas.writePNGs(artPath: artPath, maskPath: maskPath)

  let goal = max(1, Int(Double(config.count) * config.goalFraction))
  chooserLines.append(
    "\(index + 4)||\(theme.file)||\(config.count)||\(config.rate)||\(goal)||\(config.minutes)"
      + "||\(builder.start.x),\(builder.start.y)")
  chooserLines.append(abilities.map(String.init).joined(separator: "||"))

  for gate in builder.gates {
    hintLines.append(
      "\(theme.file)|\(gate.ability)|\(gate.x)|\(gate.y)|\(gate.w)|\(gate.h)")
  }

  let status = errors.isEmpty ? "ok" : "PROBLEMS"
  print(
    "\(theme.file.padding(toLength: 10, withPad: " ", startingAt: 0)) "
      + "\(config.template.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) "
      + "dir\(config.direction > 0 ? "+" : "-") start=\(builder.start.x),\(builder.start.y) "
      + "gates=\(builder.gates.map { $0.ability }.joined(separator: ",")) \(status)")
  for error in errors {
    print("    ! \(error)")
    failures += 1
  }
}

// Rewrite the chooser file in place, replacing anything below the marker and
// leaving the hand-written levels above it untouched. Re-running the generator
// therefore updates the generated levels rather than appending a second copy.
let marker = "# --- generated levels ---"
let chooserPath = "\(assetsDirectory)/levelChooser.txt"
var chooser = (try? String(contentsOfFile: chooserPath, encoding: .utf8)) ?? ""
if let existing = chooser.range(of: marker) {
  chooser = String(chooser[..<existing.lowerBound])
}
let updated =
  chooser.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
  + marker + "\n" + chooserLines.joined(separator: "\n") + "\n"
try updated.write(toFile: chooserPath, atomically: true, encoding: .utf8)

let hints = """
# Generated by LevelGen. One line per gate, naming the ability the room needs.
# file|ability|x|y|w|h   -- the rect is where lemmings pile up waiting for it.
\(hintLines.joined(separator: "\n"))

"""
try hints.write(
  toFile: "\(assetsDirectory)/levelHints.txt", atomically: true, encoding: .utf8)

print("")
print("\(configs.count) levels, \(hintLines.count) gates")
print("chooser          -> \(chooserPath)")
print("gate hints       -> \(assetsDirectory)/levelHints.txt")
if failures > 0 {
  print("\(failures) problem(s) found")
  exit(1)
}
print("all levels validated")
