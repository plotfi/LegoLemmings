import Foundation

/// Reads `levelChooser.txt` and hands out the level list in order.
///
/// Each level is two lines of `||`-separated fields:
/// ```
/// level# || file || released || release rate || to save || minutes || x,y
/// digger || blocker || floater || exploder || bridger || climber || miner || basher
/// ```
/// Lines starting with `#` are comments. The original parsed this a character at
/// a time with hand-rolled digit accumulation that silently depended on each
/// field's width; splitting on the separator reads the same file and stops
/// caring how many digits a number has.
struct LevelChooser {

  private(set) var levels: [LevelData] = []

  var levelCount: Int { levels.count }

  func levelData(_ index: Int) -> LevelData {
    levels[index]
  }

  init(contents: String) {
    let lines =
      contents
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty && !$0.hasPrefix("#") }

    var index = 0
    while index + 1 < lines.count {
      let header = lines[index].components(separatedBy: "||")
      let counts = lines[index + 1].components(separatedBy: "||")
      index += 2

      guard header.count >= 7 else {
        FileHandle.standardError.write(
          Data("Skipping malformed level line: \(lines[index - 2])\n".utf8))
        continue
      }

      var data = LevelData()
      data.file = header[1].trimmingCharacters(in: .whitespaces)
      data.count = Int(header[2]) ?? 0
      data.rate = Int(header[3]) ?? 0
      data.goal = Int(header[4]) ?? 0
      data.time = Int(header[5]) ?? 5

      let start = header[6].components(separatedBy: ",")
      if start.count == 2 {
        data.start = (Int(start[0]) ?? 0, Int(start[1]) ?? 0)
      }

      for ability in Ability.allCases where ability.rawValue < counts.count {
        data.abilities[ability.rawValue] = Int(counts[ability.rawValue]) ?? -1
      }
      // Cluster and Lodestone are granted on every level and never run out, so
      // they are not read from the file — which still carries the original
      // eight columns.
      data.abilities[Ability.cluster.rawValue] = Ability.unlimited
      data.abilities[Ability.lodestone.rawValue] = Ability.unlimited

      levels.append(data)
    }
  }

  init() {
    self.init(contents: Assets.text("levelChooser.txt"))
  }
}
