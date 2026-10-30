import Foundation

/// The eight abilities, in the one order the original used everywhere: the
/// toolbar slots left to right, the second line of each `levelChooser.txt`
/// entry, and the order the level-stats screen lists them in.
///
/// The Java code carried these counts around in a `java.util.Stack` that was
/// cloned, popped and `insertElementAt`-ed at hand-computed indices
/// (`7 - slot`). They are just a fixed-size list keyed by ability, so that is
/// what they are here.
enum Ability: Int, CaseIterable {
  case digger, blocker, floater, exploder, bridger, climber, miner, basher
  /// Bursts the lemming into five flying duplicates that each detonate.
  case cluster
  /// Plants the lemming as a magnetic anchor whose field steers and cushions
  /// every other lemming around it. Always granted, and never switches off.
  case lodestone

  /// A use count meaning the ability never runs out.
  static let unlimited = Int.max

  /// Toolbar slot, left to right.
  var slot: Int { rawValue }

  var displayName: String {
    switch self {
    case .digger: return "Digger"
    case .blocker: return "Blocker"
    case .floater: return "Floater"
    case .exploder: return "Exploder"
    case .bridger: return "Bridger"
    case .climber: return "Climber"
    case .miner: return "Miner"
    case .basher: return "Basher"
    case .cluster: return "Cluster"
    case .lodestone: return "Lodestone"
    }
  }
}

/// Everything `levelChooser.txt` says about one level.
struct LevelData {

  /// Base name of the art (`<file>.png`) and the collision mask
  /// (`<file>mask.png`).
  var file: String = ""

  /// How many lemmings the level releases in total.
  var count: Int = 0

  /// Release rate, 1-99. Stored as written in the file; the running level uses
  /// `100 - rate` as its delay, as the original did.
  var rate: Int = 0

  /// How many lemmings have to reach the exit to pass the level.
  var goal: Int = 0

  /// Time limit, in minutes.
  var time: Int = 5

  /// Where lemmings drop in, in level pixels.
  var start: (x: Int, y: Int) = (0, 0)

  /// Uses of each ability, indexed by `Ability.rawValue`. `-1` means the
  /// ability is not available on this level at all.
  var abilities: [Int] = Array(repeating: -1, count: Ability.allCases.count)

  func uses(_ ability: Ability) -> Int {
    abilities[ability.rawValue]
  }

  /// How a use count reads on screen.
  func usesLabel(_ ability: Ability) -> String {
    let count = uses(ability)
    if count == Ability.unlimited { return "unlimited" }
    return "\(count)"
  }
}
