import Foundation

/// The movement and collision step for a single lemming, run once per frame.
///
/// Ported deliberately literally, including one quirk worth knowing about
/// before touching it: `x` and `y` below are *copies* taken on entry and written
/// back at the very end, while the ability methods (`mine`, `climb`) move the
/// lemming directly. So whenever control reaches the bottom of this function,
/// the write-back discards whatever those methods did to the position — which is
/// exactly what makes a climber that tops out keep its climbed height but lose
/// the ledge hop, and it is load-bearing for how climbing actually looks. The
/// early `return`s after `mine()` and after a climb-in-progress are what let
/// those two keep their movement.
enum LiteKernel {

  static func move(_ lemming: Lemming) {
    var x = lemming.xPos
    var y = lemming.yPos

    // A dead lemming, or one standing as a wall, does not move.
    if lemming.dead || lemming.blocking { return }

    // Falling far enough is fatal, but only on landing, and never for floaters.
    if lemming.fallCounter > lemming.dropLen / 5 && !lemming.isFloater {
      lemming.fallDying = true
    }
    if lemming.fallDying && !isColor(lemming.bottomColor(0), Mask.black) && !lemming.isFloater {
      lemming.dying = true
    }

    if lemming.exited() { return }

    if lemming.isDigger { lemming.dig() }

    // Stand still for a few frames after finishing a bridge.
    if lemming.bridgePause {
      lemming.noDir = true
      lemming.pauseCounter += 1
      if lemming.pauseCounter > 5 {
        lemming.noDir = false
        lemming.bridgePause = false
      }
    }

    // A blocker stamps itself into the mask once, then holds position.
    if lemming.isBlocker && !lemming.blocking {
      lemming.block()
      lemming.isDigger = false
      lemming.noDir = true
    }

    if lemming.isFloater {
      lemming.floatt()
      lemming.fallDying = false
      lemming.resetFallCounter()
    }

    if lemming.isBasher { lemming.bash(lemming.rightDir) }

    // The miner moves itself diagonally, so it returns before the write-back.
    if lemming.isMiner {
      lemming.mine()
      return
    }

    if lemming.isBridger && !isColor(lemming.bottomColor(0), Mask.black) {
      lemming.bridge()
    }

    if (lemming.isClimber && lemming.climbable(lemming.rightDir)) || lemming.climbing {
      lemming.climb(lemming.rightDir)

      // Still on the wall: keep the two pixels climb() just gained.
      if lemming.climbing { return }

      // Hit a ceiling: bounce off the wall and turn around.
      if lemming.falling {
        x += lemming.rightDir ? -4 : 4
        y += 4
        lemming.rightDir = !lemming.rightDir
      }
    }

    // White is lava/water: instant death, no animation.
    if isColor(lemming.bottomColor(0), Mask.white) {
      lemming.dead = true
    }

    if isColor(lemming.bottomColor(0), Mask.black) {
      // Nothing underfoot: fall.
      y += 2 + lemming.speedUp
      lemming.falling = true
      lemming.isBridger = false

      if isColor(lemming.bottomColor(2), Mask.black) && !lemming.isFloater {
        y += 4
        lemming.isDigger = false
        lemming.climbing = false
        lemming.falling = true
      } else if lemming.isFloater {
        y -= 1
        lemming.isDigger = false
      } else {
        lemming.falling = false
      }

    } else if !isColor(lemming.rightColor, Mask.black) && lemming.rightDir && !lemming.noDir {
      lemming.resetFallCounter()
      if isColor(lemming.rightUpColor, Mask.black) {
        // Walkable slope ahead: step up.
        x += 4
        y -= 2
      } else {
        // Wall ahead: turn around.
        lemming.rightDir = !lemming.rightDir
        x -= 4
        lemming.isBridger = false
      }

    } else if !isColor(lemming.leftColor, Mask.black) && !lemming.rightDir && !lemming.noDir {
      lemming.resetFallCounter()
      if isColor(lemming.leftUpColor, Mask.black) {
        x -= 4
        y -= 2
      } else {
        lemming.rightDir = !lemming.rightDir
        x += 4
        lemming.isBridger = false
      }

    } else {
      lemming.resetFallCounter()
      if !lemming.noDir {
        x += lemming.rightDir ? (4 + lemming.speedUp) : -(4 + lemming.speedUp)
      }
    }

    lemming.xPos = x
    lemming.yPos = y
  }
}
