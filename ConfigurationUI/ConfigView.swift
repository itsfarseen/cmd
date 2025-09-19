import SwiftUI

struct KeybindingData: Identifiable {
  let id = UUID()
  let key: String
  let displayKey: String
  let assignedAppName: String?
  let assignedAppIcon: NSImage?
}

struct KeybindingRowView: View {
  let keybinding: KeybindingData
  let onAssign: () -> Void
  let onUnassign: () -> Void
  let useCmdModifier: Bool
  let useOptionModifier: Bool
  let useShiftModifier: Bool

  private var modifierText: String {
    var text = ""
    if useCmdModifier { text += "⌘" }
    if useOptionModifier { text += "⌥" }
    if useShiftModifier { text += "⇧" }
    return text.isEmpty ? "⌘" : text
  }

  var body: some View {
    HStack(spacing: 16) {
      // Keyboard shortcut display
      HStack(spacing: 2) {
        Text(modifierText)
          .font(.system(size: 18, weight: .medium))
        Text(keybinding.displayKey)
          .font(.system(size: 18, weight: .medium))
      }
      .frame(width: 80, alignment: .leading)
      .foregroundColor(.primary)

      // Assigned app or assign button
      if let appName = keybinding.assignedAppName {
        HStack(spacing: 12) {
          if let icon = keybinding.assignedAppIcon {
            Image(nsImage: icon)
              .resizable()
              .frame(width: 32, height: 32)
          } else {
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.gray.opacity(0.3))
              .frame(width: 32, height: 32)
          }

          Text(appName)
            .frame(maxWidth: .infinity, alignment: .leading)

          Button("Remove") {
            onUnassign()
          }
          .buttonStyle(BorderlessButtonStyle())
          .foregroundColor(.red)
        }
        .frame(height: 48)
      } else {
        HStack(spacing: 12) {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.clear)
            .frame(width: 32, height: 32)

          Spacer()

          Button("Assign") {
            onAssign()
          }
          .buttonStyle(BorderlessButtonStyle())
          .foregroundColor(.blue)
        }
        .frame(height: 48)
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(8)
  }
}

struct ConfigView: View {
  @ObservedObject var hotkeyHandler: HotkeyHandler
  @State private var keybindings: [KeybindingData] = []
  @State private var runningApps: [AvailableApp] = []
  @State private var installedApps: [AvailableApp] = []
  @State private var showingAssignmentModal = false
  @State private var selectedKey: String?
  @State private var selectedTab = 0
  let onDismiss: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      Text("App Switcher Configuration")
        .font(.title)
        .fontWeight(.medium)

      // Tab picker
      Picker("", selection: $selectedTab) {
        Text("Apps").tag(0)
        Text("Settings").tag(1)
      }
      .pickerStyle(SegmentedPickerStyle())
      .frame(width: 200)

      // Tab content
      if selectedTab == 0 {
        AppsTabView(
          keybindings: keybindings,
          useCmdModifier: hotkeyHandler.useCmdModifier,
          useOptionModifier: hotkeyHandler.useOptionModifier,
          useShiftModifier: hotkeyHandler.useShiftModifier,
          onAssign: { key in
            selectedKey = key
            showingAssignmentModal = true
          },
          onUnassign: { key in
            hotkeyHandler.removeKeyBinding(key: key)
            hotkeyHandler.saveConfiguration()
            updateKeybindings()
          }
        )
      } else {
        SettingsTabView(
          useCmdModifier: $hotkeyHandler.useCmdModifier,
          useOptionModifier: $hotkeyHandler.useOptionModifier,
          useShiftModifier: $hotkeyHandler.useShiftModifier,
          configHotkeyKey: $hotkeyHandler.configHotkeyKey,
          configHotkeyUseCmdModifier: $hotkeyHandler.configHotkeyUseCmdModifier,
          configHotkeyUseOptionModifier: $hotkeyHandler.configHotkeyUseOptionModifier,
          configHotkeyUseShiftModifier: $hotkeyHandler.configHotkeyUseShiftModifier,
          onSettingsChanged: {
            hotkeyHandler.saveConfiguration()
          }
        )
      }

      HStack {
        Spacer()
        Button("Done") {
          onDismiss()
        }
        .buttonStyle(DefaultButtonStyle())
      }
      .padding(.top)
    }
    .padding()
    .frame(width: 650, height: 550)
    .onAppear {
      loadData()
    }
    .sheet(isPresented: $showingAssignmentModal) {
      AppAssignmentModal(
        runningApps: runningApps,
        installedApps: installedApps,
        onSelectApp: { appName in
          if let key = selectedKey {
            hotkeyHandler.setKeyBinding(key: key, appName: appName)
            hotkeyHandler.saveConfiguration()
            updateKeybindings()
          }
          showingAssignmentModal = false
          selectedKey = nil
        },
        onCancel: {
          showingAssignmentModal = false
          selectedKey = nil
        },
        onRefreshRunning: {
          loadRunningApps()
        },
        onRefreshInstalled: {
          loadInstalledApps()
        }
      )
    }
  }

  private func loadData() {
    loadRunningApps()
    loadInstalledApps()
    updateKeybindings()
  }

  private func updateKeybindings() {
    let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

    keybindings = keys.map { key in
      let assignedAppName = getAppNameForKey(key)
      var assignedAppIcon: NSImage?

      if let appName = assignedAppName {
        assignedAppIcon = getAppIcon(for: appName)
      }

      return KeybindingData(
        key: key,
        displayKey: key,
        assignedAppName: assignedAppName,
        assignedAppIcon: assignedAppIcon
      )
    }
  }

  private func loadRunningApps() {
    let workspace = NSWorkspace.shared
    let runningApplications = workspace.runningApplications

    runningApps = runningApplications.compactMap { app in
      guard app.activationPolicy == .regular else { return nil }

      let appName = app.localizedName ?? "Unknown App"
      var appIcon = app.icon

      if appIcon == nil, let bundleURL = app.bundleURL {
        appIcon = workspace.icon(forFile: bundleURL.path)
      }

      appIcon?.size = NSSize(width: 32, height: 32)

      return AvailableApp(name: appName, icon: appIcon, bundleURL: app.bundleURL)
    }
    .sorted { $0.name < $1.name }
  }

  private func loadInstalledApps() {
    AppDiscovery.shared.refresh()
    installedApps = AppDiscovery.shared.getInstalledApps()
  }

  private func getAppNameForKey(_ key: String) -> String? {
    return hotkeyHandler.keyAppBindings[key]
  }

  private func getAppIcon(for appName: String) -> NSImage? {
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications

    // First, try to find the app in running applications
    for app in runningApps {
      if app.localizedName == appName {
        var appIcon = app.icon
        if appIcon == nil, let bundleURL = app.bundleURL {
          appIcon = workspace.icon(forFile: bundleURL.path)
        }
        appIcon?.size = NSSize(width: 32, height: 32)
        return appIcon
      }
    }

    // If not found in running apps, search installed apps using AppDiscovery
    return AppDiscovery.shared.findAppIcon(for: appName)
  }

}
