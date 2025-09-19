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

struct KeybindingCaptureView: View {
  @Binding var keybinding: String
  @Binding var useCmdModifier: Bool
  @Binding var useOptionModifier: Bool
  @Binding var useShiftModifier: Bool

  @State private var isCapturing = false
  @State private var displayText = ""
  @State private var eventMonitor: Any?

  var body: some View {
    Button(action: {
      startCapturing()
    }) {
      HStack {
        Text(displayText.isEmpty ? "(unset)" : displayText)
          .foregroundColor(isCapturing ? .blue : (displayText.isEmpty ? .secondary : .primary))
          .frame(minWidth: 120, alignment: .leading)

        if isCapturing {
          Text("Press keys...")
            .font(.caption)
            .foregroundColor(.secondary)
        } else if !displayText.isEmpty {
          Button(action: {
            clearKeybinding()
          }) {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.secondary)
              .font(.system(size: 14))
          }
          .buttonStyle(PlainButtonStyle())
          .contentShape(Rectangle())
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(NSColor.controlBackgroundColor))
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(isCapturing ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
      )
      .cornerRadius(6)
    }
    .buttonStyle(PlainButtonStyle())
    .onAppear {
      updateDisplayText()
    }
    .onChange(of: keybinding) { _ in updateDisplayText() }
    .onChange(of: useCmdModifier) { _ in updateDisplayText() }
    .onChange(of: useOptionModifier) { _ in updateDisplayText() }
    .onChange(of: useShiftModifier) { _ in updateDisplayText() }
    .onDisappear {
      stopCapturing()
    }
  }

  private func startCapturing() {
    // Stop any existing capture
    stopCapturing()

    isCapturing = true

    // Create a local event monitor for key events
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
      self.handleKeyEvent(event)
      return nil  // Consume the event
    }

    // Auto-stop capturing after 10 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
      if self.isCapturing {
        self.stopCapturing()
      }
    }
  }

  private func handleKeyEvent(_ event: NSEvent) {
    let keyCode = event.keyCode
    let modifierFlags = event.modifierFlags

    // Skip if it's just a modifier key being pressed
    if isModifierKey(keyCode) {
      return
    }

    // Extract modifiers
    let hasCmd = modifierFlags.contains(.command)
    let hasOption = modifierFlags.contains(.option)
    let hasShift = modifierFlags.contains(.shift)

    // Convert keyCode to character
    if let keyChar = keyCodeToCharacter(keyCode) {
      // Update the bindings
      keybinding = keyChar
      useCmdModifier = hasCmd
      useOptionModifier = hasOption
      useShiftModifier = hasShift

      // Stop capturing
      stopCapturing()
    }
  }

  private func stopCapturing() {
    isCapturing = false
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
      eventMonitor = nil
    }
  }

  private func clearKeybinding() {
    keybinding = ""
    useCmdModifier = false
    useOptionModifier = false
    useShiftModifier = false
  }

  private func isModifierKey(_ keyCode: UInt16) -> Bool {
    // Common modifier key codes
    switch keyCode {
    case 54, 55: return true  // Command keys
    case 58, 61: return true  // Option keys
    case 56, 60: return true  // Shift keys
    case 59, 62: return true  // Control keys
    case 63: return true  // Function key
    default: return false
    }
  }

  private func updateDisplayText() {
    var components: [String] = []

    if useCmdModifier { components.append("⌘") }
    if useOptionModifier { components.append("⌥") }
    if useShiftModifier { components.append("⇧") }

    if !keybinding.isEmpty {
      components.append(keybinding.uppercased())
    }

    displayText = components.joined()
  }

  private func keyCodeToCharacter(_ keyCode: UInt16) -> String? {
    switch keyCode {
    // Letters
    case 0: return "a"
    case 11: return "b"
    case 8: return "c"
    case 2: return "d"
    case 14: return "e"
    case 3: return "f"
    case 5: return "g"
    case 4: return "h"
    case 34: return "i"
    case 38: return "j"
    case 40: return "k"
    case 37: return "l"
    case 46: return "m"
    case 45: return "n"
    case 31: return "o"
    case 35: return "p"
    case 12: return "q"
    case 15: return "r"
    case 1: return "s"
    case 17: return "t"
    case 32: return "u"
    case 9: return "v"
    case 13: return "w"
    case 7: return "x"
    case 16: return "y"
    case 6: return "z"

    // Numbers
    case 29: return "0"
    case 18: return "1"
    case 19: return "2"
    case 20: return "3"
    case 21: return "4"
    case 23: return "5"
    case 22: return "6"
    case 26: return "7"
    case 28: return "8"
    case 25: return "9"

    // Punctuation
    case 43: return ","
    case 47: return "."
    case 41: return ";"
    case 39: return "'"
    case 33: return "["
    case 30: return "]"
    case 42: return "\\"
    case 44: return "/"
    case 50: return "`"
    case 27: return "-"
    case 24: return "="
    case 49: return "space"

    default: return nil
    }
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
  @State private var configHotkeyKey = ","
  @State private var configHotkeyUseCmdModifier = true
  @State private var configHotkeyUseOptionModifier = false
  @State private var configHotkeyUseShiftModifier = false
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
          // Apply config hotkey settings
          hotkeyHandler.configHotkeyKey = configHotkeyKey
          hotkeyHandler.configHotkeyUseCmdModifier = configHotkeyUseCmdModifier
          hotkeyHandler.configHotkeyUseOptionModifier = configHotkeyUseOptionModifier
          hotkeyHandler.configHotkeyUseShiftModifier = configHotkeyUseShiftModifier
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
      VStack(spacing: 16) {
        Text("App Switching Modifier Keys")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 20) {
          Toggle("Command (⌘)", isOn: $useCmdModifier)
          Toggle("Option (⌥)", isOn: $useOptionModifier)
          Toggle("Shift (⇧)", isOn: $useShiftModifier)
          Spacer()
        }
        .padding(.leading, 20)
      }

      Divider()

      VStack(spacing: 16) {
        Text("Quick Config Access")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack {
          KeybindingCaptureView(
            keybinding: $configHotkeyKey,
            useCmdModifier: $configHotkeyUseCmdModifier,
            useOptionModifier: $configHotkeyUseOptionModifier,
            useShiftModifier: $configHotkeyUseShiftModifier
          )
          Spacer()
        }
        .padding(.leading, 20)
      }

      Spacer()
    }
    .frame(maxHeight: 400)
  }

  private func loadData() {
    localKeyAppBindings = hotkeyHandler.keyAppBindings
    useCmdModifier = hotkeyHandler.useCmdModifier
    useOptionModifier = hotkeyHandler.useOptionModifier
    useShiftModifier = hotkeyHandler.useShiftModifier
    configHotkeyKey = hotkeyHandler.configHotkeyKey
    configHotkeyUseCmdModifier = hotkeyHandler.configHotkeyUseCmdModifier
    configHotkeyUseOptionModifier = hotkeyHandler.configHotkeyUseOptionModifier
    configHotkeyUseShiftModifier = hotkeyHandler.configHotkeyUseShiftModifier
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
