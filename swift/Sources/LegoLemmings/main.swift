import AppKit

/// Sets up the window and the menu bar, and hands control to AppKit.
final class AppDelegate: NSObject, NSApplicationDelegate {

  private var window: NSWindow!
  private var view: GameView!

  func applicationDidFinishLaunching(_ notification: Notification) {
    let logical = NSSize(
      width: CGFloat(Level.canvasWidth), height: CGFloat(Level.canvasHeight))

    // Open as large as fits comfortably on this display. The view scales the
    // fixed 800x600 canvas to whatever size the window is, so this is purely
    // how big the picture gets.
    let available = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1280, height: 800)
    let factor = min(
      available.width * 0.9 / logical.width,
      available.height * 0.9 / logical.height,
      2.5)
    let size = NSSize(
      width: (logical.width * max(factor, 1)).rounded(),
      height: (logical.height * max(factor, 1)).rounded())

    window = NSWindow(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false)
    window.title = "Lego Lemmings!!!"
    // Locked to 4:3 so resizing never stretches the pixels.
    window.contentAspectRatio = logical
    window.contentMinSize = logical

    view = GameView(frame: NSRect(origin: .zero, size: size))
    if startSiege { view.controller.startSiege(wave: siegeWave) }
    if let doomLevel {
      let chooser = LevelChooser()
      let index =
        (0..<chooser.levelCount).first { chooser.levelData($0).file == doomLevel } ?? 0
      view.controller.startDoom(levelIndex: index)
    }
    if let dashLevel {
      let chooser = LevelChooser()
      let index =
        (0..<chooser.levelCount).first { chooser.levelData($0).file == dashLevel } ?? 0
      view.controller.startDash(levelIndex: index)
    }
    window.contentView = view
    window.center()
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(view)

    if let icon = NSImage(contentsOf: Assets.url("lemIcon.png")) {
      NSApp.applicationIconImage = icon
    }

    // Audio comes up only for the windowed app; the headless modes leave it
    // down, so they never open a device or make a noise on a build machine.
    Sound.shared.start()

    view.start()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

/// A one-item menu bar, which is what it takes for Cmd-Q to work in an app that
/// isn't launched from a bundle.
private func makeMenuBar() -> NSMenu {
  let menuBar = NSMenu()
  let appMenuItem = NSMenuItem()
  let appMenu = NSMenu()
  appMenu.addItem(
    withTitle: "About Lego Lemmings", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
    keyEquivalent: "")
  appMenu.addItem(.separator())
  appMenu.addItem(
    withTitle: "Hide Lego Lemmings", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
  appMenu.addItem(.separator())
  appMenu.addItem(
    withTitle: "Quit Lego Lemmings", action: #selector(NSApplication.terminate(_:)),
    keyEquivalent: "q")
  appMenuItem.submenu = appMenu
  menuBar.addItem(appMenuItem)
  return menuBar
}

// Headless modes, for checking the game without a window.
let arguments = Array(CommandLine.arguments.dropFirst())
/// Non-empty when the app should open in LEMMING DASH rather than the menu.
var dashLevel: String?
/// Non-empty when the app should open in DOOMMINGS.
var doomLevel: String?
/// True when the app should open straight into the horde game.
var startSiege = false
/// Wave the horde game should open on.
var siegeWave = 1
switch arguments.first {
case "--smoke": exit(Headless.smoke(arguments: arguments))
case "--screens": exit(Headless.screens(arguments: arguments))
case "--selftest": exit(Headless.selftest(arguments: arguments))
case "--verify": exit(Headless.verify(arguments: arguments))
case "--trace": exit(Headless.trace(arguments: arguments))
case "--cluster": exit(Headless.cluster(arguments: arguments))
case "--lodestone": exit(Headless.lodestone(arguments: arguments))
case "--dash-test": exit(Headless.dash(arguments: arguments))
case "--doom-test": exit(Headless.doom(arguments: arguments))
case "--siege-test": exit(Headless.siege(arguments: arguments))
case "--menu-test": exit(Headless.menu(arguments: arguments))
case "--sound-test": exit(Headless.sound(arguments: arguments))
case "--siege":
  startSiege = true
  siegeWave = arguments.count > 1 ? (Int(arguments[1]) ?? 1) : 1
case "--doom":
  doomLevel = arguments.count > 1 ? arguments[1] : ""
case "--dash":
  // Launch straight into the side-scroller on a named level.
  dashLevel = arguments.count > 1 ? arguments[1] : ""
default: break
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.mainMenu = makeMenuBar()
application.setActivationPolicy(.regular)
application.activate(ignoringOtherApps: true)
application.run()
