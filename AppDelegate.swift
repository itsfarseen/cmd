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

    @objc private func showConfigWindow() {
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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
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

        for app in apps {
            if app.localizedName == appName {
                return app.activate(options: .activateAllWindows)
            }
        }

        return false
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

