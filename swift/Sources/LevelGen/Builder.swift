import CoreGraphics

/// Where the player has to spend an ability to make progress, and the room the
/// lemmings pile up in while they wait for it. Written out alongside the level
/// so the verifier can play the intended solution.
struct Gate {
  var ability: String
  var x: Int
  var y: Int
  var w: Int
  var h: Int
}

/// Lays out a level's terrain.
///
/// Everything is placed in "travel space": `u` measures distance from the wall
/// the lemmings start against, growing in the direction they walk. Mirroring a
/// level left-to-right is then just a sign flip, and the geometry rules below
/// read the same either way.
///
/// The rules the engine imposes, which all the numbers here respect:
///
/// - A drop of more than about 228px kills on landing, so drops stay under 150.
/// - A step taller than ~19px is a wall a lemming turns around at, rather than
///   climbs, so retaining walls are 60px or more.
/// - A chamber bounded by a cliff on one side and a retaining wall on the other
///   holds lemmings indefinitely and safely — that is what makes a gate fair.
final class Builder {

  static let width = 1200
  static let height = 750
  static let border = 28
  /// Terrain runs down to here; below it is the bottom border.
  static let bedrock = 722
  /// How far `u` can run before hitting the far border.
  static let travelSpan = width - border * 2
  /// No terrain may sit above this line.
  ///
  /// The engine repaints dug-out terrain with whatever color the level art has
  /// at (200, 200), so that one pixel has to stay sky. Keeping every surface
  /// below it is the simplest way to guarantee that, whichever way round the
  /// level runs.
  static let minTerrainTop = 232

  let canvas: Canvas
  let theme: Theme
  var rng: RNG
  /// +1 if lemmings walk right from the start, -1 if they walk left.
  let direction: Int

  private(set) var gates: [Gate] = []
  /// Doors are recorded here and drawn after the finishing passes, so the
  /// surface-stripe pass cannot paint over the door frame.
  private(set) var doors: [(uCenter: Int, floorTop: Int)] = []
  private(set) var start = (x: 0, y: 0)
  private(set) var problems: [String] = []

  init(theme: Theme, seed: UInt64, direction: Int) {
    self.canvas = Canvas(width: Builder.width, height: Builder.height)
    self.theme = theme
    self.rng = RNG(seed: seed)
    self.direction = direction
  }

  // MARK: - Travel space

  func toX(_ u: Int) -> Int {
    direction > 0 ? Builder.border + u : Builder.width - Builder.border - u
  }

  /// The pixel range covered by `u0...u1`, in level coordinates.
  func span(_ u0: Int, _ u1: Int) -> (x: Int, w: Int) {
    let a = toX(u0)
    let b = toX(u1)
    return (min(a, b), abs(b - a))
  }

  // MARK: - Terrain

  /// Solid ground from `top` all the way down to bedrock.
  func block(_ u0: Int, _ u1: Int, top: Int, material: Material = .dirt) {
    let s = span(u0, u1)
    canvas.fill(s.x, top, s.w, Builder.bedrock - top, material, art: art(material))
  }

  /// Where the level's continuous floor sits, once a template has placed it.
  /// Scenery is anchored to this so props stand on the ground instead of
  /// floating at some fixed height that may or may not match the layout.
  private(set) var groundTop = 560

  /// The continuous floor across the whole level, under everything else.
  func ground(top: Int, material: Material = .dirt) {
    groundTop = top
    canvas.fill(0, top, Builder.width, Builder.bedrock - top, material, art: art(material))
  }

  /// A slab with open sky beneath it. Lemmings walk its top and fall off the
  /// far end onto whatever is next.
  func platform(_ u0: Int, _ u1: Int, top: Int, thickness: Int, material: Material = .dirt) {
    let s = span(u0, u1)
    canvas.fill(s.x, top, s.w, thickness, material, art: art(material))
  }

  /// A pillar. Used both as the wall that pens lemmings into a chamber and as
  /// the side of the room underneath it, which is why it runs to the floor.
  func column(_ u0: Int, _ u1: Int, top: Int, base: Int, material: Material = .dirt) {
    let s = span(u0, u1)
    canvas.fill(s.x, top, s.w, base - top, material, art: art(material))
  }

  /// A raised lip — tall enough to turn a lemming around.
  func wall(_ u0: Int, _ u1: Int, top: Int, base: Int, material: Material = .dirt) {
    let s = span(u0, u1)
    canvas.fill(s.x, top, s.w, base - top, material, art: art(material))
  }

  /// Cuts a void out of whatever is there.
  func carve(_ u0: Int, _ u1: Int, _ y0: Int, _ y1: Int) {
    let s = span(u0, u1)
    canvas.fill(s.x, y0, s.w, y1 - y0, .air, art: skyColor)
  }

  func pool(_ u0: Int, _ u1: Int, _ y0: Int, _ y1: Int) {
    let s = span(u0, u1)
    canvas.fill(s.x, y0, s.w, y1 - y0, .hazard, art: theme.hazard)
    canvas.decorate(s.x, y0, s.w, 5, theme.hazardTop)
  }

  func art(_ material: Material) -> RGB {
    switch material {
    case .dirt: return theme.dirt
    case .rock: return theme.rock
    case .hazard: return theme.hazard
    case .exit: return theme.doorway
    case .air: return skyColor
    }
  }

  var skyColor: RGB { theme.skyHorizon ?? theme.sky }

