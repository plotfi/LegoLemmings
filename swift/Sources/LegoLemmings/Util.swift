import Foundation

/// Wall-clock milliseconds, the stand-in for Java's `System.currentTimeMillis()`
/// (the original wrapped this in a `HiResTimer` singleton that had already been
/// gutted down to exactly this call).
/// The source of game time. Replaceable so the headless self-test can run the
/// simulation as fast as it likes instead of in real time.
var gameClock: () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }

@inline(__always)
func currentTimeMillis() -> Int64 {
  gameClock()
}

/// The mask palette. The level mask is a parallel image to the level art where
/// every pixel is one of these five colors, and the whole game is driven by
/// reading them:
///
/// - `black` empty space: lemmings fall through it
/// - `red`   diggable terrain
/// - `green` indestructible terrain (also painted in by blockers)
/// - `white` instant death (lava / water)
/// - `blue`  the exit
enum Mask {
  static let black: UInt32 = 0xFF00_0000
  static let red: UInt32 = 0xFFFF_0000
  static let green: UInt32 = 0xFF00_FF00
  static let blue: UInt32 = 0xFF00_00FF
  static let white: UInt32 = 0xFFFF_FFFF
}

/// Compares two packed ARGB values by color only. The masks are fully opaque,
/// but PNG decoding is free to hand us whatever alpha it likes, so the alpha
/// byte is never part of the question being asked.
@inline(__always)
func isColor(_ pixel: UInt32, _ color: UInt32) -> Bool {
  (pixel & 0x00FF_FFFF) == (color & 0x00FF_FFFF)
}
