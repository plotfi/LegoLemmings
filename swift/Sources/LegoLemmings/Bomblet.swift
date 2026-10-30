import Foundation

/// One submunition of a cluster: a lemming-shaped duplicate thrown clear of its
/// carrier, which detonates when it hits terrain or when its fuse runs out.
///
/// Bomblets are deliberately not `Lemming`s. A lemming's movement comes from
/// `LiteKernel` reading the collision mask under its feet, which has no notion
/// of being in the air with a velocity; a projectile needs plain ballistics, so
/// it gets its own tiny type instead of bending the kernel around it.
final class Bomblet {

  /// Position and velocity in level pixels per frame.
  var x: Double
  var y: Double
  var vx: Double
  var vy: Double

  /// Frames left before it goes off regardless of what it has hit.
  var fuse: Int

  /// Frames since launch. A bomblet starts out inside its carrier, so it does
  /// not test for terrain until it has had a moment to clear it.
  var age = 0

  init(x: Double, y: Double, vx: Double, vy: Double, fuse: Int) {
    self.x = x
    self.y = y
    self.vx = vx
    self.vy = vy
    self.fuse = fuse
  }

  /// Downward acceleration, in pixels per frame per frame.
  static let gravity = 2.0

  /// Frames before a bomblet will react to terrain.
  static let armingDelay = 2

  func advance() {
    age += 1
    fuse -= 1
    vy += Bomblet.gravity
    x += vx
    y += vy
  }
}

/// The flash left behind by a detonation, drawn for a few frames as it spreads.
struct Blast {
  var x: Int
  var y: Int
  var radius: Int
  var life: Int

  static let duration = 4
}
