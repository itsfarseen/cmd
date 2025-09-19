import Cocoa

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
