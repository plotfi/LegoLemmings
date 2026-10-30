import CoreGraphics

/// The shapes a level can take.
///
/// Every one lays out a route the lemmings walk unaided from the spawn to a
/// gate, and the gate is the only thing between them and the exit. The route is
/// one-way by construction: lemmings keep whatever direction they are facing
/// when they land, each platform's far edge overhangs the next thing down, and
/// the near border catches anyone who walks back the other way at the start.
///
/// Heights are accumulated downward from the spawn, never clamped at the
/// bottom. Clamping is what silently produced shafts with no room to fall in
/// and doors with no headroom; letting the floor land where the arithmetic puts
/// it keeps every drop honest.
enum Template: String, CaseIterable {
  /// Two terraces down into a single dig gate. The gentlest shape.
  case cascade
  /// Bash through a wall, then dig through a floor. Two abilities, in order.
  case gallery
  /// Chambers stacked straight down, each dug out of the one above.
  case vault
  /// A terrace over a flooded basin, then a bash gate into the exit hall.
  case chasm
  /// A staircase of narrow ledges all the way down to a dig gate.
  case spire

  func build(_ b: Builder) {
    switch self {
    case .cascade: Template.cascade(b)
    case .gallery: Template.gallery(b)
    case .vault: Template.vault(b)
    case .chasm: Template.chasm(b)
    case .spire: Template.spire(b)
    }
  }

  /// How far a pillar stands above its chamber floor. Anything over about 19px
  /// is a wall a lemming turns at rather than climbs; this leaves plenty of
  /// margin while staying cheap in vertical budget.
  static let pillarLift = 68

  /// The lowest a chamber floor may sit and still leave the room below it, the
  /// door, and some solid ground underneath.
  static let deepestGround = 688

  // MARK: - Shared pieces

  /// Fills the leftover ground past the last pillar with a hazard basin —
  /// scenery, and a warning about digging in the wrong room.
  private static func hazardApron(_ b: Builder, fromU: Int, groundTop: Int) {
    let from = fromU + 40
    let to = Builder.travelSpan - 24
    guard to - from > 90, groundTop + 76 < Builder.bedrock else { return }
    b.carve(from, to, groundTop, groundTop + 76)
    b.pool(from, to, groundTop + 34, groundTop + 76)
  }

  // MARK: - Cascade

  private static func cascade(_ b: Builder) {
    let spawnTop = Builder.minTerrainTop + b.rng.int(0, 26)
    let terraceTop = spawnTop + b.rng.int(74, 96)
    let pillarTop = terraceTop + b.rng.int(44, 62)
    let floorTop = pillarTop + pillarLift
    let thickness = b.rng.int(40, 48)
    let groundTop = floorTop + thickness + b.rng.int(90, 116)

    let u0 = 290 + b.rng.int(0, 50)
    let u1 = u0 + 270 + b.rng.int(0, 60)
    let interior = 210 + b.rng.int(0, 60)

    b.ground(top: groundTop)
    b.spawnLedge(length: u0, top: spawnTop)
    b.platform(u0, u1, top: terraceTop, thickness: 110)
    b.check(drop: terraceTop - spawnTop, what: "spawn to terrace")
    b.check(drop: pillarTop - terraceTop, what: "terrace to pillar")

    let room = b.digChamber(
      atU: u1, interior: interior, floorTop: floorTop, floorThickness: thickness,
      groundTop: groundTop, pillarLift: pillarLift)

    b.placeDoor(uCenter: (room.near + room.far) / 2, floorTop: groundTop)
    hazardApron(b, fromU: room.far + 44, groundTop: groundTop)
  }

  // MARK: - Gallery

