import SwiftUI

private enum Constants {
  static let windowWidth: CGFloat = 600
  static let windowHeight: CGFloat = 500
  static let contentHorizontalPadding: CGFloat = 20
  static let iconSize = NSSize(width: 32, height: 32)
}

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

  private var shortcutText: String {
    return modifierText + keybinding.displayKey
  }

  private func handleClick() {
    if keybinding.assignedAppName != nil {
      onUnassign()
    } else {
      onAssign()
    }
  }

  var body: some View {
    AppRowView(
      appName: keybinding.assignedAppName,
      appIcon: keybinding.assignedAppIcon,
      shortcut: shortcutText,
      isAssigned: keybinding.assignedAppName != nil,
      onTap: handleClick
    )
  }
}

struct ConfigView: View {
  @ObservedObject var hotkeyHandler: HotkeyHandler
  @ObservedObject private var configManager = ConfigManager.shared
  @State private var keybindings: [KeybindingData] = []
  @State private var runningApps: [AvailableApp] = []
  @State private var installedApps: [AvailableApp] = []
  @State private var showingAssignmentModal = false
  @State private var selectedKey: String?
  @State private var selectedTab = 0
  let onDismiss: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Header section
      ConfigHeader(selectedTab: $selectedTab)

      // Tab content with shared scroll view
      ScrollView {
        Group {
          if selectedTab == 0 {
            AppsTabView(
              keybindings: keybindings,
              useCmdModifier: configManager.useCmdModifier,
              useOptionModifier: configManager.useOptionModifier,
              useShiftModifier: configManager.useShiftModifier,
              onAssign: { key in
                selectedKey = key
                showingAssignmentModal = true
              },
              onUnassign: { key in
                configManager.removeKeyAppBinding(key: key)
                hotkeyHandler.updateGlobalKeybindings()
                refreshKeybindingDisplay()
              }
            )
          } else {
            SettingsTabView(
              useCmdModifier: $configManager.useCmdModifier,
              useOptionModifier: $configManager.useOptionModifier,
              useShiftModifier: $configManager.useShiftModifier,
              configHotkeyKey: $configManager.configHotkeyKey,
              configHotkeyUseCmdModifier: $configManager.configHotkeyUseCmdModifier,
              configHotkeyUseOptionModifier: $configManager.configHotkeyUseOptionModifier,
              configHotkeyUseShiftModifier: $configManager.configHotkeyUseShiftModifier,
              appSwitcherHotkeyKey: $configManager.appSwitcherHotkeyKey,
              appSwitcherUseCmdModifier: $configManager.appSwitcherUseCmdModifier,
              appSwitcherUseOptionModifier: $configManager.appSwitcherUseOptionModifier,
              appSwitcherUseShiftModifier: $configManager.appSwitcherUseShiftModifier,
              enableLinuxWordMovementMapping: $configManager.enableLinuxWordMovementMapping,
              enableChromeOSWorkspaceSwitching: $configManager.enableChromeOSWorkspaceSwitching,
              onSettingsChanged: {
                hotkeyHandler.updateGlobalKeybindings()
                NotificationCenter.default.post(
                  name: NSNotification.Name("ConfigChanged"), object: nil)
              }
            )
          }
        }
        .padding(.horizontal, Constants.contentHorizontalPadding)
      }

      // Footer
      ConfigFooter(onDismiss: onDismiss)
    }
    .frame(width: Constants.windowWidth, height: Constants.windowHeight)
    .background(Color(NSColor.windowBackgroundColor))
    .onAppear {
      loadData()
    }
    .sheet(isPresented: $showingAssignmentModal) {
      AppAssignmentModal(
        runningApps: runningApps,
        installedApps: installedApps,
        onSelectApp: { appName in
          if let key = selectedKey {
            configManager.setKeyAppBinding(key: key, appName: appName)
            hotkeyHandler.updateGlobalKeybindings()
            refreshKeybindingDisplay()
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
    refreshKeybindingDisplay()
  }

  private func refreshKeybindingDisplay() {
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
    return configManager.keyAppBindings[key]
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
        appIcon?.size = Constants.iconSize
        return appIcon
      }
    }

    // If not found in running apps, search installed apps using AppDiscovery
    return AppDiscovery.shared.findAppIcon(for: appName)
  }

}
