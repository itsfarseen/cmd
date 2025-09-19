import SwiftUI

struct KeybindingData: Identifiable {
  let id = UUID()
  let key: String
  let displayKey: String
  let assignedAppName: String?
  let assignedAppIcon: NSImage?
}

struct AvailableApp: Identifiable {
  let id = UUID()
  let name: String
  let icon: NSImage?
  let bundleURL: URL?
}

class AppDiscovery {
  static let shared = AppDiscovery()

  private let applicationPaths = [
    "/Applications",
    "/System/Applications",
    "\(NSHomeDirectory())/Applications",
  ]

  private let workspace = NSWorkspace.shared
  private var appNameToAppMapping: [String: AvailableApp] = [:]

  private init() {}

  func refresh() {
    var apps: [String: AvailableApp] = [:]

    for appDir in applicationPaths {
      guard
        let enumerator = FileManager.default.enumerator(
          at: URL(fileURLWithPath: appDir),
          includingPropertiesForKeys: [.isApplicationKey],
          options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
      else { continue }

      for case let fileURL as URL in enumerator {
        guard fileURL.pathExtension == "app" else { continue }

        let appName = fileURL.deletingPathExtension().lastPathComponent
        let appIcon = workspace.icon(forFile: fileURL.path)
        appIcon.size = NSSize(width: 32, height: 32)

        apps[appName] = AvailableApp(name: appName, icon: appIcon, bundleURL: fileURL)
      }
    }

    appNameToAppMapping = apps
  }

  func getInstalledApps() -> [AvailableApp] {
    if appNameToAppMapping.isEmpty {
      refresh()
    }

    return Array(appNameToAppMapping.values).sorted { $0.name < $1.name }
  }

  func findAppIcon(for appName: String) -> NSImage? {
    if appNameToAppMapping.isEmpty {
      refresh()
    }

    return appNameToAppMapping[appName]?.icon
  }

  func findAppBundleURL(for appName: String) -> URL? {
    if appNameToAppMapping.isEmpty {
      refresh()
    }

    return appNameToAppMapping[appName]?.bundleURL
  }
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

struct AppAssignmentModal: View {
  let runningApps: [AvailableApp]
  let installedApps: [AvailableApp]
  let onSelectApp: (String) -> Void
  let onCancel: () -> Void
  let onRefreshRunning: () -> Void
  let onRefreshInstalled: () -> Void

  @State private var selectedTab = 0
  @State private var isRefreshing = false

  var body: some View {
    VStack(spacing: 16) {
      Text("Select App")
        .font(.headline)

      // Tab picker
      Picker("", selection: $selectedTab) {
        Text("Running").tag(0)
        Text("Installed").tag(1)
      }
      .pickerStyle(SegmentedPickerStyle())
      .frame(width: 200)

      // Refresh button
      HStack {
        Spacer()
        Button(action: {
          isRefreshing = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if selectedTab == 0 {
              onRefreshRunning()
            } else {
              onRefreshInstalled()
            }
            isRefreshing = false
          }
        }) {
          HStack(spacing: 4) {
            Image(systemName: "arrow.clockwise")
              .rotationEffect(.degrees(isRefreshing ? 360 : 0))
              .animation(.easeInOut(duration: 0.5), value: isRefreshing)
            Text("Refresh")
          }
        }
        .buttonStyle(BorderlessButtonStyle())
        .foregroundColor(isRefreshing ? .gray : .blue)
        .disabled(isRefreshing)
      }
      .padding(.horizontal)

      ScrollView {
        VStack(spacing: 4) {
          let appsToShow = selectedTab == 0 ? runningApps : installedApps
          ForEach(appsToShow) { app in
            Button(action: {
              onSelectApp(app.name)
            }) {
              HStack(spacing: 12) {
                if let icon = app.icon {
                  Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                } else {
                  RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                }

                Text(app.name)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .foregroundColor(.primary)
              }
              .padding(.vertical, 8)
              .padding(.horizontal, 12)
              .background(Color(NSColor.controlBackgroundColor))
              .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
      }
      .frame(maxHeight: 300)

      Button("Cancel") {
        onCancel()
      }
    }
    .padding()
    .frame(width: 450, height: 450)
  }
}

struct ConfigView: View {
  @ObservedObject var hotkeyHandler: HotkeyHandler
  @State private var keybindings: [KeybindingData] = []
  @State private var localKeyAppBindings: [String: String] = [:]
  @State private var runningApps: [AvailableApp] = []
  @State private var installedApps: [AvailableApp] = []
  @State private var showingAssignmentModal = false
  @State private var selectedKey: String?
  @State private var selectedTab = 0
  @State private var useCmdModifier = true
  @State private var useOptionModifier = false
  @State private var useShiftModifier = false
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
        appsTabContent
      } else {
        settingsTabContent
      }

      HStack(spacing: 12) {
        Button("Cancel") {
          onDismiss()
        }

        Button("Save") {
          // Apply local changes to the hotkey handler
          for (key, _) in hotkeyHandler.keyAppBindings {
            hotkeyHandler.removeKeyBinding(key: key)
          }
          for (key, appName) in localKeyAppBindings {
            hotkeyHandler.setKeyBinding(key: key, appName: appName)
          }
          // Apply modifier settings
          hotkeyHandler.useCmdModifier = useCmdModifier
          hotkeyHandler.useOptionModifier = useOptionModifier
          hotkeyHandler.useShiftModifier = useShiftModifier
          hotkeyHandler.saveKeybindings()
          onDismiss()
        }
        .buttonStyle(DefaultButtonStyle())
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(6)
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
            localKeyAppBindings[key] = appName
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

  private var appsTabContent: some View {
    VStack(spacing: 16) {
      Text("Assign apps to keyboard shortcuts")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      ScrollView {
        VStack(spacing: 8) {
          ForEach(keybindings) { keybinding in
            KeybindingRowView(
              keybinding: keybinding,
              onAssign: {
                selectedKey = keybinding.key
                showingAssignmentModal = true
              },
              onUnassign: {
                localKeyAppBindings.removeValue(forKey: keybinding.key)
                updateKeybindings()
              },
              useCmdModifier: useCmdModifier,
              useOptionModifier: useOptionModifier,
              useShiftModifier: useShiftModifier
            )
          }
        }
        .padding(.horizontal)
      }
      .frame(maxHeight: 400)
    }
  }

  private var settingsTabContent: some View {
    VStack(spacing: 20) {
      Text("Modifier Keys")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      VStack(spacing: 12) {
        HStack {
          Toggle("Command (⌘)", isOn: $useCmdModifier)
          Spacer()
        }

        HStack {
          Toggle("Option (⌥)", isOn: $useOptionModifier)
          Spacer()
        }

        HStack {
          Toggle("Shift (⇧)", isOn: $useShiftModifier)
          Spacer()
        }
      }
      .padding(.leading, 20)

      Spacer()
    }
    .frame(maxHeight: 400)
  }

  private func loadData() {
    localKeyAppBindings = hotkeyHandler.keyAppBindings
    useCmdModifier = hotkeyHandler.useCmdModifier
    useOptionModifier = hotkeyHandler.useOptionModifier
    useShiftModifier = hotkeyHandler.useShiftModifier
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
    return localKeyAppBindings[key]
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
