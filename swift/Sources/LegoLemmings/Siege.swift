import CoreGraphics
import Foundation

/// LEMMING SIEGE — hold a fortress against the horde.
///
/// The lemmings have stopped needing rescuing and started coming for you. They
/// pour in from both edges, converge on the tower in the middle, and chew on it
/// until it falls over. You have a cannon on the roof and a very high rate of
/// fire.
///
/// Built from the same sprite sheet as everything else: the raiders are the
/// walk frames, the heavies are the blocker pose scaled up, the bombers carry
/// the floater's umbrella, and everything that dies plays the puzzle game's own
/// three-frame death. The backdrop is a level painting, darkened.
final class Siege {

  // MARK: - Layout

  static let hudHeight = 40
  static let groundY = 505
  /// The tower, centred.
  static let fortressLeft = 340
  static let fortressRight = 460
  static let fortressTop = 300
  /// Where the cannon pivots, on the roof.
  /// The tower's centreline, and the height the guns are mounted at.
  static let towerCenterX = 400
  static let roofY = 286
  static let barrelLength = 58.0
  /// The two airships, by the centre of their envelope. Each carries a pair
  /// of guns, and both of a ship's guns ride the same drift.
  static let airships: [(x: Int, y: Int, bobPhase: Double)] = [
    (118, 158, 0.0),
    (682, 158, 1.9),
  ]

  /// Every gun emplacement. Tower mounts give absolute positions; airship
  /// mounts give an offset from their ship. `mirrored` guns reflect the aim
  /// about the horizon, the rest point straight at it.
  static let gunMounts: [(x: Int, y: Int, airship: Int?, mirrored: Bool)] = [
    (towerCenterX - 40, roofY, nil, false),
    (towerCenterX, roofY, nil, false),
    (towerCenterX + 40, roofY, nil, false),
    (-21, 2, 0, true),
    (21, 2, 0, false),
    (-21, 2, 1, true),
    (21, 2, 1, false),
  ]
  /// How far an airship drifts up and down as it holds station.
  static let airshipBob = 7.0
  /// The line the airship guns mirror the cursor about. Roughly the middle of
  /// the playfield, so low on the ground maps to high in the sky.
  static let aimMirrorY = 318.0

  // MARK: - Tuning

  /// Frames between rounds while the trigger is held. Four at 60Hz is fifteen
  /// a second, which is what "high speed" has to mean to feel like one.
  static let fireInterval = 4
  static let shotSpeed = 22.0
  static let shotDamage = 1

  static let maxHealth = 100.0
  /// Frames between bites once a raider is on the wall.
  static let biteInterval = 34

  // MARK: - Kinds of raider

  enum Raider: CaseIterable {
    case walker
    case runner
    case heavy
    case bomber
    /// Drops in under a parachute, anywhere across the field — including
    /// right on top of the tower, well past everything on the ground.
    case paratrooper
    /// Stops out of reach and shells the tower from there. Standing outside
    /// the force field, it keeps firing while the dome is up.
    case shooter
    /// Arrives alone at the end of a boss wave. Enormous, slow, and has to be
    /// put down before the next wave will start.
    case boss

    var health: Int {
      switch self {
      case .walker: return 1
      case .runner: return 1
      case .heavy: return 6
      case .bomber: return 2
      case .paratrooper: return 2
      case .shooter: return 4
      // Overridden per spawn — a boss scales with how deep you are.
      case .boss: return 120
      }
    }

    var speed: Double {
      switch self {
      case .walker: return 0.62
      case .runner: return 1.5
      case .heavy: return 0.34
      case .bomber: return 0.85
      case .paratrooper: return 1.0
      case .shooter: return 0.46
      // Heavy, but not so slow that it spends ten seconds off-screen before
      // you can even shoot at it. Enrage takes it higher as it loses health.
      case .boss: return 0.50
      }
    }

    var scale: Double {
      switch self {
      case .walker: return 1.0
      case .runner: return 0.85
      case .heavy: return 1.75
      case .bomber: return 1.05
      case .paratrooper: return 1.0
      case .shooter: return 1.15
      case .boss: return 4.4
      }
    }

    var score: Int {
      switch self {
      case .walker: return 10
      case .runner: return 15
      case .heavy: return 50
      case .bomber: return 25
      case .paratrooper: return 30
      case .shooter: return 55
      case .boss: return 750
      }
    }

    /// How much wall repair killing this is worth. Banked, then paid out
    /// slowly — see `repairWall`.
    var repairValue: Double {
      switch self {
      case .walker: return 0.5
      case .runner: return 0.4
      case .bomber: return 0.7
      case .paratrooper: return 0.6
      case .shooter: return 1.0
      case .heavy: return 1.8
      case .boss: return 14
      }
    }

    /// Damage dealt per bite, or all at once for a bomber.
    var bite: Double {
      switch self {
      case .walker: return 3
      case .runner: return 2
      case .heavy: return 9
      case .bomber: return 22
      case .paratrooper: return 4
      // Shooters never reach the wall; they do their damage at range.
      case .shooter: return 0
      case .boss: return 34
      }
    }
  }

  /// Nukes held at once. The rack starts full and refills over time.
  static let nukesPerStage = 3
  /// Frames to earn one charge back — about thirty-five seconds, so roughly
  /// one a wave rather than one on demand.
  static let nukeRechargeFrames = 2100
  /// How long the detonation is drawn for.
  static let nukeFlashFrames = 28

  /// How far the dome stands off the tower, in pixels along the ground.
  static let fieldRadius = 205.0
  /// How long one stays up.
  static let fieldDuration = 420
  /// Domes held at once, and how long one takes to come back.
  static let fieldsPerStage = 2
  static let fieldRechargeFrames = 1500

  /// Wall repaid per frame, at most. Deliberately slow: at 0.012 a frame the
  /// wall comes back at well under one percent a second, so it reads as the
  /// masonry being shored up between waves rather than as regeneration.
  static let repairRate = 0.012
  /// The most repair that can be banked at once, so a quiet spell at full
  /// health cannot stockpile a whole wall.
  static let repairReserveCap = 30.0

  /// How long a body lies there before it is cleared, and how long it spends
  /// flickering out at the end.
  static let corpseLifetime = 2_700
  static let corpseFadeFrames = 240
  /// A hard ceiling, so a long run cannot fill the field with bodies.
  static let maxCorpses = 150
  /// Ground is bucketed this wide for stacking, and each body in a bucket
  /// raises the heap by this much.
  static let pileBucket = 26.0
  static let pileStep = 5.0
  static let pileCap = 10
  static let stainLifetime = 4_200
  static let maxStains = 220

  /// Frames between guided bombs. They come on their own, with no input.
  static let smartBombInterval = 460
  static let smartBombSpeed = 3.9
  /// Radians it can turn per frame. Deliberately short of instant, so the
  /// bomb trails the aim instead of pinning to it.
  static let smartBombTurn = 0.052
  static let smartBombRadius = 66.0
  /// How close to the aim point counts as arrived.
  static let smartBombArmDistance = 26.0

  /// How much wall one crate is worth.
  static let kitHeal = 18.0
  /// Roughly how often one is dropped, in frames. Halved while the wall is in
  /// a bad way, so they turn up when they are actually needed.
  static let kitDropInterval = 1600
  static let kitDescentSpeed = 0.95
  /// How long it sits on the ground before it is lost.
  static let kitLingerFrames = 420
  static let kitSize = 26

  /// How fast a parachute descends, in pixels per frame.
  static let descentSpeed = 1.15
  /// How far out a shooter plants itself. Well beyond the force field, so the
  /// dome stops its shells without stopping the shooter.
  static let shooterStandoff = 312.0
  static let shooterInterval = 105
  static let shellSpeed = 5.4
  static let shellDamage = 5.0

  /// A boss turns up at the end of every third wave.
  static let bossEveryWaves = 3
  /// Base health, before the per-wave scaling.
  static let bossBaseHealth = 90
  static let bossHealthPerWave = 12

  final class Attacker {
    var x: Double
    var y: Double
    let kind: Raider
    var health: Int
    /// +1 walking right, -1 walking left.
    var facing: Int
    var step = 0
    /// Counts down while it dies; 0 means still coming.
    var dying = 0
    var biteTimer = 0
    var atWall = false
    /// True while still under the parachute.
    var descending = false
    /// Frames until this shooter fires again.
    var shootTimer = Int.random(in: 30...Siege.shooterInterval)
    /// Where this shooter plants itself, jittered so they do not form a line.
    var standoff = Siege.shooterStandoff + Double.random(in: -34...34)

    static let deathFrames = 16

    /// Full health as spawned, so a boss bar can show a fraction.
    let maxHealth: Int
    /// Counts down after taking a hit, for the white flash.
    var hitFlash = 0
    /// Damage thresholds already passed, so minions are shed once each.
    var sheddingStage = 0

    init(x: Double, y: Double, kind: Raider, facing: Int, health: Int? = nil) {
      self.x = x
      self.y = y
      self.kind = kind
      self.health = health ?? kind.health
      self.maxHealth = health ?? kind.health
      self.facing = facing
    }

    var isBoss: Bool { kind == .boss }

    /// A wounded boss speeds up. Nothing else changes pace.
    var currentSpeed: Double {
      guard isBoss else { return kind.speed }
      let lost = 1.0 - Double(health) / Double(max(maxHealth, 1))
      return kind.speed * (1.0 + lost * 1.6)
    }

    var width: Double { 36 * kind.scale }
    var height: Double { 41 * kind.scale }
  }

  struct Shot {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life: Int
    /// Which barrel put it out. Recorded rather than inferred from position,
    /// so telling the guns apart does not depend on sampling the right frame.
    var gun: Int
  }

  /// A body left where it fell. Bodies stack into heaps and stay a long time
  /// before they are cleared.
  final class Corpse {
    var x: Double
    var y: Double
    let scale: Double
    let facingRight: Bool
    /// Which bucket of the ground this is piled in, so the heap shrinks again
    /// when it is cleared away.
    let bucket: Int
    var life: Int

    init(x: Double, y: Double, scale: Double, facingRight: Bool, bucket: Int, life: Int) {
      self.x = x
      self.y = y
      self.scale = scale
      self.facingRight = facingRight
      self.bucket = bucket
      self.life = life
    }
  }

  /// A mark on the ground. Outlasts the body that made it.
  struct Stain {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    var color: UInt32
    var life: Int
  }

  /// A crate of supplies on a parachute. Shoot it to patch the wall; let it
  /// sit too long and it is gone.
  final class HealthKit {
    var x: Double
    var y: Double
    var landed = false
    /// Frames left once it is on the ground.
    var linger = Siege.kitLingerFrames
    var age = 0

    init(x: Double, y: Double) {
      self.x = x
      self.y = y
    }
  }

  /// The flash a guided bomb leaves where it lands.
  struct Blast {
    var x: Double
    var y: Double
    var life: Int

    static let duration = 14
  }

  /// A guided bomb the airships drop every so often. It steers toward
  /// wherever the guns are pointed, but only turns so fast — swing the aim
  /// hard across the field and it arcs after you rather than snapping round.
  final class SmartBomb {
    var x: Double
    var y: Double
    /// Current heading, in radians.
    var heading: Double
    var fuse: Int
    var age = 0

    init(x: Double, y: Double, heading: Double, fuse: Int) {
      self.x = x
      self.y = y
      self.heading = heading
      self.fuse = fuse
    }
  }

  /// A shell lobbed at the tower by a shooter.
  struct Shell {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life: Int
  }

  struct Fleck {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life: Int
    var color: UInt32
    var size: Int
  }

  /// What the screen is showing.
  enum Phase {
    /// Choosing which wave to start on.
    case selecting
    case fighting
    case over
  }

  /// The hardest wave that can be selected. Past this the spawn interval has
  /// bottomed out anyway, so later waves stop differing.
  static let maxStartWave = 40

  // MARK: - State

  private let chooser: LevelChooser
  private var backdropIndex: Int
  private var backdrop: Bitmap

