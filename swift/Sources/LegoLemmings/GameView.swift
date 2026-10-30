import AppKit

/// The window contents: drives the simulation from a timer, repaints, and turns
/// AppKit events into the game's own input vocabulary.
///
/// This stands in for the AWT `Frame` plus `BufferStrategy` the original drew
/// into directly from its animation thread. AppKit double-buffers already, so
/// there is nothing to flip.
final class GameView: NSView {

  let controller = GameController()

  private var timer: Timer?
  private var trackingArea: NSTrackingArea?

  override var isOpaque: Bool { true }
  override var acceptsFirstResponder: Bool { true }
  override var isFlipped: Bool { false }

  /// Starts the simulation clock.
  func start() {
    timer?.invalidate()
    // 60Hz, because the side-scroller needs it. The puzzle game still advances
    // on its own 10Hz beat; the controller counts frames and only steps it
    // every sixth one, so its simulation is untouched.
    timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) {
      [weak self] _ in
      guard let self else { return }
      self.controller.tickFrame()
      if self.controller.wantsToQuit {
        NSApp.terminate(nil)
      }
      self.needsDisplay = true
    }
  }

  deinit {
    timer?.invalidate()
  }

  // MARK: - Drawing

  override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    // The game thinks in a fixed 800x600 space; scale it onto whatever size the
    // window actually is.
    context.saveGState()
    context.scaleBy(
      x: bounds.width / CGFloat(Level.canvasWidth),
      y: bounds.height / CGFloat(Level.canvasHeight))

    let g = Graphics(context: context, logicalHeight: CGFloat(Level.canvasHeight))
    controller.draw(g)

    context.restoreGState()
  }

  // MARK: - Coordinates

  /// Converts an event location into game coordinates: origin top-left, y down.
  private func gamePoint(_ event: NSEvent) -> (x: Int, y: Int) {
    let point = convert(event.locationInWindow, from: nil)
    let scaleX = bounds.width / CGFloat(Level.canvasWidth)
    let scaleY = bounds.height / CGFloat(Level.canvasHeight)
    return (Int(point.x / scaleX), Int((bounds.height - point.y) / scaleY))
  }

  // MARK: - Mouse

  override func mouseDown(with event: NSEvent) {
    let point = gamePoint(event)
    controller.mouseDown(x: point.x, y: point.y)
    needsDisplay = true
  }

  override func rightMouseDown(with event: NSEvent) {
    let point = gamePoint(event)
    controller.rightMouseDown(x: point.x, y: point.y)
    needsDisplay = true
  }

  override func rightMouseUp(with event: NSEvent) {
    let point = gamePoint(event)
    controller.rightMouseUp(x: point.x, y: point.y)
    needsDisplay = true
  }

  override func rightMouseDragged(with event: NSEvent) {
    // Keep aiming while the focus button is held.
    mouseMoved(with: event)
  }

  override func mouseUp(with event: NSEvent) {
    let point = gamePoint(event)
    controller.mouseUp(x: point.x, y: point.y)
    needsDisplay = true
  }

  override func mouseMoved(with event: NSEvent) {
    let point = gamePoint(event)
    controller.mouseMoved(x: point.x, y: point.y)
  }

  override func mouseDragged(with event: NSEvent) {
    mouseMoved(with: event)
  }

  override func scrollWheel(with event: NSEvent) {
    // One notch per event, matching AWT's integer wheel rotation rather than
    // macOS's continuous pixel deltas.
    guard event.scrollingDeltaY != 0 else { return }
    let delta = event.scrollingDeltaY > 0 ? -1 : 1
    controller.scrollWheel(delta: delta, shift: event.modifierFlags.contains(.shift))
    needsDisplay = true
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingArea { removeTrackingArea(trackingArea) }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
      owner: self)
    addTrackingArea(area)
    trackingArea = area
  }

  // MARK: - Keyboard

  override func keyDown(with event: NSEvent) {
    guard
      let characters = event.charactersIgnoringModifiers,
      let scalar = characters.unicodeScalars.first
    else { return }

    let key = GameView.key(for: Int(scalar.value))
    controller.keyDown(key, shift: event.modifierFlags.contains(.shift))
    needsDisplay = true
  }

  override func keyUp(with event: NSEvent) {
    guard
      let characters = event.charactersIgnoringModifiers,
      let scalar = characters.unicodeScalars.first
    else { return }
    controller.keyUp(GameView.key(for: Int(scalar.value)))
    needsDisplay = true
  }

  /// Maps a key code to the game's own key vocabulary.
  private static func key(for code: Int) -> GameKey {
    switch code {
    case NSUpArrowFunctionKey: return .up
    case NSDownArrowFunctionKey: return .down
    case NSLeftArrowFunctionKey: return .left
    case NSRightArrowFunctionKey: return .right
    case NSF1FunctionKey: return .f1
    case NSF2FunctionKey: return .f2
    case 0x1B: return .escape
    case 0x0D, 0x03: return .enter
    case 0x7F, 0x08: return .backspace
    default:
      guard let scalar = Unicode.Scalar(UInt32(code)) else { return .other }
      return .char(Character(scalar))
    }
  }
}
