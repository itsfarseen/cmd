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
}

@available(macOS 10.15, *)
struct KeybindingRowView: View {
  let keybinding: KeybindingData
  let onAssign: () -> Void
  let onUnassign: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      // Keyboard shortcut display
      HStack(spacing: 2) {
        Text("⌘")
          .font(.system(size: 18, weight: .medium))
        Text(keybinding.displayKey)
          .font(.system(size: 18, weight: .medium))
      }
      .frame(width: 60, alignment: .leading)
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
      } else {
        Button("Assign App...") {
          onAssign()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(8)
  }
}

@available(macOS 10.15, *)
struct AppAssignmentModal: View {
  let runningApps: [AvailableApp]
  let installedApps: [AvailableApp]
  let onSelectApp: (String) -> Void
  let onCancel: () -> Void

  @State private var selectedTab = 0

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

@available(macOS 10.15, *)
struct ConfigView: View {
  @ObservedObject var hotkeyHandler: HotkeyHandler
  @State private var keybindings: [KeybindingData] = []
  @State private var runningApps: [AvailableApp] = []
  @State private var installedApps: [AvailableApp] = []
  @State private var showingAssignmentModal = false
  @State private var selectedKey: String?
  let onDismiss: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      Text("App Switcher Configuration")
        .font(.title)
        .fontWeight(.medium)

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
                hotkeyHandler.removeKeyBinding(key: keybinding.key)
                updateKeybindings()
              }
            )
          }
        }
        .padding(.horizontal)
      }
      .frame(maxHeight: 400)

      HStack(spacing: 12) {
        Button("Cancel") {
          onDismiss()
        }

        Button("Save") {
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
            hotkeyHandler.setKeyBinding(key: key, appName: appName)
            updateKeybindings()
          }
          showingAssignmentModal = false
          selectedKey = nil
        },
        onCancel: {
          showingAssignmentModal = false
          selectedKey = nil
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

      return AvailableApp(name: appName, icon: appIcon)
    }
    .sorted { $0.name < $1.name }
  }

  private func loadInstalledApps() {
    let workspace = NSWorkspace.shared
    let applicationURLs = [
      "/Applications",
      "/System/Applications",
      "\(NSHomeDirectory())/Applications",
    ]

    var apps: [AvailableApp] = []

    for appDir in applicationURLs {
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

        apps.append(AvailableApp(name: appName, icon: appIcon))
      }
    }

    installedApps = apps.sorted { $0.name < $1.name }
  }

  private func getAppNameForKey(_ key: String) -> String? {
    return hotkeyHandler.keyAppBindings[key]
  }

  private func getAppIcon(for appName: String) -> NSImage? {
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications

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
    return nil
  }

}