  // MARK: - Pieces

  /// The ledge the lemmings drop onto, backed against the near border.
  func spawnLedge(length: Int, top: Int, thickness: Int = 110) {
    platform(0, length, top: top, thickness: thickness)
    let x = toX(direction > 0 ? 60 : 60) - (direction > 0 ? 0 : 36)
    start = (x: x, y: top - 41 - 10)
  }

  /// A chamber: two pillars with a diggable floor slung between them, and the
  /// room they enclose underneath.
  ///
  /// Lemmings drop onto the near pillar, step off it into the chamber, and are
  /// then penned between the two pillars until somebody digs. The hole drops
  /// them into the room below, which the same two pillars wall in — so whatever
  /// direction they land facing, they find what is down there.
  ///
  /// Returns the span of the chamber interior, in travel space.
  @discardableResult
  func digChamber(
    atU: Int, interior: Int, floorTop: Int, floorThickness: Int, groundTop: Int,
    pillarWidth: Int = 44, pillarLift: Int = 68, landsOn: Int? = nil,
    nearPillar: Bool = true
  ) -> (near: Int, far: Int) {
    let pillarTop = floorTop - pillarLift
    // With no near pillar the caller already has a wall there — a bashed wall,
    // say — and adding another would seal the room the lemmings just opened.
    let nearEdge = nearPillar ? atU - pillarWidth / 2 + pillarWidth : atU
    let farPillar = nearEdge + interior

    // Pillars are indestructible on purpose. They are what pens the lemmings
    // into the chamber and into the room below it, so if they could be dug or
    // bashed through, a misaimed ability would open a hole into dead space and
    // strand everyone — which is exactly what it did while this was dirt.
    if nearPillar {
      column(atU - pillarWidth / 2, nearEdge, top: pillarTop, base: groundTop, material: .rock)
    }
    column(farPillar, farPillar + pillarWidth, top: pillarTop, base: groundTop, material: .rock)
    platform(nearEdge, farPillar, top: floorTop, thickness: floorThickness)

    // A lemming's position is its sprite's left edge, but it digs from the
    // middle of its body — so the right end of the room is trimmed by a sprite
    // width. Without that, a digger standing at the edge sinks its shaft
    // through whatever is next door instead of into the room below.
    let s = span(nearEdge + 10, farPillar - 10)
    appendGate(
      Gate(ability: "digger", x: s.x, y: floorTop - 44, w: max(s.w - 40, 36), h: 46))

    check(drop: (landsOn ?? groundTop) - (floorTop + floorThickness), what: "dig shaft")
    return (nearEdge, farPillar)
  }

  /// A chamber whose far wall is thin enough to bash through. Beyond it the
  /// floor carries on at the same height, so lemmings walk straight out of the
  /// tunnel they made.
  @discardableResult
  func bashChamber(
    atU: Int, interior: Int, floorTop: Int, floorThickness: Int, wallThickness: Int,
    groundTop: Int, pillarWidth: Int = 44, pillarLift: Int = 68
  ) -> Int {
    let pillarTop = floorTop - pillarLift
    let nearPillar = atU - pillarWidth / 2
    let wallU = nearPillar + pillarWidth + interior

    // Rock pen, dirt wall: the only thing in this room worth bashing is the
    // one wall that leads onward.
    column(nearPillar, nearPillar + pillarWidth, top: pillarTop, base: groundTop, material: .rock)
    platform(nearPillar + pillarWidth, wallU, top: floorTop, thickness: floorThickness)
    column(wallU, wallU + wallThickness, top: floorTop - 96, base: groundTop)

    // The whole hall, plus a little past the wall face. A lemming is only in
    // position to start bashing for a frame or two before it turns around, and
    // which side of its sprite that happens on depends on which way the level
    // runs — so the room is the gate, and whether a bash would actually take is
    // decided when the ability is handed over.
    let s = span(nearPillar + pillarWidth, wallU + 12)
    appendGate(Gate(ability: "basher", x: s.x, y: floorTop - 46, w: max(s.w, 44), h: 50))

    return wallU + wallThickness
  }

  func placeDoor(uCenter: Int, floorTop: Int) {
    doors.append((uCenter, floorTop))
  }

  func appendGate(_ gate: Gate) {
    gates.append(gate)
  }

  /// Draws every recorded door. Call once the finishing passes are done.
  func drawDoors() {
    for door in doors { drawDoor(uCenter: door.uCenter, floorTop: door.floorTop) }
  }

  private func drawDoor(uCenter: Int, floorTop: Int) {
    let doorX = toX(uCenter) - 21
    canvas.decorate(doorX - 8, floorTop - 62, 58, 62, theme.doorFrame)
    canvas.decorate(doorX - 8, floorTop - 62, 58, 6, theme.doorFrame.lighter(0.3))
    canvas.decorateEllipse(doorX - 2, floorTop - 70, 46, 30, theme.doorway)
    canvas.fill(doorX, floorTop - 49, 42, 49, .exit, art: theme.doorway)
  }

  // MARK: - Checks

  func check(drop: Int, what: String) {
    if drop > 150 {
      problems.append("\(what): drop of \(drop)px is close to fatal (limit ~228)")
    }
    if drop < 0 {
      problems.append("\(what): negative drop of \(drop)px")
    }
  }

  func note(_ message: String) {
    problems.append(message)
  }
}
