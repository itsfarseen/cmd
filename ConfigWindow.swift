import Cocoa

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
