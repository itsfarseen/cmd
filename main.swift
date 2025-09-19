import ApplicationServices
import Carbon
import Cocoa

struct AppInfo {
    let name: String
    let pid: pid_t
    let keyInput: NSTextField
}

class HotkeyHandler {
    private var registeredHotkeys: [EventHotKeyRef] = []
    private weak var appDelegate: AppDelegate?
    private var handlerRef: EventHandlerRef?
    private(set) var appKeybindings: [String: String] = [:]

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        loadKeybindings()
        installEventHandler()
    }

    deinit {
        clearGlobalKeybindings()
        if let handlerRef = handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let handler = Unmanaged<HotkeyHandler>.fromOpaque(userData).takeUnretainedValue()
                return handler.handleHotkey(nextHandler: nextHandler, event: event)
            },
            1,
            &eventType,
            userData,
            &handlerRef
        )
    }

    private func handleHotkey(nextHandler: EventHandlerCallRef?, event: EventRef?) -> OSStatus {
        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        guard status == noErr else { return status }

        let keyNumber = Int(hotkeyID.id - 1000)
        let targetKey = String(keyNumber)

        if let delegate = appDelegate {
            for (appName, keyValue) in appKeybindings {
                if keyValue == targetKey {
                    _ = delegate.switchToApp(named: appName)
                    break
                }
            }
        }

        return noErr
    }

    func registerGlobalKeybindings() {
        clearGlobalKeybindings()

        for (appName, keyValue) in appKeybindings {
            if keyValue.count == 1, let keyChar = keyValue.first, keyChar.isNumber {
                registerKeybinding(for: keyChar, appName: appName)
            }
        }
    }

    func updateKeybinding(for appName: String, key: String) {
        if key.isEmpty {
            appKeybindings.removeValue(forKey: appName)
        } else if key.count == 1 && key.first?.isNumber == true {
            appKeybindings[appName] = key
        }
    }

    func saveKeybindings() {
        let filePath = NSHomeDirectory().appending("/.appswitch_keybindings")
        let dict = NSDictionary(dictionary: appKeybindings)
        dict.write(toFile: filePath, atomically: true)
        registerGlobalKeybindings()
    }

    private func loadKeybindings() {
        let filePath = NSHomeDirectory().appending("/.appswitch_keybindings")
        if let data = NSDictionary(contentsOfFile: filePath) as? [String: String] {
            appKeybindings = data
        }
    }

    private func clearGlobalKeybindings() {
        for hotkey in registeredHotkeys {
            UnregisterEventHotKey(hotkey)
        }
        registeredHotkeys.removeAll()
    }

    private func registerKeybinding(for keyChar: Character, appName: String) {
        let keyCode: UInt32

        switch keyChar {
        case "0": keyCode = UInt32(kVK_ANSI_0)
        case "1": keyCode = UInt32(kVK_ANSI_1)
        case "2": keyCode = UInt32(kVK_ANSI_2)
        case "3": keyCode = UInt32(kVK_ANSI_3)
        case "4": keyCode = UInt32(kVK_ANSI_4)
        case "5": keyCode = UInt32(kVK_ANSI_5)
        case "6": keyCode = UInt32(kVK_ANSI_6)
        case "7": keyCode = UInt32(kVK_ANSI_7)
        case "8": keyCode = UInt32(kVK_ANSI_8)
        case "9": keyCode = UInt32(kVK_ANSI_9)
        default: return
        }

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: fourCharCodeFrom("SWCH"), id: UInt32(1000 + keyChar.wholeNumberValue!))

        let status = RegisterEventHotKey(
            keyCode,
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotkey = hotKeyRef {
            registeredHotkeys.append(hotkey)
        }
    }
}

class AppList {
    private(set) var runningApps: [AppInfo] = []

    func populateAppList(contentView: NSView, hotkeyHandler: HotkeyHandler) {
        runningApps.removeAll()

        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications

        var yOffset: CGFloat = 0

        for app in apps {
            if app.activationPolicy == .regular {
                let appName = app.localizedName ?? "Unknown App"
                var appIcon = app.icon

                if appIcon == nil {
                    if let bundleURL = app.bundleURL {
                        appIcon = workspace.icon(forFile: bundleURL.path)
                    }
                }

                appIcon?.size = NSSize(width: 32, height: 32)

                let appRow = NSView(frame: NSRect(x: 10, y: yOffset, width: 580, height: 40))

                let iconView = NSImageView(frame: NSRect(x: 0, y: 4, width: 32, height: 32))
                iconView.image = appIcon
                appRow.addSubview(iconView)

                let nameLabel = NSTextField(frame: NSRect(x: 40, y: 12, width: 400, height: 16))
                nameLabel.stringValue = appName
                nameLabel.isEditable = false
                nameLabel.isBordered = false
                nameLabel.backgroundColor = .clear
                appRow.addSubview(nameLabel)

                let keyInput = NSTextField(frame: NSRect(x: 450, y: 8, width: 50, height: 24))
                keyInput.placeholderString = "0-9"
                keyInput.stringValue = hotkeyHandler.appKeybindings[appName] ?? ""
                appRow.addSubview(keyInput)

                contentView.addSubview(appRow)

                let appInfo = AppInfo(
                    name: appName,
                    pid: app.processIdentifier,
                    keyInput: keyInput
                )
                runningApps.append(appInfo)

                yOffset += 45
            }
        }

        contentView.frame = NSRect(x: 0, y: 0, width: 580, height: max(yOffset, 300))
    }
}

class ConfigWindow: NSObject, NSWindowDelegate {
    var window: NSWindow?
    let appList = AppList()
    let hotkeyHandler: HotkeyHandler

    init(hotkeyHandler: HotkeyHandler) {
        self.hotkeyHandler = hotkeyHandler
        super.init()
    }

    func openWindow() {
        if self.window != nil { return }
        let frame = NSRect(x: 100, y: 100, width: 600, height: 400)
        let configWindow = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        configWindow.title = "App Switcher Configuration"
        configWindow.delegate = self

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 50, width: 600, height: 300))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentView = NSView()
        scrollView.documentView = contentView
        configWindow.contentView?.addSubview(scrollView)

        let saveButton = NSButton(frame: NSRect(x: 250, y: 10, width: 100, height: 30))
        saveButton.title = "Save"
        saveButton.target = self
        saveButton.action = #selector(saveConfiguration)
        configWindow.contentView?.addSubview(saveButton)

        appList.populateAppList(contentView: contentView, hotkeyHandler: hotkeyHandler)

        // magic incantation to make segfaults go away mac docs sucks
        configWindow.isReleasedWhenClosed = false

        self.window = configWindow

        configWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        self.window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        self.window = nil
    }

    func isOpen() -> Bool {
        return self.window != nil
    }

    var runningApps: [AppInfo] {
        return appList.runningApps
    }

    @objc func saveConfiguration() {
        for appInfo in runningApps {
            let keyValue = appInfo.keyInput.stringValue
            hotkeyHandler.updateKeybinding(for: appInfo.name, key: keyValue)
        }

        hotkeyHandler.saveKeybindings()
        self.closeWindow()
    }
}

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

// Helper function to convert string to FourCharCode
private func fourCharCodeFrom(_ string: String) -> FourCharCode {
    let chars = Array(string.utf8)
    return FourCharCode(chars[0]) << 24 | FourCharCode(chars[1]) << 16 | FourCharCode(chars[2]) << 8
        | FourCharCode(chars[3])
}

// Main application setup
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
