import AppKit
import Foundation

/// Locates the shared `assets/` directory from the original Java tree.
///
/// The Java build copied `src/` and `assets/` into one flat directory and loaded
/// everything off the classpath. Rather than duplicate 4MB of PNGs into the
/// package, this searches the places the assets plausibly live, so `swift run`
/// from anywhere in the repo works and a bundled `.app` works too.
enum Assets {

  static let directory: URL = {
    var candidates: [URL] = []

    if let override = ProcessInfo.processInfo.environment["LEGO_LEMMINGS_ASSETS"] {
      candidates.append(URL(fileURLWithPath: override))
    }
    if let bundled = Bundle.main.resourceURL {
      candidates.append(bundled)
      candidates.append(bundled.appendingPathComponent("assets"))
    }

    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    candidates.append(cwd.appendingPathComponent("assets"))
    candidates.append(cwd.appendingPathComponent("../assets"))
    candidates.append(cwd)

    // ...and relative to this source file, which is what makes a plain
    // `swift build && .build/debug/LegoLemmings` work during development.
    let source = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // LegoLemmings
      .deletingLastPathComponent()  // Sources
      .deletingLastPathComponent()  // swift
      .appendingPathComponent("assets")
    candidates.append(source)

    for candidate in candidates {
      let probe = candidate.appendingPathComponent("levelChooser.txt")
      if FileManager.default.fileExists(atPath: probe.path) {
        return candidate.standardizedFileURL
      }
    }

    fatalError(
      """
      Could not find the game assets.
      Looked for levelChooser.txt in:
      \(candidates.map { "  " + $0.standardizedFileURL.path }.joined(separator: "\n"))
      Set LEGO_LEMMINGS_ASSETS to the assets directory to override.
      """)
  }()

  static func url(_ name: String) -> URL {
    directory.appendingPathComponent(name)
  }

  /// Loads a PNG into a mutable ARGB bitmap. Fatal on failure: every caller is
  /// loading a file the game cannot run without, which is also how the Java
  /// version behaved (it printed "Please Reload all game files" and exited).
  static func bitmap(_ name: String) -> Bitmap {
    guard let bitmap = Bitmap(contentsOf: url(name)) else {
      fatalError("Error: could not read asset \(name) from \(directory.path)")
    }
    return bitmap
  }

  static func text(_ name: String) -> String {
    guard let contents = try? String(contentsOf: url(name), encoding: .utf8) else {
      fatalError("Error reading \(name) from \(directory.path)")
    }
    return contents
  }
}