  private static func gallery(_ b: Builder) {
    let spawnTop = Builder.minTerrainTop + b.rng.int(0, 24)
    let terraceTop = spawnTop + b.rng.int(74, 94)
    let pillarTop = terraceTop + b.rng.int(44, 60)
    let hallTop = pillarTop + pillarLift
    let thickness = b.rng.int(40, 48)
    let groundTop = hallTop + thickness + b.rng.int(90, 114)

    let u0 = 250 + b.rng.int(0, 40)
    let u1 = u0 + 230 + b.rng.int(0, 40)
    let hallInterior = 170 + b.rng.int(0, 40)
    let wallThickness = b.rng.int(58, 78)

    b.ground(top: groundTop)
    b.spawnLedge(length: u0, top: spawnTop)
    b.platform(u0, u1, top: terraceTop, thickness: 110)
    b.check(drop: terraceTop - spawnTop, what: "spawn to terrace")
    b.check(drop: pillarTop - terraceTop, what: "terrace to pillar")

    // First gate: the hall's far wall is the only way on, and it is thin.
    let afterWall = b.bashChamber(
      atU: u1, interior: hallInterior, floorTop: hallTop, floorThickness: 110,
      wallThickness: wallThickness, groundTop: groundTop, pillarLift: pillarLift)

    // Second gate: beyond the tunnel, at the same height, a floor to dig.
    let room = b.digChamber(
      atU: afterWall,
      interior: max(min(190 + b.rng.int(0, 40), Builder.travelSpan - afterWall - 110), 130),
      floorTop: hallTop, floorThickness: thickness, groundTop: groundTop,
      pillarLift: pillarLift, nearPillar: false)

    b.placeDoor(uCenter: (room.near + room.far) / 2, floorTop: groundTop)
  }

  // MARK: - Vault

  private static func vault(_ b: Builder) {
    let spawnTop = Builder.minTerrainTop + b.rng.int(0, 22)
    let pillarTop = spawnTop + b.rng.int(44, 58)
    let topFloor = pillarTop + pillarLift
    let thickness = b.rng.int(34, 42)
    let secondFloor = topFloor + thickness + b.rng.int(88, 106)
    let groundTop = secondFloor + thickness + b.rng.int(96, 114)

    let u0 = 280 + b.rng.int(0, 50)
    let interior = 300 + b.rng.int(0, 70)
    let pillarWidth = 44
    let near = u0 + pillarWidth / 2
    let far = near + interior
    let mid = (near + far) / 2

    b.ground(top: groundTop)
    b.spawnLedge(length: u0, top: spawnTop)
    b.check(drop: pillarTop - spawnTop, what: "spawn to pillar")

    // Two pillars from the top storey all the way to the floor. They pen the
    // lemmings into every storey on the way down, which is what makes each
    // one a fair place to spend a digger.
    b.column(u0 - pillarWidth / 2, near, top: pillarTop, base: groundTop, material: .rock)
    b.column(far, far + pillarWidth, top: pillarTop, base: groundTop, material: .rock)

    // The two floors are staggered: each is diggable on one half and solid on
    // the other, and the halves are opposite. A shaft sunk through the upper
    // floor therefore always lands on solid lower floor, so the two can never
    // line up into a single drop deep enough to kill everyone who follows.
    b.platform(near, mid, top: topFloor, thickness: thickness, material: .dirt)
    b.platform(mid, far, top: topFloor, thickness: thickness, material: .rock)
    b.platform(near, mid, top: secondFloor, thickness: thickness, material: .rock)
    b.platform(mid, far, top: secondFloor, thickness: thickness, material: .dirt)

    // Trimmed by a sprite width on the right, so a digger at the edge of its
    // half cannot sink its shaft through the solid half next to it.
    let upper = b.span(near + 12, mid - 12)
    b.appendGate(
      Gate(ability: "digger", x: upper.x, y: topFloor - 44, w: max(upper.w - 40, 36), h: 46))
    let lower = b.span(mid + 12, far - 12)
    b.appendGate(
      Gate(ability: "digger", x: lower.x, y: secondFloor - 44, w: max(lower.w - 40, 36), h: 46))

    b.check(drop: secondFloor - (topFloor + thickness), what: "vault upper shaft")
    b.check(drop: groundTop - (secondFloor + thickness), what: "vault lower shaft")

    b.placeDoor(uCenter: mid, floorTop: groundTop)
    hazardApron(b, fromU: far + pillarWidth, groundTop: groundTop)
  }

