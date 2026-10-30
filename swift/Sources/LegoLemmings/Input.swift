import Foundation

/// The keys the game reacts to, normalized away from AppKit's key codes.
enum GameKey: Hashable {
  case char(Character)
  case up, down, left, right
  case f1, f2
  case enter, backspace, escape
  case other
}
