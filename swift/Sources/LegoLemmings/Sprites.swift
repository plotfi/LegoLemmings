import Foundation

/// The lemming animation frames, loaded once.
///
/// These were `static` fields on `Lemming`, filled in by an `init()` call on a
/// throwaway lemming the main window constructed purely for that side effect.
///
/// Note the walk/dig/fall/die frames are 36x41 but the climb frames are 41x36 —
/// the climbing lemming is the same art rotated. Several of the ported geometry
/// calculations lean on that swap, so the frames are kept at their natural size
/// rather than normalized.
final class Sprites {

  static let shared = Sprites()

  let rightMid = Assets.bitmap("rightMid.png")
  let rightFront = Assets.bitmap("rightFront.png")
  let rightBack = Assets.bitmap("rightBack.png")
  let leftMid = Assets.bitmap("leftMid.png")
  let leftFront = Assets.bitmap("leftFront.png")
  let leftBack = Assets.bitmap("leftBack.png")

  let rightMidClimb = Assets.bitmap("rightMidClimb.png")
  let rightFrontClimb = Assets.bitmap("rightFrontClimb.png")
  let rightBackClimb = Assets.bitmap("rightBackClimb.png")
  let leftMidClimb = Assets.bitmap("leftMidClimb.png")
  let leftFrontClimb = Assets.bitmap("leftFrontClimb.png")
  let leftBackClimb = Assets.bitmap("leftBackClimb.png")

  let digLeft = Assets.bitmap("digLeft.png")
  let digRight = Assets.bitmap("digRight.png")
  let blocker = Assets.bitmap("blocker.png")
  let fallingRight = Assets.bitmap("fallingDownRight.png")
  let fallingLeft = Assets.bitmap("fallingDownLeft.png")
  let floater = Assets.bitmap("floater.png")

  let die1 = Assets.bitmap("die1.png")
  let die2 = Assets.bitmap("die2.png")
  let die3 = Assets.bitmap("dead.png")

  private init() {}
}