  private var attackers: [Attacker] = []
  private var shots: [Shot] = []
  private var flecks: [Fleck] = []
  private var shells: [Shell] = []
  private var kits: [HealthKit] = []
  private var smartBombs: [SmartBomb] = []
  private var blasts: [Blast] = []
  private var smartBombTimer = Siege.smartBombInterval
  /// Which airship drops the next one.
  private var smartBombShip = 0
  private var corpses: [Corpse] = []
  private var stains: [Stain] = []
  /// Bodies currently heaped in each stretch of ground.
  private var pile: [Int: Int] = [:]
  private var kitTimer = Siege.kitDropInterval / 2

  /// One barrel. Each tracks the aim point independently, so the pair
  /// converges on wherever the cursor is rather than firing parallel.
  final class Gun {
    /// Live position. For an airship gun these follow its ship as it drifts.
    var x: Int
    var y: Int
    /// For an airship gun, where it sits relative to its ship.
    let offsetX: Int
    let offsetY: Int
    /// Which airship carries it, or nil for a tower mount.
    let airshipIndex: Int?
    /// Whether it reflects the aim about the horizon.
    let mirrored: Bool

    var airship: Bool { airshipIndex != nil }
    var angle = -0.6
    var recoil = 0.0
    var muzzle = 0

    init(x: Int, y: Int, offsetX: Int, offsetY: Int, airshipIndex: Int?, mirrored: Bool) {
      self.x = x
      self.y = y
      self.offsetX = offsetX
      self.offsetY = offsetY
      self.airshipIndex = airshipIndex
      self.mirrored = mirrored
    }
  }

  private var guns: [Gun] = Siege.gunMounts.map { mount in
    if let ship = mount.airship {
      return Gun(
        x: Siege.airships[ship].x + mount.x, y: Siege.airships[ship].y + mount.y,
        offsetX: mount.x, offsetY: mount.y, airshipIndex: ship, mirrored: mount.mirrored)
    }
    return Gun(
      x: mount.x, y: mount.y, offsetX: 0, offsetY: 0, airshipIndex: nil,
      mirrored: mount.mirrored)
  }

  /// How far each airship is currently displaced by its drift.
  private var airshipLift = [Int](repeating: 0, count: Siege.airships.count)
  /// Which barrel fires next. They alternate, so the combined stream is twice
  /// as dense as one gun's rate rather than two shots arriving together.
  private var nextGun = 0

  /// Aim is kept as a point, not an angle, because two guns at different
  /// positions need different angles to hit the same thing.
  private var aimAngle = -0.6
  private var aimDistance = 320.0
  /// Fractional, so the combined rate is exactly `fireInterval / guns.count`
  /// however many barrels are bolted on. Integer division threw this out: with
  /// three guns `4 / 3` rounds to 1, which would have fired 60 a second rather
  /// than 45.
  private var fireAccumulator = 0.0
  private var triggerHeld = false
  /// True while the right button is held: the mirror comes off and every gun
  /// converges on the cursor.
  private(set) var concentrating = false

  private(set) var health = Siege.maxHealth
  private(set) var score = 0
  private(set) var kills = 0
  private(set) var wave = 0
  private var toSpawn = 0
  private var spawnTimer = 0
  /// Set when the current wave still owes you a boss.
  private var bossPending = false
  /// Frames left on the arrival banner.
  private var bossWarning = 0
  private var wavePause = 90
  private var shake = 0.0
  private var frames = 0
  private(set) var gameOver = false
  private(set) var wantsOut = false
  private(set) var phase: Phase = .selecting
  private(set) var nukesLeft = Siege.nukesPerStage
  private var nukeFlash = 0
  /// Progress toward the next charge, in frames.
  private var nukeRecharge = 0

  /// Repair earned by kills and not yet paid into the wall.
  private(set) var repairReserve = 0.0

  private(set) var fieldsLeft = Siege.fieldsPerStage
  /// Frames the dome has left to run, zero when it is down.
  private(set) var fieldTimer = 0
  private var fieldRecharge = 0
  /// The wave the next run begins on. Restarting comes back to this, not to 1.
  private(set) var startWave = 1

  private var held: Set<GameKey> = []
  private var rng = SystemRandomNumberGenerator()

  // MARK: - Setup

  init(chooser: LevelChooser, backdropIndex: Int, startWave: Int = 1) {
    self.chooser = chooser
    self.backdropIndex = backdropIndex
    self.backdrop = Siege.makeBackdrop(chooser.levelData(backdropIndex).file)
    self.startWave = min(max(startWave, 1), Siege.maxStartWave)
  }

  /// Changes the wave the run will begin on.
  func setStartWave(_ value: Int) {
    startWave = min(max(value, 1), Siege.maxStartWave)
  }

  /// Leaves the setup screen and starts the fight on the chosen wave.
  func begin() {
    restart()
    phase = .fighting
  }

  /// How many raiders the chosen wave sends, and what is in it. The mix is
  /// read off `pickKind`, so this cannot drift away from what actually spawns.
  var waveBriefing: (count: Int, kinds: String) {
    var kinds = ["walkers"]
    if startWave >= 2 { kinds.append("runners") }
    if startWave >= 3 { kinds.append("bombers") }
    if startWave >= 3 { kinds.append("paratroopers") }
    if startWave >= 3 { kinds.append("shooters") }
    if startWave >= 6 { kinds.append("heavies") }
    return (7 + startWave * 5, kinds.joined(separator: ", "))
  }

  /// Darkens a level painting once, up front. `Graphics` has no alpha, so a
  /// translucent wash over the top is not an option — the copy is.
  private static func makeBackdrop(_ file: String) -> Bitmap {
    let source = Assets.bitmap("\(file).png")
    let copy = Bitmap(width: source.width, height: source.height)
    for y in 0..<source.height {
      for x in 0..<source.width {
        let c = source.getRGB(x, y)
        let r = ((c >> 16) & 0xFF) * 42 / 100
        let g = ((c >> 8) & 0xFF) * 42 / 100
        let b = (c & 0xFF) * 52 / 100
        copy.setRGB(x, y, 0xFF00_0000 | (r << 16) | (g << 8) | b)
      }
    }
    return copy
  }

  func cycleBackdrop() {
    backdropIndex = (backdropIndex + 1) % chooser.levelCount
    backdrop = Siege.makeBackdrop(chooser.levelData(backdropIndex).file)
  }

  func restart() {
    attackers.removeAll()
    shots.removeAll()
    flecks.removeAll()
    shells.removeAll()
    kits.removeAll()
    kitTimer = Siege.kitDropInterval / 2
    smartBombs.removeAll()
    blasts.removeAll()
    smartBombTimer = Siege.smartBombInterval
    corpses.removeAll()
    stains.removeAll()
    pile.removeAll()
    health = Siege.maxHealth
    score = 0
    kills = 0
    nukesLeft = Siege.nukesPerStage
    nukeFlash = 0
    nukeRecharge = 0
    fieldsLeft = Siege.fieldsPerStage
    fieldTimer = 0
    fieldRecharge = 0
    repairReserve = 0
    // One short, so the first wave to arrive is the one that was selected.
    wave = startWave - 1
    toSpawn = 0
    wavePause = 90
    gameOver = false
    frames = 0
  }

  // MARK: - Frame

  func tick() {
    // Nothing moves while the wave is being chosen.
    guard phase != .selecting else {
      Sound.shared.stopLoop(.shot)
      return
    }

    frames += 1
    for gun in guns {
      if gun.muzzle > 0 { gun.muzzle -= 1 }
      gun.recoil *= 0.82
    }
    if nukeFlash > 0 { nukeFlash -= 1 }
    // Drift the ships, then carry their guns along with them.
    for (index, ship) in Siege.airships.enumerated() {
      airshipLift[index] =
        Int(sin(Double(frames) * 0.028 + ship.bobPhase) * Siege.airshipBob)
    }
    for gun in guns {
      guard let ship = gun.airshipIndex else { continue }
      gun.x = Siege.airships[ship].x + gun.offsetX
      gun.y = Siege.airships[ship].y + gun.offsetY + airshipLift[ship]
    }
    layGuns()
    shake *= 0.88

    guard !gameOver else {
      Sound.shared.stopLoop(.shot)
      updateFlecks()
      // The dead keep rotting after the run ends. Without this they froze on
      // the game-over screen and stayed there for as long as it was up.
      updateRemains()
      return
    }

    rechargeNukes()
    repairWall()
    updateField()
    updateWaves()
    updateAiming()
    updateFiring()
    updateShots()
    updateAttackers()
    updateShells()
    updateKits()
    updateSmartBombs()
    updateRemains()
    updateFlecks()

    if health <= 0 {
      health = 0
      gameOver = true
      phase = .over
      shake = 18
    }
  }

  /// Earns a charge back over time, capped at a full rack.
  private func rechargeNukes() {
    guard nukesLeft < Siege.nukesPerStage else {
      nukeRecharge = 0
      return
    }
    nukeRecharge += 1
    if nukeRecharge >= Siege.nukeRechargeFrames {
      nukeRecharge = 0
      nukesLeft += 1
    }
  }

  /// How far along the next charge is, 0 to 1. Zero when the rack is full.
  var nukeRechargeFraction: Double {
    guard nukesLeft < Siege.nukesPerStage else { return 0 }
    return Double(nukeRecharge) / Double(Siege.nukeRechargeFrames)
  }

  /// Pays banked repair into the wall, a trickle at a time.
  ///
  /// Kill-driven rather than time-driven: standing still earns nothing. The
  /// payout is slow enough that it never outruns a wave, but over a long run
  /// it rewards clearing the field instead of only holding it.
  private func repairWall() {
    guard repairReserve > 0, health < Siege.maxHealth else { return }
    let amount = min(Siege.repairRate, repairReserve, Siege.maxHealth - health)
    health += amount
    repairReserve -= amount

    // A green mote drifting off the parapet now and then, and nothing louder.
    if frames % 26 == 0 {
      flecks.append(
        Fleck(
          x: Double(Siege.fortressLeft + Int.random(in: 6...110, using: &rng)),
          y: Double(Siege.fortressTop),
          vx: Double.random(in: -0.3...0.3, using: &rng),
          vy: -0.75,
          life: 46,
          color: 0xFF7ADC8A,
          size: 2))
    }
  }

  /// True while the wall is being shored up, for the HUD.
  var isRepairing: Bool { repairReserve > 0 && health < Siege.maxHealth }

  /// Raises the dome. Nothing gets past it while it holds — brutes included.
  @discardableResult
  func raiseField() -> Bool {
    guard phase == .fighting, !gameOver, fieldsLeft > 0, fieldTimer == 0 else { return false }
    fieldsLeft -= 1
    fieldTimer = Siege.fieldDuration
    shake = max(shake, 6)
    Sound.shared.play(.field, gain: 0.8)
    burst(
      atX: Double(Siege.towerCenterX), y: Double(Siege.roofY), count: 24,
      colors: [0xFF6ADCFF, 0xFFBFF2FF, 0xFFFFFFFF])
    return true
  }

  private func updateField() {
    if fieldTimer > 0 { fieldTimer -= 1 }
    guard fieldsLeft < Siege.fieldsPerStage else {
      fieldRecharge = 0
      return
    }
    fieldRecharge += 1
    if fieldRecharge >= Siege.fieldRechargeFrames {
      fieldRecharge = 0
      fieldsLeft += 1
    }
  }

  var fieldRechargeFraction: Double {
    guard fieldsLeft < Siege.fieldsPerStage else { return 0 }
    return Double(fieldRecharge) / Double(Siege.fieldRechargeFrames)
  }

  var fieldIsUp: Bool { fieldTimer > 0 }

  // MARK: - Waves