  // MARK: - Chasm

  private static func chasm(_ b: Builder) {
    let spawnTop = Builder.minTerrainTop + b.rng.int(8, 30)
    let terraceTop = spawnTop + b.rng.int(74, 96)
    let pillarTop = terraceTop + b.rng.int(46, 64)
    let hallTop = pillarTop + pillarLift
    let groundTop = hallTop + b.rng.int(110, 145)

    let u0 = 260 + b.rng.int(0, 44)
    let u1 = u0 + 280 + b.rng.int(0, 50)
    let hallInterior = 180 + b.rng.int(0, 44)
    let wallThickness = b.rng.int(58, 80)

    b.ground(top: groundTop)
    b.spawnLedge(length: u0, top: spawnTop)
    b.platform(u0, u1, top: terraceTop, thickness: 96)
    b.check(drop: terraceTop - spawnTop, what: "spawn to terrace")
    b.check(drop: pillarTop - terraceTop, what: "terrace to pillar")

    // A flooded basin in the ground under the terrace the lemmings cross.
    if groundTop + 78 < Builder.bedrock {
      b.carve(u0 + 30, u1 - 30, groundTop, groundTop + 78)
      b.pool(u0 + 30, u1 - 30, groundTop + 32, groundTop + 78)
    }

    let afterWall = b.bashChamber(
      atU: u1, interior: hallInterior, floorTop: hallTop, floorThickness: 110,
      wallThickness: wallThickness, groundTop: groundTop, pillarLift: pillarLift)

    // Beyond the tunnel the floor runs on to the far border, which seals the
    // exit hall without needing a pillar of its own.
    b.platform(afterWall, Builder.travelSpan, top: hallTop, thickness: 110)
    b.placeDoor(uCenter: (afterWall + Builder.travelSpan) / 2, floorTop: hallTop)
  }

  // MARK: - Spire

  private static func spire(_ b: Builder) {
    let spawnTop = Builder.minTerrainTop + b.rng.int(0, 16)
    let steps = 3
    var stepDrops = (0..<steps).map { _ in b.rng.int(50, 64) }
    let toPillar = b.rng.int(38, 52)
    let thickness = b.rng.int(36, 44)
    let shaft = b.rng.int(84, 104)

    // The staircase is the only flexible part of the budget, so if the floor
    // would end up too deep, take it out of the steps rather than clamping the
    // floor and leaving the shaft with nowhere to fall.
    func groundFor(_ drops: [Int]) -> Int {
      spawnTop + drops.reduce(0, +) + toPillar + pillarLift + thickness + shaft
    }
    while groundFor(stepDrops) > deepestGround {
      guard let largest = stepDrops.indices.max(by: { stepDrops[$0] < stepDrops[$1] }),
        stepDrops[largest] > 38
      else { break }
      stepDrops[largest] -= 3
    }

    var top = spawnTop
    let groundTop = groundFor(stepDrops)
    let u0 = 210 + b.rng.int(0, 36)
    let stepWidth = (Builder.travelSpan - u0 - 300) / steps
    var u = u0

    b.ground(top: groundTop)
    b.spawnLedge(length: u0, top: spawnTop)

    for drop in stepDrops {
      top += drop
      b.check(drop: drop, what: "spire step")
      b.platform(u, u + stepWidth, top: top, thickness: 84)
      u += stepWidth
    }
    b.check(drop: toPillar, what: "spire to pillar")

    let room = b.digChamber(
      atU: u, interior: max(Builder.travelSpan - u - 110, 150),
      floorTop: top + toPillar + pillarLift, floorThickness: thickness,
      groundTop: groundTop, pillarWidth: 40, pillarLift: pillarLift)

    b.placeDoor(uCenter: (room.near + room.far) / 2, floorTop: groundTop)
  }
}
