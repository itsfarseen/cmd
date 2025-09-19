import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var configWindowHandler: ConfigWindow!
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
        configWindowHandler = ConfigWindow(hotkeyHandler: hotkeyHandler!)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.title = "⌘"
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(showConfigWindow)
    }

    @objc private func showConfigWindow() {
        configWindowHandler.openWindow()
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
}