  private func updateWaves() {
    if bossWarning > 0 { bossWarning -= 1 }

    // The pack is spent and this wave owes a boss: send it in as the finale.
    // Because it is an ordinary attacker, the "everything is dying" test below
    // will not pass until it is dead — so the next wave waits for it.
    if toSpawn == 0 && bossPending {
      bossPending = false
      summonBoss()
      return
    }

    if toSpawn == 0 && attackers.allSatisfy({ $0.dying > 0 }) {
      wavePause -= 1
      if wavePause <= 0 {
        wave += 1
        // Fresh ground for a fresh wave.
        clearTheDead()
        toSpawn = 7 + wave * 5
        spawnTimer = 0
        wavePause = 150
        bossPending = wave % Siege.bossEveryWaves == 0
      }
      return
    }

    guard toSpawn > 0 else { return }
    spawnTimer -= 1
    guard spawnTimer <= 0 else { return }
    // They arrive faster as the night goes on, and in twos once it is really
    // going.
    spawnTimer = max(5, 32 - wave * 2)
    let burst = wave >= 8 ? 2 : 1

    for _ in 0..<burst where toSpawn > 0 {
      toSpawn -= 1
      send(pickKind())
    }
  }

  /// Puts one raider on the field. Most walk in from an edge; paratroopers
  /// come down out of the sky anywhere across it, which is the point of them.
  private func send(_ kind: Raider) {
    if kind == .paratrooper {
      let raider = Attacker(
        x: Double.random(in: 80...Double(Level.canvasWidth - 80), using: &rng),
        y: Double.random(in: -120 ... -40, using: &rng),
        kind: kind,
        facing: Bool.random(using: &rng) ? 1 : -1)
      raider.descending = true
      // Face the tower once it lands, or it will wander off the map.
      raider.facing = raider.x < Double(Siege.towerCenterX) ? 1 : -1
      attackers.append(raider)
      return
    }

    let fromLeft = Bool.random(using: &rng)
    attackers.append(
      Attacker(
        x: fromLeft ? -40 : Double(Level.canvasWidth) + 40,
        y: Double(Siege.groundY),
        kind: kind,
        facing: fromLeft ? 1 : -1))
  }

  /// Sends in the wave's boss, scaled to how deep the run is.
  private func summonBoss() {
    let fromLeft = Bool.random(using: &rng)
    let health = Siege.bossBaseHealth + wave * Siege.bossHealthPerWave
    // Just off the edge, measured from its own bulk, so it starts walking on
    // almost immediately rather than trudging through empty space first.
    let edge = 36 * Raider.boss.scale / 2 + 14
    attackers.append(
      Attacker(
        x: fromLeft ? -edge : Double(Level.canvasWidth) + edge,
        y: Double(Siege.groundY),
        kind: .boss,
        facing: fromLeft ? 1 : -1,
        health: health))
    bossWarning = 150
    shake = max(shake, 14)
    Sound.shared.play(.boss, gain: 1.0)
  }

  /// The boss currently on the field, if any.
  private var activeBoss: Attacker? {
    attackers.first { $0.isBoss && $0.dying == 0 }
  }

  /// The mix hardens with the wave: plain walkers early, heavies and bombers
  /// once you have had time to get comfortable.
  private func pickKind() -> Raider {
    // Bosses are summoned deliberately, never rolled.
    let roll = Int.random(in: 0..<100, using: &rng)
    // Shooters and paratroopers arrive from wave 3 rather than 5 and 4, and
    // in real numbers: gated later and thinner, they barely turned up before
    // the run was over.
    if wave >= 6 && roll < 12 { return .heavy }
    if wave >= 3 && roll < 30 { return .shooter }
    if wave >= 3 && roll < 48 { return .paratrooper }
    if wave >= 3 && roll < 60 { return .bomber }
    if wave >= 2 && roll < 78 { return .runner }
    return .walker
  }

  // MARK: - The cannon

  private func updateAiming() {
    // Keyboard aim, for when the mouse is not where you want it.
    if held.contains(.left) || held.contains(.char("a")) { aimAngle -= 0.035 }
    if held.contains(.right) || held.contains(.char("d")) { aimAngle += 0.035 }
    if held.contains(.up) || held.contains(.char("w")) { aimAngle -= 0.02 }
    if held.contains(.down) || held.contains(.char("s")) { aimAngle += 0.02 }
    layGuns()
  }

  /// Where both barrels are pointing.
  private var aimPoint: (x: Double, y: Double) {
    (
      Double(Siege.towerCenterX) + cos(aimAngle) * aimDistance,
      Double(Siege.roofY) + sin(aimAngle) * aimDistance
    )
  }

  /// Points each barrel at where it should be looking.
  ///
  /// The tower guns follow the cursor. The airship guns are mirrored about the
  /// horizon, so aiming low at the ground swings them high into the sky and
  /// the one cursor covers both at once. Holding the right button drops the
  /// mirror and brings all five onto the same point.
  private func layGuns() {
    let target = aimPoint
    for gun in guns {
      let aimY =
        (gun.mirrored && !concentrating)
        ? 2 * Siege.aimMirrorY - target.y
        : target.y
      gun.angle = atan2(aimY - Double(gun.y), target.x - Double(gun.x))
    }
  }


  /// Points the cannon at a canvas position.
  func aim(atX x: Int, y: Int) {
    let dx = Double(x - Siege.towerCenterX)
    let dy = Double(y - Siege.roofY)
    guard abs(dx) > 0.5 || abs(dy) > 0.5 else { return }
    aimAngle = atan2(dy, dx)
    // Converge exactly on the cursor rather than at some fixed range.
    aimDistance = max((dx * dx + dy * dy).squareRoot(), 90)
    layGuns()
  }

  /// Hit boxes on the setup screen, in canvas coordinates.
  static let minusBox = (x: 262, y: 262, w: 52, h: 52)
  static let plusBox = (x: 486, y: 262, w: 52, h: 52)
  static let beginBox = (x: 300, y: 372, w: 200, h: 48)

  /// A press. On the setup screen it works the buttons; in the fight it aims
  /// and holds the trigger.
  func mouseDown(atX x: Int, y: Int) {
    guard phase != .selecting else {
      func inside(_ box: (x: Int, y: Int, w: Int, h: Int)) -> Bool {
        x >= box.x && x <= box.x + box.w && y >= box.y && y <= box.y + box.h
      }
      if inside(Siege.minusBox) {
        setStartWave(startWave - 1)
      } else if inside(Siege.plusBox) {
        setStartWave(startWave + 1)
      } else if inside(Siege.beginBox) {
        begin()
      }
      return
    }
    aim(atX: x, y: y)
    triggerDown()
  }

  func mouseUp(atX x: Int, y: Int) {
    guard phase != .selecting else { return }
    triggerUp()
  }

  /// Right button holds every gun on the cursor instead of mirroring the
  /// airships. The nuke moved to Q when this took the button over.
  func rightMouseDown(atX x: Int, y: Int) {
    guard phase != .selecting else { return }
    concentrating = true
    aim(atX: x, y: y)
  }

  func rightMouseUp(atX x: Int, y: Int) {
    concentrating = false
    layGuns()
  }

  func triggerDown() {
    triggerHeld = true
  }

  func triggerUp() {
    triggerHeld = false
  }

  /// Wipes the field. Three per run, and they do not come back between waves,
  /// so the question is always whether this is the moment.
  ///
  /// Nothing survives it, bosses included — which makes spending one on a
  /// Brute a real trade against the swarm you will not be able to clear later.
  @discardableResult
  func fireNuke() -> Bool {
    guard phase == .fighting, !gameOver, nukesLeft > 0 else { return false }
    // Do not let one go on an empty field.
    guard attackers.contains(where: { $0.dying == 0 }) else { return false }

    nukesLeft -= 1
    // Everything on the field goes, including what was already lying on it.
    clearTheDead()
    nukeFlash = Siege.nukeFlashFrames
    shake = max(shake, 26)
    Sound.shared.play(.nuke, gain: 1.0)

    for attacker in attackers where attacker.dying == 0 {
      kill(attacker)
    }
    // A ring of debris off the tower itself.
    burst(
      atX: Double(Siege.towerCenterX), y: Double(Siege.roofY), count: 60,
      colors: [0xFFFFFFFF, 0xFFFFE07A, 0xFFFF8A2A])
    return true
  }

  private func updateFiring() {
    let wantsFire = triggerHeld || held.contains(.char(" "))

    // The gun sound runs for as long as the trigger is down, rather than being
    // retriggered per round. A chaingun is one continuous noise, and a sample
    // of one restarted forty-five times a second is a stutter.
    if wantsFire {
      Sound.shared.startLoop(.shot, gain: 0.5)
    } else {
      Sound.shared.stopLoop(.shot)
    }

    guard wantsFire else {
      // Hold a little credit so tapping does not feel sluggish, but not enough
      // to bank a burst.
      fireAccumulator = min(fireAccumulator, 1.0)
      return
    }

    // Each barrel still fires every `fireInterval` frames; they take turns, so
    // the stream leaving the tower is that much denser.
    let interval = Double(Siege.fireInterval) / Double(max(guns.count, 1))
    fireAccumulator += 1
    while fireAccumulator >= interval {
      fireAccumulator -= interval
      fireOneGun()
    }
  }

  private func fireOneGun() {
    let index = nextGun
    let gun = guns[index]
    nextGun = (nextGun + 1) % guns.count
    gun.muzzle = 3
    gun.recoil = 9
    shake = max(shake, 1.6)


    let dx = cos(gun.angle)
    let dy = sin(gun.angle)
    shots.append(
      Shot(
        x: Double(gun.x) + dx * Siege.barrelLength,
        y: Double(gun.y) + dy * Siege.barrelLength,
        vx: dx * Siege.shotSpeed,
        vy: dy * Siege.shotSpeed,
        life: 70,
        gun: index))
  }

  private func updateShots() {
    var index = 0
    while index < shots.count {
      shots[index].x += shots[index].vx
      shots[index].y += shots[index].vy
      shots[index].life -= 1

      let shot = shots[index]
      var spent = shot.life <= 0 || shot.y > Double(Siege.groundY) + 6
        || shot.x < -30 || shot.x > Double(Level.canvasWidth) + 30

      // Crates are checked before raiders: a crate drifting past a crowd
      // should still be hittable, and it is the thing being aimed at.
      if !spent, let kit = kitHit(atX: shot.x, y: shot.y) {
        collect(kit)
        spent = true
      }

      if !spent, let hit = attackerHit(atX: shot.x, y: shot.y) {
        hit.health -= Siege.shotDamage
        hit.hitFlash = 3
        burst(atX: shot.x, y: shot.y, count: 5, colors: [0xFFF2D23A, 0xFFFFFFFF])
        if hit.isBoss { shedMinions(from: hit) }
        if hit.health <= 0 && hit.dying == 0 {
          kill(hit)
        }
        spent = true
      }

      if spent {
        if shot.y > Double(Siege.groundY) {
          burst(atX: shot.x, y: Double(Siege.groundY), count: 3, colors: [0xFF8A7A6A])
        }
        shots.remove(at: index)
        continue
      }
      index += 1
    }
  }

  /// The crate a point falls inside, if any.
  private func kitHit(atX x: Double, y: Double) -> HealthKit? {
    let half = Double(Siege.kitSize) / 2 + 4
    return kits.first {
      x > $0.x - half && x < $0.x + half && y > $0.y - half && y < $0.y + half
    }
  }

  /// The first living raider whose body contains a point.
  private func attackerHit(atX x: Double, y: Double) -> Attacker? {
    for attacker in attackers where attacker.dying == 0 {
      let w = attacker.width
      let h = attacker.height
      if x > attacker.x - w / 2, x < attacker.x + w / 2,
        y > attacker.y - h, y < attacker.y
      {
        return attacker
      }
    }
    return nil
  }

  /// A boss throws off a pair of walkers each time it loses a quarter of its
  /// health, so chewing through one is not just a question of holding the
  /// trigger down.
  private func shedMinions(from boss: Attacker) {
    let lost = 1.0 - Double(boss.health) / Double(max(boss.maxHealth, 1))
    let stage = Int(lost * 4)
    guard stage > boss.sheddingStage else { return }
    boss.sheddingStage = stage

    for side in [-1.0, 1.0] {
      attackers.append(
        Attacker(
          x: boss.x + side * boss.width * 0.4,
          y: Double(Siege.groundY),
          kind: .walker,
          facing: boss.facing))
    }
    burst(
      atX: boss.x, y: boss.y - boss.height / 2, count: 12,
      colors: [0xFFF2D23A, 0xFF8A1A1A])
  }

