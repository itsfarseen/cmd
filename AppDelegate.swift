import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  var statusItem: NSStatusItem?
  private var configWindow: NSWindow?
  private(set) var hotkeyHandler: HotkeyHandler?

  override init() {
    super.init()
  }

  deinit {
    hotkeyHandler = nil
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    setupMenuBar()
    hotkeyHandler = HotkeyHandler(appDelegate: self)
    hotkeyHandler?.registerGlobalKeybindings()
  }

  private func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem?.button?.title = "⌘"

    let menu = NSMenu()

    let pauseResumeItem = NSMenuItem(
      title: "Pause",
      action: #selector(togglePauseResume),
      keyEquivalent: ""
    )
    pauseResumeItem.target = self
    menu.addItem(pauseResumeItem)

    menu.addItem(NSMenuItem.separator())

    let configureItem = NSMenuItem(
      title: "Configure...",
      action: #selector(showConfigWindow),
      keyEquivalent: ""
    )
    configureItem.target = self
    menu.addItem(configureItem)

    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(
      title: "Quit",
      action: #selector(quitApp),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem?.menu = menu

    updateMenuItems()
  }

  @objc func showConfigWindow() {
    if configWindow != nil {
      configWindow?.makeKeyAndOrderFront(nil)
      return
    }

    guard let hotkeyHandler = hotkeyHandler else { return }

    let contentView = ConfigView(hotkeyHandler: hotkeyHandler) {
      self.configWindow?.close()
    }
    let hostingController = NSHostingController(rootView: contentView)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 650, height: 550),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "App Switcher Configuration"
    window.contentViewController = hostingController
    window.isReleasedWhenClosed = false
    window.center()

    configWindow = window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification,
      object: window,
      queue: .main
    ) { _ in
      self.configWindow = nil
    }
  }

  func switchToApp(named appName: String) -> Bool {
    let workspace = NSWorkspace.shared
    let apps = workspace.runningApplications

    // First, check if the app is already running
    for app in apps {
      if app.localizedName == appName {
        // App is running, just switch to it (don't fullscreen)
        if let bundleURL = app.bundleURL {
          workspace.openApplication(
            at: bundleURL, configuration: NSWorkspace.OpenConfiguration()
          ) { _, _ in }
          return true
        }
      }
    }

    // App is not running, launch it normally
    return launchApp(named: appName)
  }

  private func launchApp(named appName: String) -> Bool {
    let workspace = NSWorkspace.shared

    // Use AppDiscovery to find the bundle URL
    guard let bundleURL = AppDiscovery.shared.findAppBundleURL(for: appName) else {
      return false
    }

    // Launch the app normally
    let configuration = NSWorkspace.OpenConfiguration()
    workspace.openApplication(at: bundleURL, configuration: configuration) { _, _ in }
    return true
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  @objc private func togglePauseResume() {
    hotkeyHandler?.togglePause()
    updateMenuItems()
  }

  @objc private func quitApp() {
    NSApplication.shared.terminate(nil)
  }

  private func updateMenuItems() {
    guard let menu = statusItem?.menu,
      let pauseResumeItem = menu.items.first,
      let hotkeyHandler = hotkeyHandler
    else { return }

    pauseResumeItem.title = hotkeyHandler.isPaused ? "Resume" : "Pause"
    statusItem?.button?.title = hotkeyHandler.isPaused ? "⏸" : "⌘"
  }
}