  private func kill(_ attacker: Attacker) {
    attacker.dying = Attacker.deathFrames
    kills += 1
    score += attacker.kind.score
    // Every kill buys a little masonry, capped so it cannot be hoarded.
    repairReserve = min(repairReserve + attacker.kind.repairValue, Siege.repairReserveCap)

    // Heavies get their own cry; brutes deliberately keep the ordinary one.
    if attacker.kind == .heavy {
      Sound.shared.play(.deathHeavy, gain: 0.85)
    } else {
      Sound.shared.play(.death, gain: attacker.isBoss ? 1.0 : 0.7)
    }
    let pieces: Int
    switch attacker.kind {
    case .boss: pieces = 90
    case .heavy: pieces = 26
    default: pieces = 14
    }
    burst(
      atX: attacker.x, y: attacker.y - attacker.height / 2, count: pieces,
      colors: [0xFF8A1A1A, 0xFFC02A2A, 0xFF6A1414, 0xFFF2D23A, 0xFFFFFFFF, 0xFF3A6AD8])

    if attacker.isBoss {
      // Goes down loudly.
      shake = max(shake, 22)
      burst(
        atX: attacker.x, y: attacker.y - attacker.height * 0.7, count: 50,
        colors: [0xFFFF8A2A, 0xFFFFE07A, 0xFFFFFFFF])
    }
  }

  // MARK: - The horde

  private func updateAttackers() {
    var index = 0
    while index < attackers.count {
      let attacker = attackers[index]
      attacker.step += 1
      if attacker.hitFlash > 0 { attacker.hitFlash -= 1 }

      if attacker.dying > 0 {
        attacker.dying -= 1
        if attacker.dying == 0 {
          layOut(attacker)
          attackers.remove(at: index)
          continue
        }
        index += 1
        continue
      }

      // Under the parachute: drift straight down until the ground, and do
      // nothing else on the way. Landing is what puts it in the fight.
      if attacker.descending {
        attacker.y += Siege.descentSpeed
        if attacker.y >= Double(Siege.groundY) {
          attacker.y = Double(Siege.groundY)
          attacker.descending = false
          burst(atX: attacker.x, y: attacker.y - 10, count: 5, colors: [0xFF8A8A9A])
        }
        index += 1
        continue
      }

      // Shooters plant themselves out of reach and shell the tower. They stop
      // short of the force field, so raising the dome stops their shells but
      // not them.
      if attacker.kind == .shooter {
        let offset = attacker.x - Double(Siege.towerCenterX)
        if abs(offset) <= attacker.standoff {
          attacker.atWall = true
          attacker.shootTimer -= 1
          if attacker.shootTimer <= 0 {
            attacker.shootTimer = Siege.shooterInterval
            lobShell(from: attacker)
          }
          index += 1
          continue
        }
        attacker.x += Double(attacker.facing) * attacker.currentSpeed
        index += 1
        continue
      }

      // The dome: anything inside it is shoved back out to the perimeter and
      // pinned there, so it never reaches the wall to bite. Shoved rather than
      // teleported, because snapping them looks like a rendering glitch.
      if fieldTimer > 0 {
        let offset = attacker.x - Double(Siege.towerCenterX)
        if abs(offset) < Siege.fieldRadius {
          let side: Double = offset < 0 ? -1 : 1
          let perimeter = Double(Siege.towerCenterX) + side * Siege.fieldRadius
          attacker.x += side * min(4.0, abs(perimeter - attacker.x))
          attacker.atWall = false
          index += 1
          continue
        }
      }

      let wallEdge =
        attacker.facing > 0
        ? Double(Siege.fortressLeft) - attacker.width / 2
        : Double(Siege.fortressRight) + attacker.width / 2

      let reached =
        attacker.facing > 0 ? attacker.x >= wallEdge : attacker.x <= wallEdge

      if reached {
        attacker.atWall = true
        attacker.x = wallEdge
        if attacker.kind == .bomber {
          // Goes off on arrival rather than settling in to chew.
          health -= attacker.kind.bite
          shake = max(shake, 11)
          burst(
            atX: attacker.x, y: attacker.y - 20, count: 30,
            colors: [0xFFFF8A2A, 0xFFFFE07A, 0xFFFFFFFF])
          attacker.dying = Attacker.deathFrames
        } else {
          attacker.biteTimer -= 1
          if attacker.biteTimer <= 0 {
            attacker.biteTimer = Siege.biteInterval
            health -= attacker.kind.bite
            shake = max(shake, 4)
            Sound.shared.play(.bite, gain: 0.5)
            burst(
              atX: attacker.x, y: attacker.y - 24, count: 6, colors: [0xFF9A9AA8, 0xFF6A6A7A])
          }
        }
      } else {
        attacker.x += Double(attacker.facing) * attacker.currentSpeed
      }
      index += 1
    }
  }

  /// Lobs a shell at the top of the tower.
  private func lobShell(from shooter: Attacker) {
    let originX = shooter.x
    let originY = shooter.y - shooter.height * 0.6
    let targetX = Double(Siege.towerCenterX)
    let targetY = Double(Siege.fortressTop + 40)
    let dx = targetX - originX
    let dy = targetY - originY
    let distance = max((dx * dx + dy * dy).squareRoot(), 1)

    shells.append(
      Shell(
        x: originX, y: originY,
        vx: dx / distance * Siege.shellSpeed,
        vy: dy / distance * Siege.shellSpeed,
        life: 260))
    burst(atX: originX, y: originY, count: 3, colors: [0xFFFFC24A, 0xFFFF8A2A])
  }

  private func updateShells() {
    var index = 0
    while index < shells.count {
      shells[index].x += shells[index].vx
      shells[index].y += shells[index].vy
      shells[index].life -= 1
      let shell = shells[index]

      var spent = shell.life <= 0 || shell.y > Double(Siege.groundY)
        || shell.x < -40 || shell.x > Double(Level.canvasWidth) + 40

      // The dome stops shells. That is what makes it an answer to shooters
      // even though they stand outside it.
      if !spent && fieldTimer > 0 {
        let dx = shell.x - Double(Siege.towerCenterX)
        let dy = shell.y - Double(Siege.groundY)
        if (dx * dx + dy * dy).squareRoot() <= Siege.fieldRadius {
          burst(
            atX: shell.x, y: shell.y, count: 8,
            colors: [0xFFBFF2FF, 0xFF6ADCFF, 0xFFFFFFFF])
          spent = true
        }
      }

      if !spent,
        shell.x > Double(Siege.fortressLeft - 6), shell.x < Double(Siege.fortressRight + 6),
        shell.y > Double(Siege.fortressTop - 44)
      {
        health -= Siege.shellDamage
        shake = max(shake, 7)
        Sound.shared.play(.bite, gain: 0.75)
        burst(
          atX: shell.x, y: shell.y, count: 12,
          colors: [0xFFFF8A2A, 0xFF9A9AA8, 0xFF6A6A7A])
        spent = true
      }

      if spent {
        shells.remove(at: index)
        continue
      }
      index += 1
    }
  }

  /// Releases a guided bomb on a timer, and flies the ones already out.
  private func updateSmartBombs() {
    for i in blasts.indices { blasts[i].life -= 1 }
    blasts.removeAll { $0.life <= 0 }

    smartBombTimer -= 1
    if smartBombTimer <= 0 {
      smartBombTimer = Siege.smartBombInterval
      let ship = Siege.airships[smartBombShip]
      smartBombShip = (smartBombShip + 1) % Siege.airships.count
      smartBombs.append(
        SmartBomb(
          x: Double(ship.x),
          y: Double(ship.y + airshipLift[smartBombShip] + 26),
          // Starts heading downfield, and turns onto the aim from there.
          heading: ship.x < Siege.towerCenterX ? 0.5 : .pi - 0.5,
          fuse: 420))
    }

    let target = aimPoint
    var index = 0
    while index < smartBombs.count {
      let bomb = smartBombs[index]
      bomb.age += 1
      bomb.fuse -= 1

      // Steer toward the aim, but only by so much each frame.
      let desired = atan2(target.y - bomb.y, target.x - bomb.x)
      var delta = desired - bomb.heading
      while delta > .pi { delta -= 2 * .pi }
      while delta < -.pi { delta += 2 * .pi }
      bomb.heading += min(max(delta, -Siege.smartBombTurn), Siege.smartBombTurn)

      bomb.x += cos(bomb.heading) * Siege.smartBombSpeed
      bomb.y += sin(bomb.heading) * Siege.smartBombSpeed

      let reach = (bomb.x - target.x) * (bomb.x - target.x)
        + (bomb.y - target.y) * (bomb.y - target.y)
      let arrived = reach <= Siege.smartBombArmDistance * Siege.smartBombArmDistance
      let grounded = bomb.y >= Double(Siege.groundY)
      let strayed = bomb.x < -60 || bomb.x > Double(Level.canvasWidth) + 60 || bomb.y < -80

      if arrived || grounded || strayed || bomb.fuse <= 0 {
        detonateSmartBomb(bomb)
        smartBombs.remove(at: index)
        continue
      }
      index += 1
    }
  }

  /// Sets one off: everything inside the blast goes, and the wall is not
  /// touched — this is our ordnance.
  private func detonateSmartBomb(_ bomb: SmartBomb) {
    let radius = Siege.smartBombRadius
    for attacker in attackers where attacker.dying == 0 {
      let dx = attacker.x - bomb.x
      let dy = attacker.y - attacker.height / 2 - bomb.y
      if dx * dx + dy * dy <= radius * radius {
        kill(attacker)
      }
    }
    // Shells caught in it go too.
    shells.removeAll {
      let dx = $0.x - bomb.x
      let dy = $0.y - bomb.y
      return dx * dx + dy * dy <= radius * radius
    }

    shake = max(shake, 9)
    Sound.shared.play(.nuke, gain: 0.55)
    blasts.append(Blast(x: bomb.x, y: bomb.y, life: Blast.duration))
    burst(
      atX: bomb.x, y: bomb.y, count: 34,
      colors: [0xFFFF8A2A, 0xFFFFE07A, 0xFFFFFFFF, 0xFF8A1A1A])
  }

  /// Drops crates now and then, and ages the ones already out.
  private func updateKits() {
    kitTimer -= 1
    // More generous when the wall is in trouble.
    let pressure = health < Siege.maxHealth * 0.5 ? 2 : 1
    if kitTimer <= 0 && kits.count < 2 {
      kitTimer = Siege.kitDropInterval / pressure
      kits.append(
        HealthKit(
          x: Double.random(in: 90...Double(Level.canvasWidth - 90), using: &rng),
          y: Double.random(in: -90 ... -40, using: &rng)))
    }

    var index = 0
    while index < kits.count {
      let kit = kits[index]
      kit.age += 1
      if kit.landed {
        kit.linger -= 1
        if kit.linger <= 0 {
          // Lost. A puff, and nothing gained.
          burst(atX: kit.x, y: kit.y, count: 8, colors: [0xFF6A6A7A, 0xFF4A4A58])
          kits.remove(at: index)
          continue
        }
      } else {
        kit.y += Siege.kitDescentSpeed
        if kit.y >= Double(Siege.groundY) - Double(Siege.kitSize) / 2 {
          kit.y = Double(Siege.groundY) - Double(Siege.kitSize) / 2
          kit.landed = true
        }
      }
      index += 1
    }
  }

  /// Opens a crate: patches the wall and removes it.
  private func collect(_ kit: HealthKit) {
    health = min(health + Siege.kitHeal, Siege.maxHealth)
    Sound.shared.play(.pickup, gain: 0.9)
    burst(
      atX: kit.x, y: kit.y, count: 26,
      colors: [0xFF7ADC8A, 0xFFBFF2CF, 0xFFFFFFFF])
    kits.removeAll { $0 === kit }
  }

  /// Leaves a body on the ground where a raider finished dying, stacked onto
  /// whatever is already heaped there.
  private func layOut(_ attacker: Attacker) {
    // Bodies in the air — a paratrooper shot under its chute — come down to
    // the ground rather than lying in mid-air.
    let restingX = attacker.x
    let bucket = Int(restingX / Siege.pileBucket)
    let stacked = min(pile[bucket, default: 0], Siege.pileCap)
    pile[bucket, default: 0] += 1

    corpses.append(
      Corpse(
        x: restingX,
        y: Double(Siege.groundY) - Double(stacked) * Siege.pileStep,
        scale: attacker.kind.scale,
        facingRight: attacker.facing > 0,
        bucket: bucket,
        life: Siege.corpseLifetime + Int.random(in: 0...420, using: &rng)))

    // The mess it leaves, which outlasts the body.
    let spread = attacker.width * 0.9
    for _ in 0..<Int.random(in: 3...6, using: &rng) {
      stains.append(
        Stain(
          x: restingX + Double.random(in: -spread...spread, using: &rng),
          y: Double(Siege.groundY) + Double.random(in: 0...7, using: &rng),
          w: Double.random(in: 5...16, using: &rng) * attacker.kind.scale,
          h: Double.random(in: 2...5, using: &rng),
          color: [0xFF6A1414, 0xFF8A1A1A, 0xFF4A0E0E].randomElement(using: &rng)!,
          life: Siege.stainLifetime))
    }

    if corpses.count > Siege.maxCorpses {
      let oldest = corpses.removeFirst()
      pile[oldest.bucket] = max((pile[oldest.bucket] ?? 1) - 1, 0)
    }
    if stains.count > Siege.maxStains {
      stains.removeFirst(stains.count - Siege.maxStains)
    }
  }

  /// Clears the field of bodies. The stains stay — they fade on their own, and
  /// they are the record of what happened here.
  private func clearTheDead() {
    guard !corpses.isEmpty else { return }
    // A little dust off the heaps as they go, sampled rather than one puff per
    // body — there can be a hundred and fifty of them.
    for corpse in corpses.enumerated().filter({ $0.offset % 9 == 0 }).map(\.element) {
      burst(atX: corpse.x, y: corpse.y - 6, count: 3, colors: [0xFF6A5A4A, 0xFF4A4038])
    }
    corpses.removeAll()
    pile.removeAll()
  }

  private func updateRemains() {
    var index = 0
    while index < corpses.count {
      corpses[index].life -= 1
      if corpses[index].life <= 0 {
        let gone = corpses.remove(at: index)
        pile[gone.bucket] = max((pile[gone.bucket] ?? 1) - 1, 0)
        continue
      }
      index += 1
    }
    for i in stains.indices { stains[i].life -= 1 }
    stains.removeAll { $0.life <= 0 }
  }

  // MARK: - Debris

  private func burst(atX x: Double, y: Double, count: Int, colors: [UInt32]) {
    for _ in 0..<count {
      let angle = Double.random(in: 0..<(.pi * 2), using: &rng)
      let speed = Double.random(in: 1.2...5.5, using: &rng)
      flecks.append(
        Fleck(
          x: x, y: y,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 1.6,
          life: Int.random(in: 16...38, using: &rng),
          color: colors.randomElement(using: &rng) ?? 0xFFFFFFFF,
          size: Int.random(in: 2...5, using: &rng)))
    }
  }

  private func updateFlecks() {
    var index = 0
    while index < flecks.count {
      flecks[index].vy += 0.34
      flecks[index].x += flecks[index].vx
      flecks[index].y += flecks[index].vy
      flecks[index].life -= 1
      if flecks[index].life <= 0 || flecks[index].y > Double(Siege.groundY) + 4 {
        flecks.remove(at: index)
        continue
      }
      index += 1
    }
  }

  // MARK: - Input

  func keyDown(_ key: GameKey) {
    let normalized = Siege.normalize(key)
    held.insert(normalized)

    if phase == .selecting {
      switch normalized {
      case .left, .char("-"):
        setStartWave(startWave - 1)
      case .right, .char("="), .char("+"):
        setStartWave(startWave + 1)
      case .down:
        setStartWave(startWave - 5)
      case .up:
        setStartWave(startWave + 5)
      case .enter, .char(" "):
        begin()
      case .char("n"):
        cycleBackdrop()
      case .escape:
        wantsOut = true
      default:
        break
      }
      return
    }

    switch normalized {
    case .char("q"):
      fireNuke()
    case .char("e"), .char("f"):
      raiseField()
    case .char("m"):
      Sound.shared.muted.toggle()
    case .char("r") where gameOver:
      restart()
      phase = .fighting
    case .char("n"):
      cycleBackdrop()
    case .enter where gameOver:
      // Back to the setup screen to pick a different wave.
      phase = .selecting
      gameOver = false
    case .escape:
      Sound.shared.stopLoop(.shot)
      wantsOut = true
    default:
      break
    }
  }

  func keyUp(_ key: GameKey) {
    held.remove(Siege.normalize(key))
  }

  static func normalize(_ key: GameKey) -> GameKey {
    if case .char(let c) = key { return .char(Character(c.lowercased())) }
    return key
  }

  // MARK: - Inspection, for the headless test

  var debugState:
    (health: Double, score: Int, kills: Int, wave: Int, attackers: Int, shots: Int,
     flecks: Int, over: Bool)
  {
    (health, score, kills, wave, attackers.filter { $0.dying == 0 }.count, shots.count,
      flecks.count, gameOver)
  }

  func debugHold(_ key: GameKey) { held.insert(Siege.normalize(key)) }
  var debugPhase: String { "\(phase)" }
  var debugGunCount: Int { guns.count }
  var debugAirshipGuns: Int { guns.filter(\.airship).count }
  var debugMirroredAngles: [Double] {
    guns.filter(\.mirrored).map { $0.angle * 180 / .pi }
  }
  var debugStraightAngles: [Double] {
    guns.filter { !$0.mirrored }.map { $0.angle * 180 / .pi }
  }
  /// Each gun's live muzzle height, for checking the airships actually drift.
  var debugGunHeights: [Int] { guns.map(\.y) }
  /// Each gun's aim, in degrees, for checking the airships break off.
  var debugGunAngles: [Double] { guns.map { $0.angle * 180 / .pi } }
  var debugConcentrating: Bool { concentrating }
  /// The boss on the field: its health, its maximum, and how big it is.
  var debugBoss: (health: Int, maxHealth: Int, width: Double)? {
    activeBoss.map { ($0.health, $0.maxHealth, $0.width) }
  }
  var debugBossPending: Bool { bossPending }
  var debugNukesLeft: Int { nukesLeft }
  var debugNukeRecharge: Double { nukeRechargeFraction }
  var debugFieldsLeft: Int { fieldsLeft }
  var debugShells: Int { shells.count }
  var debugSmartBombs: Int { smartBombs.count }
  /// Where the guided bombs currently are, for checking they steer.
  var debugSmartBombPositions: [(x: Double, y: Double)] {
    smartBombs.map { ($0.x, $0.y) }
  }
  var debugAimPoint: (x: Double, y: Double) { aimPoint }
  var debugRepairReserve: Double { repairReserve }
  var debugKitCount: Int { kits.count }
  var debugCorpses: Int { corpses.count }
  var debugStains: Int { stains.count }
  /// The tallest heap, in bodies.
  var debugTallestPile: Int { pile.values.max() ?? 0 }
  var debugKitLanded: Bool { kits.contains { $0.landed } }
  /// True once a crate has dropped below the HUD and is actually on screen.
  var debugKitOnScreen: Bool { kits.contains { $0.y > 150 } }
  /// Puts a crate exactly where a test can shoot it.
  func debugDropKit(atX x: Double, y: Double) {
    kits.append(HealthKit(x: x, y: y))
  }
  /// Fires one round straight at a point, bypassing aiming.
  func debugSnipe(atX x: Double, y: Double) {
    let originX = Double(Siege.towerCenterX)
    let originY = Double(Siege.roofY)
    let dx = x - originX
    let dy = y - originY
    let distance = max((dx * dx + dy * dy).squareRoot(), 1)
    shots.append(
      Shot(
        x: originX, y: originY,
        vx: dx / distance * Siege.shotSpeed,
        vy: dy / distance * Siege.shotSpeed,
        life: 70, gun: 0))
  }
  var debugRepairing: Bool { isRepairing }
  func debugDamageWall(by amount: Double) { health = max(health - amount, 1) }
  /// Everything on the field, counted by kind. Answers "where are the X?"
  /// without having to stare at the screen.
  var debugCensus: [Raider: Int] {
    var census: [Raider: Int] = [:]
    for attacker in attackers where attacker.dying == 0 {
      census[attacker.kind, default: 0] += 1
    }
    return census
  }
  /// What `pickKind` would produce over many rolls at the current wave.
  func debugMixSample(_ samples: Int) -> [Raider: Int] {
    var census: [Raider: Int] = [:]
    for _ in 0..<samples { census[pickKind(), default: 0] += 1 }
    return census
  }
  /// Height above the ground of the highest raider still under a chute.
  var debugHighestDescending: Double? {
    attackers.filter { $0.descending && $0.dying == 0 }
      .map { Double(Siege.groundY) - $0.y }.max()
  }
  var debugDescendingCount: Int { attackers.filter { $0.descending }.count }
  /// How far out the nearest planted shooter is standing.
  var debugShooterStandoff: Double? {
    attackers.filter { $0.kind == .shooter && $0.dying == 0 && $0.atWall }
      .map { abs($0.x - Double(Siege.towerCenterX)) }.min()
  }
  func debugSpawnShell(fromX x: Double) {
    let shooter = Attacker(
      x: x, y: Double(Siege.groundY), kind: .shooter,
      facing: x < Double(Siege.towerCenterX) ? 1 : -1)
    lobShell(from: shooter)
  }
  /// Drops the dome and refills the rack, so a capture pass can leave the run
  /// exactly as it found it.
  func debugClearField() {
    fieldTimer = 0
    fieldsLeft = Siege.fieldsPerStage
    fieldRecharge = 0
  }
  var debugFieldUp: Bool { fieldIsUp }
  var debugFieldRecharge: Double { fieldRechargeFraction }
  /// How close the nearest living raider has got to the tower.
  var debugClosestApproach: Double? {
    attackers.filter { $0.dying == 0 }
      .map { abs($0.x - Double(Siege.towerCenterX)) }
      .min()
  }
  /// Tops the wall back up, so a test can exercise one mechanic without the
  /// fortress quietly falling over in the background and changing the answer.
  func debugRestoreWall() { health = Siege.maxHealth }
  var debugLivingAttackers: Int { attackers.filter { $0.dying == 0 }.count }
  /// Where to point the guns to hit the boss.
  var debugBossPosition: (x: Double, y: Double)? {
    activeBoss.map { ($0.x, $0.y - $0.height / 2) }
  }
  /// Removes every non-boss raider, so a test can fast-forward a wave to its
  /// finale without shooting its way there.
  /// Kills the first living raider outright, without spending an ability —
  /// staging five kinds through the nuke ran the rack of three dry.
  @discardableResult
  func debugKillFirst() -> Bool {
    guard let victim = attackers.first(where: { $0.dying == 0 }) else { return false }
    kill(victim)
    return true
  }

  /// Clears the field entirely, so a test can stage exactly one raider.
  func debugRemoveAllAttackers() {
    attackers.removeAll()
    toSpawn = 0
  }

  func debugCullOrdinary() {
    attackers.removeAll { !$0.isBoss }
    toSpawn = 0
  }
  /// Which barrels have rounds in the air right now.
  var debugBarrelsInUse: Set<Int> { Set(shots.map(\.gun)) }
  /// Where each barrel's muzzle currently is, so a test can tell two guns from
  /// one gun firing twice as fast.
  var debugMuzzles: [(x: Double, y: Double)] {
    guns.map {
      (
        Double($0.x) + cos($0.angle) * Siege.barrelLength,
        Double($0.y) + sin($0.angle) * Siege.barrelLength
      )
    }
  }
  var debugPendingSpawns: Int { toSpawn }
  func debugReleaseAll() { held.removeAll() }
  /// Position of a living raider, for pointing the cannon at something.
  var debugFirstTarget: (x: Double, y: Double)? {
    attackers.first { $0.dying == 0 }.map { ($0.x, $0.y - $0.height / 2) }
  }
  func debugSpawn(_ kind: Raider, atX x: Double, facing: Int) {
    let raider = Attacker(x: x, y: Double(Siege.groundY), kind: kind, facing: facing)
    // Match what the real spawner does: a paratrooper starts in the air under
    // a chute, not standing on the ground.
    if kind == .paratrooper {
      raider.y = -80
      raider.descending = true
    }
    attackers.append(raider)
  }
}

// MARK: - Drawing

extension Siege {

  func draw(_ g: Graphics) {
    if phase == .selecting {
      drawSetup(g)
      return
    }

    // Screen shake, applied by nudging everything that is drawn in the world.
    let jitterX = shake > 0.3 ? Int(Double.random(in: -shake...shake)) : 0
    let jitterY = shake > 0.3 ? Int(Double.random(in: -shake...shake)) : 0

    drawBackdrop(g, jitterX, jitterY)
    drawGround(g, jitterY)
    drawRemains(g, jitterX, jitterY)
    drawHorde(g, jitterX, jitterY)
    drawFortress(g, jitterX, jitterY)
    drawCannon(g, jitterX, jitterY)
    drawField(g, jitterX, jitterY)
    drawShots(g, jitterX, jitterY)
    drawShells(g, jitterX, jitterY)
    drawSmartBombs(g, jitterX, jitterY)
    drawKits(g, jitterX, jitterY)
    drawFlecks(g, jitterX, jitterY)
    drawNuke(g)
    drawHUD(g)
    if gameOver { drawGameOver(g) }
  }

  /// The detonation: a hard white flash, then a shockwave off the tower.
  ///
  /// `Graphics` has no alpha to fade with, so the flash is a few solid frames
  /// and the falloff is carried by expanding rings instead.
  private func drawNuke(_ g: Graphics) {
    guard nukeFlash > 0 else { return }
    let top = Siege.hudHeight
    let height = Level.canvasHeight - top

    if nukeFlash > Siege.nukeFlashFrames - 3 {
      g.setColor(AWTColor.white)
      g.fillRect(0, top, Level.canvasWidth, height)
      return
    }

    let age = Siege.nukeFlashFrames - nukeFlash
    let centreX = Siege.towerCenterX
    let centreY = Siege.roofY
    for (index, color) in [
      (0, AWTColor.white), (1, AWTColor.packed(0xFFFFE07A)),
      (2, AWTColor.packed(0xFFFF8A2A)),
    ] {
      let radius = (age - index * 3) * 38
      guard radius > 0 else { continue }
      g.setColor(color)
      // A band rather than a hairline, so it reads at speed.
      for ring in 0..<4 {
        g.drawOval(
          centreX - radius - ring, centreY - radius - ring,
          (radius + ring) * 2, (radius + ring) * 2)
      }
    }
  }

  /// The setup screen: pick the wave to start on before the first raider
  /// appears, rather than grinding through the early ones every run.
  private func drawSetup(_ g: Graphics) {
    drawBackdrop(g, 0, 0)
    g.setColor(AWTColor.packed(0xFF08_0810))
    g.fillRect(150, 120, 500, 360)
    g.setColor(AWTColor.packed(0xFFE8563A))
    g.drawRect(150, 120, 500, 360)

    g.setFont(size: 26, bold: true)
    g.drawString("LEMMING SIEGE", 285, 172)

    g.setFont(size: 14)
    g.setColor(AWTColor.packed(0xFF9A9AAA))
    g.drawString("hold the tower. they come from both sides.", 240, 204)

    g.setFont(size: 15, bold: true)
    g.setColor(AWTColor.white)
    g.drawString("START AT WAVE", 338, 248)

    // The minus and plus buttons, and the number between them.
    for (box, label) in [(Siege.minusBox, "-"), (Siege.plusBox, "+")] {
      let enabled =
        label == "-" ? startWave > 1 : startWave < Siege.maxStartWave
      g.setColor(AWTColor.packed(enabled ? 0xFF2A2A36 : 0xFF18181E))
      g.fillRect(box.x, box.y, box.w, box.h)
      g.setColor(AWTColor.packed(enabled ? 0xFFE8563A : 0xFF3A3A44))
      g.drawRect(box.x, box.y, box.w, box.h)
      g.setFont(size: 30, bold: true)
      g.drawString(label, box.x + 19, box.y + 38)
    }

    g.setFont(size: 44, bold: true)
    g.setColor(AWTColor.packed(0xFFF2D23A))
    let digits = "\(startWave)"
    g.drawString(digits, 400 - digits.count * 13, 302)

    // What that wave actually sends, read off the same table the spawner uses.
    let briefing = waveBriefing
    g.setFont(size: 13)
    g.setColor(AWTColor.packed(0xFF9A9AAA))
    g.drawString("\(briefing.count) raiders  .  \(briefing.kinds)", 246, 340)

    g.setColor(AWTColor.packed(0xFF2A2A36))
    g.fillRect(Siege.beginBox.x, Siege.beginBox.y, Siege.beginBox.w, Siege.beginBox.h)
    g.setColor(AWTColor.packed(0xFF5ADC5A))
    g.drawRect(Siege.beginBox.x, Siege.beginBox.y, Siege.beginBox.w, Siege.beginBox.h)
    g.setFont(size: 18, bold: true)
    g.drawString("HOLD THE LINE", 330, 403)

    g.setFont(size: 12)
    g.setColor(AWTColor.packed(0xFF7A7A8A))
    g.drawString("arrows or -/+ change wave  .  up/down by five", 236, 436)
    g.drawString("enter or click to begin  .  N backdrop  .  esc out", 232, 452)
    g.setColor(AWTColor.packed(0xFFFFD23A))
    g.drawString(
      "\(Siege.nukesPerStage) nukes (Q)  .  \(Siege.fieldsPerStage) force fields (E)",
      264, 470)
  }

  private func drawBackdrop(_ g: Graphics, _ jx: Int, _ jy: Int) {
    // A slice of a level painting, already darkened, scaled to fill.
    let height = Level.canvasHeight - Siege.hudHeight
    g.setColor(AWTColor.packed(0xFF08_0810))
    g.fillRect(0, 0, Level.canvasWidth, Level.canvasHeight)
    g.drawImage(
      backdrop, jx / 3, Siege.hudHeight + jy / 3, Level.canvasWidth, height)
  }

  private func drawGround(_ g: Graphics, _ jy: Int) {
    let y = Siege.groundY + jy
    g.setColor(AWTColor.packed(0xFF2A2420))
    g.fillRect(0, y, Level.canvasWidth, Level.canvasHeight - y)
    g.setColor(AWTColor.packed(0xFF4A4038))
    g.fillRect(0, y, Level.canvasWidth, 4)
  }

  /// Stains first, then the bodies heaped on top of them. Drawn before the
  /// living, so raiders walk over their own dead.
  private func drawRemains(_ g: Graphics, _ jx: Int, _ jy: Int) {
    for stain in stains {
      // Dries out towards the end rather than vanishing outright.
      let fading = stain.life < 600 && (stain.life / 9) % 2 == 0
      if fading { continue }
      g.setColor(AWTColor.packed(stain.color))
      g.fillOval(
        Int(stain.x) + jx, Int(stain.y) + jy, Int(stain.w), Int(stain.h))
    }

    let sprites = Sprites.shared
    for corpse in corpses {
      // Flickers out over its last few seconds.
      if corpse.life < Siege.corpseFadeFrames && (corpse.life / 8) % 2 == 0 { continue }
      let image = corpse.facingRight ? sprites.die3 : sprites.die2
      let w = Int(36 * corpse.scale)
      let h = Int(41 * corpse.scale)
      g.drawImage(
        image, Int(corpse.x) + jx - w / 2, Int(corpse.y) + jy - h, w, h)
    }
  }

  private func drawFortress(_ g: Graphics, _ jx: Int, _ jy: Int) {
    let left = Siege.fortressLeft + jx
    let top = Siege.fortressTop + jy
    let width = Siege.fortressRight - Siege.fortressLeft
    let bottom = Siege.groundY + jy

    g.setColor(AWTColor.packed(0xFF6E6E7A))
    g.fillRect(left, top, width, bottom - top)
    g.setColor(AWTColor.packed(0xFF5A5A66))
    Siege.courses(g, left: left, top: top, right: left + width, bottom: bottom)

    // Battlements, which crumble away as the wall takes damage.
    let fraction = max(health / Siege.maxHealth, 0)
    let merlons = 5
    for i in 0..<merlons {
      let standing = Double(i) / Double(merlons) < fraction
      guard standing else { continue }
      g.setColor(AWTColor.packed(0xFF6E6E7A))
      g.fillRect(left + 4 + i * 23, top - 16, 15, 16)
    }

    // Cracks, drawn as the damage mounts.
    if fraction < 0.75 {
      g.setColor(AWTColor.packed(0xFF32323C))
      g.fillRect(left + 20, top + 30, 3, 60)
      g.fillRect(left + 21, top + 86, 26, 3)
    }
    if fraction < 0.45 {
      g.setColor(AWTColor.packed(0xFF32323C))
      g.fillRect(left + 80, top + 18, 3, 90)
      g.fillRect(left + 54, top + 100, 30, 3)
    }
    if fraction < 0.2 {
      g.setColor(AWTColor.packed(0xFF32323C))
      g.fillRect(left + 40, top + 60, 3, 120)
      g.fillRect(left + 12, top + 150, 60, 3)
    }

    // Health bar on the parapet, framed so it reads as a gauge rather than as
    // part of the building.
    let barWidth = width - 8
    g.setColor(AWTColor.packed(0xFF0A0A10))
    g.fillRect(left + 2, top - 32, barWidth + 4, 12)
    g.setColor(AWTColor.packed(0xFF1A1A22))
    g.fillRect(left + 4, top - 30, barWidth, 8)
    let filled = Int(Double(barWidth) * fraction)

    // Banked repair shown as a dim segment ahead of the solid bar, so it is
    // visible that the wall is coming back without anything flashing.
    if repairReserve > 0 {
      let pending = min(repairReserve / Siege.maxHealth, 1 - fraction)
      let extra = Int(Double(barWidth) * pending)
      g.setColor(AWTColor.packed(0xFF2E6A3A))
      g.fillRect(left + 4 + filled, top - 30, max(extra, 0), 8)
    }

    g.setColor(
      fraction > 0.5
        ? AWTColor.packed(0xFF5ADC5A)
        : (fraction > 0.25 ? AWTColor.packed(0xFFE8C23A) : AWTColor.packed(0xFFE8563A)))
    g.fillRect(left + 4, top - 30, max(filled, 0), 8)
  }

  /// Horizontal courses and staggered joints, so a flat rect reads as masonry.
  private static func courses(_ g: Graphics, left: Int, top: Int, right: Int, bottom: Int) {
    var y = top
    var row = 0
    while y < bottom {
      g.fillRect(left, y, right - left, 1)
      var x = left + (row % 2 == 0 ? 0 : 20)
      while x < right {
        g.fillRect(x, y, 1, 18)
        x += 40
      }
      y += 18
      row += 1
    }
  }

  /// Draws both barrels. The far one goes down first so the near one overlaps
  /// it, which reads as depth on a flat tower roof.
  private func drawCannon(_ g: Graphics, _ jx: Int, _ jy: Int) {
    // Envelopes first, so the guns hang in front of their own ship. Drawn
    // from the ship list rather than per gun, or each would be drawn twice
    // now that they carry a pair.
    for index in Siege.airships.indices {
      drawAirship(g, index, jx, jy)
    }
    let ordered = guns.sorted { abs($0.angle) > abs($1.angle) }
    for gun in ordered {
      drawGun(g, gun, jx, jy)
    }
  }

  /// The airship a corner gun is slung under: envelope, fins and gondola.
  private func drawAirship(_ g: Graphics, _ index: Int, _ jx: Int, _ jy: Int) {
    let ship = Siege.airships[index]
    let x = ship.x + jx
    // The envelope sits above the gondola, and rides the same drift.
    let y = ship.y + airshipLift[index] + jy - 44
    let width = 168
    let height = 52

    // Envelope.
    g.setColor(AWTColor.packed(0xFF3A3A4A))
    g.fillOval(x - width / 2, y - height / 2, width, height)
    g.setColor(AWTColor.packed(0xFF55556A))
    g.fillOval(x - width / 2 + 5, y - height / 2 + 4, width - 10, height / 2)
    // A band along the middle.
    g.setColor(AWTColor.packed(0xFF8A2A2A))
    g.fillRect(x - 7, y - height / 2 + 3, 14, height - 6)

    // Tail fins, on whichever side faces the middle of the map.
    let outward = ship.x < Siege.towerCenterX ? -1 : 1
    let tailX = x + outward * (width / 2 - 6)
    g.setColor(AWTColor.packed(0xFF55556A))
    g.fillPolygon([
      (tailX, y - 4), (tailX + outward * 26, y - 26), (tailX + outward * 26, y + 2),
    ])
    g.fillPolygon([
      (tailX, y + 4), (tailX + outward * 26, y + 26), (tailX + outward * 26, y - 2),
    ])

    // Gondola, and the rigging down to it.
    g.setColor(AWTColor.packed(0xFF2A2A34))
    g.fillRect(x - 3, y + height / 2 - 4, 2, 18)
    g.fillRect(x + 2, y + height / 2 - 4, 2, 18)
    // A longer gondola, since it now carries two mounts.
    g.setColor(AWTColor.packed(0xFF4A4A58))
    g.fillRect(x - 32, y + height / 2 + 12, 64, 16)
    g.setColor(AWTColor.packed(0xFF8ACFE8))
    g.fillRect(x - 24, y + height / 2 + 16, 9, 7)
    g.fillRect(x - 5, y + height / 2 + 16, 9, 7)
    g.fillRect(x + 14, y + height / 2 + 16, 9, 7)
  }

  private func drawGun(_ g: Graphics, _ gun: Gun, _ jx: Int, _ jy: Int) {
    let pivotX = Double(gun.x + jx)
    let pivotY = Double(gun.y + jy)
    let dx = cos(gun.angle)
    let dy = sin(gun.angle)
    // Recoil slides the barrel back along its own axis.
    let baseX = pivotX - dx * gun.recoil
    let baseY = pivotY - dy * gun.recoil

    // Barrel as a quad along the aim, with a perpendicular half-width.
    let halfWidth = 6.5
    let px = -dy * halfWidth
    let py = dx * halfWidth
    let tipX = baseX + dx * Siege.barrelLength
    let tipY = baseY + dy * Siege.barrelLength

    g.setColor(AWTColor.packed(0xFF3A3A46))
    g.fillPolygon([
      (Int(baseX + px), Int(baseY + py)),
      (Int(tipX + px), Int(tipY + py)),
      (Int(tipX - px), Int(tipY - py)),
      (Int(baseX - px), Int(baseY - py)),
    ])
    // Mirrored barrels wear a brass highlight, straight ones steel, so which
    // is which is visible without working it out from where they point.
    g.setColor(AWTColor.packed(gun.mirrored ? 0xFFB08A3A : 0xFF5E5E6E))
    g.fillPolygon([
      (Int(baseX + px), Int(baseY + py)),
      (Int(tipX + px), Int(tipY + py)),
      (Int(tipX + px * 0.4), Int(tipY + py * 0.4)),
      (Int(baseX + px * 0.4), Int(baseY + py * 0.4)),
    ])

    // Mount.
    g.setColor(AWTColor.packed(0xFF4A4A58))
    g.fillOval(gun.x + jx - 15, gun.y + jy - 15, 30, 30)
    g.setColor(AWTColor.packed(gun.mirrored ? 0xFFB08A3A : 0xFF6E6E80))
    g.fillOval(gun.x + jx - 8, gun.y + jy - 8, 16, 16)

    if gun.muzzle > 0 {
      // Kept small enough that the barrel still reads underneath it.
      let size = 16 + gun.muzzle * 6
      g.setColor(AWTColor.packed(0xFFFF8A2A))
      g.fillOval(Int(tipX) - size / 2, Int(tipY) - size / 2, size, size)
      g.setColor(AWTColor.packed(0xFFFFE07A))
      g.fillOval(Int(tipX) - size / 3, Int(tipY) - size / 3, size * 2 / 3, size * 2 / 3)
      g.setColor(AWTColor.white)
      g.fillOval(Int(tipX) - size / 6, Int(tipY) - size / 6, size / 3, size / 3)
    }
  }

  private func drawHorde(_ g: Graphics, _ jx: Int, _ jy: Int) {
    let sprites = Sprites.shared
    for attacker in attackers {
      let image: Bitmap
      if attacker.dying > 0 {
        let stage = Attacker.deathFrames - attacker.dying
        image = stage < 5 ? sprites.die1 : (stage < 10 ? sprites.die2 : sprites.die3)
      } else {
        switch attacker.kind {
        case .heavy:
          image = sprites.blocker
        case .paratrooper where attacker.descending:
          // The real parachute sprite: canopy, rigging and all.
          image = sprites.floater
        case .shooter:
          // The drill sprites, cycling as it works the thing it is firing.
          image = (attacker.step / 6) % 2 == 0 ? sprites.digRight : sprites.digLeft
        default:
          // Walk cycle, facing the way it is travelling.
          let phase = (attacker.step / (attacker.kind == .runner ? 4 : 7)) % 3
          if attacker.facing > 0 {
            image = phase == 0 ? sprites.rightMid : (phase == 1 ? sprites.rightFront : sprites.rightBack)
          } else {
            image = phase == 0 ? sprites.leftMid : (phase == 1 ? sprites.leftFront : sprites.leftBack)
          }
        }
      }

      // A descending raider is drawn a little larger so the canopy reads
      // against the sky.
      let bulk = attacker.descending ? 1.25 : 1.0
      let w = Int(attacker.width * bulk)
      let h = Int(attacker.height * bulk)
      let drawX = Int(attacker.x) - w / 2 + jx
      let drawY = Int(attacker.y) - h + jy

      if attacker.isBoss && attacker.dying == 0 {
        drawBossAura(g, attacker, drawX, drawY, w, h)
      }
      g.drawImage(image, drawX, drawY, w, h)
      if attacker.isBoss && attacker.dying == 0 {
        drawBossRegalia(g, attacker, drawX, drawY, w, h)
      }
      if attacker.kind == .bomber && attacker.dying == 0 {
        drawBombCharge(g, drawX, drawY, w, h, step: attacker.step)
      }
      // White wash on the frame it was hit, so fire registers on something
      // that takes two hundred rounds to drop.
      if attacker.hitFlash > 0 {
        g.setColor(AWTColor.packed(0xFFFFFFFF))
        g.fillRect(drawX + w / 4, drawY + h / 3, w / 2, 3)
      }
    }
  }

  /// The charge a bomber is carrying, with a fuse that sparks as it walks.
  /// Drawn rather than given a sprite of its own, now that the parachute art
  /// belongs to the paratroopers.
  private func drawBombCharge(
    _ g: Graphics, _ x: Int, _ y: Int, _ w: Int, _ h: Int, step: Int
  ) {
    let cx = x + w / 2
    let cy = y + h / 3
    let size = max(w / 3, 8)
    g.setColor(AWTColor.packed(0xFF14141A))
    g.fillOval(cx - size / 2, cy - size / 2, size, size)
    g.setColor(AWTColor.packed(0xFF3A3A48))
    g.fillOval(cx - size / 2 + 2, cy - size / 2 + 2, size / 3, size / 3)
    // Fuse.
    g.setColor(AWTColor.packed(0xFF8A6A3A))
    g.fillRect(cx - 1, cy - size / 2 - 5, 2, 6)
    g.setColor(
      AWTColor.packed((step / 5) % 2 == 0 ? 0xFFFFD23A : 0xFFFF6A2A))
    g.fillOval(cx - 3, cy - size / 2 - 9, 6, 6)
  }

  /// A dark halo behind the boss, so it separates from the backdrop.
  private func drawBossAura(
    _ g: Graphics, _ boss: Attacker, _ x: Int, _ y: Int, _ w: Int, _ h: Int
  ) {
    g.setColor(AWTColor.packed(0xFF2A0A0A))
    g.fillOval(x - 14, y - 10, w + 28, h + 20)
    g.setColor(AWTColor.packed(0xFF4A1414))
    g.fillOval(x - 7, y - 5, w + 14, h + 10)
  }

  /// Horns, pauldrons and lit eyes, drawn over the ordinary sprite. Cheaper
  /// than new art and it reads as a boss at a glance.
  private func drawBossRegalia(
    _ g: Graphics, _ boss: Attacker, _ x: Int, _ y: Int, _ w: Int, _ h: Int
  ) {
    let midX = x + w / 2

    // Horns.
    g.setColor(AWTColor.packed(0xFF1A1A20))
    g.fillPolygon([
      (midX - w / 5, y + h / 7), (midX - w / 3 - 8, y - h / 9), (midX - w / 8, y + h / 24),
    ])
    g.fillPolygon([
      (midX + w / 5, y + h / 7), (midX + w / 3 + 8, y - h / 9), (midX + w / 8, y + h / 24),
    ])

    // Pauldrons.
    g.setColor(AWTColor.packed(0xFF3A1414))
    g.fillRect(x + 2, y + h / 3, w / 5, h / 7)
    g.fillRect(x + w - w / 5 - 2, y + h / 3, w / 5, h / 7)
    g.setColor(AWTColor.packed(0xFF6A2020))
    g.fillRect(x + 2, y + h / 3, w / 5, 4)
    g.fillRect(x + w - w / 5 - 2, y + h / 3, w / 5, 4)

    // Eyes.
    g.setColor(AWTColor.packed(0xFFFF3A2A))
    let eyeY = y + h / 5
    let eye = max(w / 14, 3)
    g.fillRect(midX - w / 7, eyeY, eye, eye)
    g.fillRect(midX + w / 7 - eye, eyeY, eye, eye)
  }

  /// The dome, drawn as a stack of arcs over the tower.
  ///
  /// `drawOval` gives a whole ellipse, so the half below the ground line is
  /// masked by repainting the ground band over it.
  private func drawField(_ g: Graphics, _ jx: Int, _ jy: Int) {
    guard fieldTimer > 0 else { return }

    // Flickers through its last second, so the player sees it about to fail.
    let failing = fieldTimer < 70
    if failing && (fieldTimer / 4) % 2 == 0 {
      drawGround(g, jy)
      return
    }

    let cx = Siege.towerCenterX + jx
    let cy = Siege.groundY + jy
    let radius = Int(Siege.fieldRadius)
    let shimmer = (frames / 3) % 7

    for ring in 0..<5 {
      let r = radius - ring * 6 - shimmer
      guard r > 20 else { continue }
      g.setColor(
        AWTColor.packed(ring == 0 ? 0xFFBFF2FF : (ring < 3 ? 0xFF6ADCFF : 0xFF2A8ABF)))
      g.drawOval(cx - r, cy - r, r * 2, r * 2)
    }

    // Bright anchors where the dome meets the ground.
    g.setColor(AWTColor.packed(0xFFBFF2FF))
    g.fillOval(cx - radius - 4, cy - 8, 10, 10)
    g.fillOval(cx + radius - 6, cy - 8, 10, 10)

    drawGround(g, jy)
  }

  private func drawShots(_ g: Graphics, _ jx: Int, _ jy: Int) {
    for shot in shots {
      // Drawn as a streak back along its own velocity, which is what sells
      // speed on a 60Hz display.
      let tailX = shot.x - shot.vx * 0.9
      let tailY = shot.y - shot.vy * 0.9
      g.setColor(AWTColor.packed(0xFFFFA83A))
      g.fillPolygon([
        (Int(tailX) + jx, Int(tailY) + jy - 1),
        (Int(shot.x) + jx, Int(shot.y) + jy - 2),
        (Int(shot.x) + jx, Int(shot.y) + jy + 2),
        (Int(tailX) + jx, Int(tailY) + jy + 1),
      ])
      g.setColor(AWTColor.packed(0xFFFFF0B0))
      g.fillOval(Int(shot.x) + jx - 2, Int(shot.y) + jy - 2, 5, 5)
    }
  }

  /// Guided bombs under power, and the blasts they leave.
  private func drawSmartBombs(_ g: Graphics, _ jx: Int, _ jy: Int) {
    for bomb in smartBombs {
      let x = Int(bomb.x) + jx
      let y = Int(bomb.y) + jy
      let dx = cos(bomb.heading)
      let dy = sin(bomb.heading)

      // Exhaust, trailing back along the heading and flickering.
      let flare = (bomb.age / 2) % 2 == 0 ? 16.0 : 11.0
      g.setColor(AWTColor.packed(0xFFFF8A2A))
      g.fillPolygon([
        (x - Int(dx * flare) - Int(dy * 4), y - Int(dy * flare) + Int(dx * 4)),
        (x - Int(dx * flare) + Int(dy * 4), y - Int(dy * flare) - Int(dx * 4)),
        (x - Int(dx * 26), y - Int(dy * 26)),
      ])
      g.setColor(AWTColor.packed(0xFFFFE07A))
      g.fillOval(x - Int(dx * 9) - 3, y - Int(dy * 9) - 3, 7, 7)

      // Body: a dark dart pointing where it is going.
      g.setColor(AWTColor.packed(0xFF2A2A34))
      g.fillPolygon([
        (x + Int(dx * 11), y + Int(dy * 11)),
        (x - Int(dx * 7) - Int(dy * 5), y - Int(dy * 7) + Int(dx * 5)),
        (x - Int(dx * 7) + Int(dy * 5), y - Int(dy * 7) - Int(dx * 5)),
      ])
      g.setColor(AWTColor.packed(0xFFC03A3A))
      g.fillOval(x - 2, y - 2, 5, 5)
    }

    for blast in blasts {
      let age = Double(Blast.duration - blast.life) / Double(Blast.duration)
      let radius = Int(Siege.smartBombRadius * (0.35 + age * 0.9))
      let x = Int(blast.x) + jx
      let y = Int(blast.y) + jy
      g.setColor(AWTColor.packed(age < 0.4 ? 0xFFFFFFFF : 0xFFFF8A2A))
      g.fillOval(x - radius, y - radius, radius * 2, radius * 2)
      let core = radius / 2
      g.setColor(AWTColor.packed(0xFFFFE07A))
      g.fillOval(x - core, y - core, core * 2, core * 2)
    }
  }

  /// Supply crates: a canopy while they fall, blinking once they are about to
  /// be lost.
  private func drawKits(_ g: Graphics, _ jx: Int, _ jy: Int) {
    for kit in kits {
      let x = Int(kit.x) + jx
      let y = Int(kit.y) + jy
      let size = Siege.kitSize

      // About to expire: blink, so it reads as running out rather than just
      // vanishing.
      if kit.landed && kit.linger < 120 && (kit.linger / 7) % 2 == 0 { continue }

      if !kit.landed {
        // Canopy and rigging. Drawn rather than a sprite, because the only
        // parachute art there is belongs to the paratroopers.
        let span = size * 2
        let top = y - 40
        g.setColor(AWTColor.packed(0xFFE8E8E0))
        g.fillOval(x - span / 2, top, span, 30)
        g.setColor(AWTColor.packed(0xFF5ADC5A))
        g.fillOval(x - span / 6, top + 2, span / 3, 24)
        g.setColor(AWTColor.packed(0xFF8A8A96))
        g.fillRect(x - span / 2 + 3, top + 16, 2, 22)
        g.fillRect(x + span / 2 - 5, top + 16, 2, 22)
      }

      // The crate.
      g.setColor(AWTColor.packed(0xFF2A2A34))
      g.fillRect(x - size / 2 - 1, y - size / 2 - 1, size + 2, size + 2)
      g.setColor(AWTColor.packed(0xFFE8E8E0))
      g.fillRect(x - size / 2, y - size / 2, size, size)
      // Green cross.
      g.setColor(AWTColor.packed(0xFF2EA84A))
      g.fillRect(x - 3, y - size / 2 + 4, 6, size - 8)
      g.fillRect(x - size / 2 + 4, y - 3, size - 8, 6)
    }
  }

  /// Shells on their way to the tower.
  private func drawShells(_ g: Graphics, _ jx: Int, _ jy: Int) {
    for shell in shells {
      let tailX = shell.x - shell.vx * 1.6
      let tailY = shell.y - shell.vy * 1.6
      g.setColor(AWTColor.packed(0xFF6A4A2A))
      g.fillPolygon([
        (Int(tailX) + jx, Int(tailY) + jy - 1),
        (Int(shell.x) + jx, Int(shell.y) + jy - 3),
        (Int(shell.x) + jx, Int(shell.y) + jy + 3),
        (Int(tailX) + jx, Int(tailY) + jy + 1),
      ])
      g.setColor(AWTColor.packed(0xFFFF6A2A))
      g.fillOval(Int(shell.x) + jx - 4, Int(shell.y) + jy - 4, 9, 9)
      g.setColor(AWTColor.packed(0xFFFFE07A))
      g.fillOval(Int(shell.x) + jx - 2, Int(shell.y) + jy - 2, 4, 4)
    }
  }

  private func drawFlecks(_ g: Graphics, _ jx: Int, _ jy: Int) {
    for fleck in flecks {
      g.setColor(AWTColor.packed(fleck.color))
      g.fillRect(Int(fleck.x) + jx, Int(fleck.y) + jy, fleck.size, fleck.size)
    }
  }

  private func drawHUD(_ g: Graphics) {
    g.setColor(AWTColor.packed(0xFF0E0E14))
    g.fillRect(0, 0, Level.canvasWidth, Siege.hudHeight)
    g.setColor(AWTColor.packed(0xFF8A2A2A))
    g.fillRect(0, Siege.hudHeight - 2, Level.canvasWidth, 2)

    g.setFont(size: 15, bold: true)
    g.setColor(AWTColor.packed(0xFFE8563A))
    g.drawString("LEMMING SIEGE", 12, 26)

    g.setFont(size: 13)
    g.setColor(AWTColor.white)
    g.drawString("w\(max(wave, 1))", 148, 26)
    g.setColor(AWTColor.packed(0xFFF2D23A))
    g.drawString("\(score)", 192, 26)
    g.setColor(AWTColor.white)
    g.drawString("x\(kills)", 268, 26)
    g.setColor(
      isRepairing ? AWTColor.packed(0xFF5ADC5A) : AWTColor.packed(0xFF8ADC8A))
    g.drawString("wall \(Int(health))%", 322, 26)

    // Two racks of charges, as pips that go dark once spent and refill as they
    // come back.
    g.setFont(size: 11)
    drawCharges(
      g, label: "NUKE", labelX: 424, pipX: 458, count: Siege.nukesPerStage,
      left: nukesLeft, charging: nukeRechargeFraction,
      full: 0xFFFFD23A, core: 0xFFFF8A2A, partial: 0xFF8A6A1A)
    drawCharges(
      g, label: "FIELD", labelX: 500, pipX: 540, count: Siege.fieldsPerStage,
      left: fieldsLeft, charging: fieldRechargeFraction,
      full: fieldIsUp ? 0xFFBFF2FF : 0xFF6ADCFF, core: 0xFF2A8ABF, partial: 0xFF1A5A7A)
    // The guided bomb needs no input, so this is a readiness dial rather than
    // a rack: one pip, filling toward the next release.
    drawCharges(
      g, label: "BOMB", labelX: 578, pipX: 614, count: 1, left: 0,
      charging: 1 - Double(smartBombTimer) / Double(Siege.smartBombInterval),
      full: 0xFFC03A3A, core: 0xFF2A2A34, partial: 0xFFC03A3A)

    g.setColor(AWTColor.packed(0xFF7A7A8A))
    g.setFont(size: 11)
    g.setColor(AWTColor.packed(0xFF7A7A8A))
    g.drawString("mouse aims . hold to fire", 640, 17)
    g.drawString("Q nuke . E field . RMB focus", 640, 32)

    // Boss bar, across the top of the field while one is standing.
    if let boss = activeBoss {
      let fraction = Double(boss.health) / Double(max(boss.maxHealth, 1))
      let barX = 120
      let barWidth = Level.canvasWidth - barX * 2
      g.setColor(AWTColor.packed(0xFF0A0A10))
      g.fillRect(barX - 3, 54, barWidth + 6, 20)
      g.setColor(AWTColor.packed(0xFF1A1A22))
      g.fillRect(barX, 57, barWidth, 14)
      g.setColor(AWTColor.packed(fraction > 0.35 ? 0xFFC8203A : 0xFFE8663A))
      g.fillRect(barX, 57, max(Int(Double(barWidth) * fraction), 0), 14)
      g.setColor(AWTColor.packed(0xFF8A2A2A))
      g.drawRect(barX - 3, 54, barWidth + 6, 20)

      g.setFont(size: 12, bold: true)
      g.setColor(AWTColor.white)
      g.drawString("BRUTE  \(boss.health)/\(boss.maxHealth)", barX + 6, 68)
    }

    // Arrival banner.
    if bossWarning > 0 {
      g.setFont(size: 26, bold: true)
      // Flashes while it walks on.
      g.setColor(
        AWTColor.packed((bossWarning / 8) % 2 == 0 ? 0xFFE8203A : 0xFFFFD23A))
      g.drawString("A BRUTE IS COMING", 258, 120)
    }

    // Incoming-wave banner between waves. Suppressed while a brute is being
    // announced, or the two banners print on top of each other.
    if toSpawn == 0 && !gameOver && wavePause < 150 && bossWarning == 0 {
      g.setFont(size: 22, bold: true)
      g.setColor(AWTColor.packed(0xFFE8563A))
      g.drawString("WAVE \(wave + 1) INCOMING", 270, 110)
    }
  }

  /// One rack of ability charges.
  private func drawCharges(
    _ g: Graphics, label: String, labelX: Int, pipX: Int, count: Int, left: Int,
    charging: Double, full: UInt32, core: UInt32, partial: UInt32
  ) {
    g.setColor(AWTColor.packed(0xFF7A7A8A))
    g.drawString(label, labelX, 26)
    for index in 0..<count {
      let x = pipX + index * 15
      if index < left {
        g.setColor(AWTColor.packed(full))
        g.fillOval(x, 15, 12, 12)
        g.setColor(AWTColor.packed(core))
        g.fillOval(x + 3, 18, 6, 6)
      } else {
        g.setColor(AWTColor.packed(0xFF2A2A34))
        g.fillOval(x, 15, 12, 12)
        if index == left && charging > 0 {
          let size = max(Int(12 * charging), 1)
          let inset = (12 - size) / 2
          g.setColor(AWTColor.packed(partial))
          g.fillOval(x + inset, 15 + inset, size, size)
        }
      }
    }
  }

  private func drawGameOver(_ g: Graphics) {
    g.setColor(AWTColor.packed(0xFF0E0E14))
    g.fillRect(200, 210, 400, 180)
    g.setColor(AWTColor.packed(0xFFE8563A))
    g.drawRect(200, 210, 400, 180)
    g.setFont(size: 26, bold: true)
    g.drawString("THE WALL IS DOWN", 245, 262)
    g.setFont(size: 14)
    g.setColor(AWTColor.white)
    g.drawString("survived \(max(wave, 1)) waves", 255, 305)
    g.drawString("\(kills) lemmings stopped, score \(score)", 255, 330)
    g.setColor(AWTColor.packed(0xFF7A7A8A))
    g.drawString("R to retry from wave \(startWave)", 255, 358)
    g.drawString("enter to pick a different wave", 255, 376)
  }
}
