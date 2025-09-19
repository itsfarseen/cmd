import SwiftUI

@available(macOS 10.15, *)
struct AppRowView: View {
    let app: AppData
    @State private var keyBinding: String
    let onKeyBindingChange: (String, String) -> Void

    init(app: AppData, onKeyBindingChange: @escaping (String, String) -> Void) {
        self.app = app
        self.onKeyBindingChange = onKeyBindingChange
        self._keyBinding = State(initialValue: app.keyBinding)
    }

    var body: some View {
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

            TextField("0-9", text: $keyBinding)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 50)
                .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidChangeNotification)) { _ in
                    let filtered = String(keyBinding.filter { $0.isNumber }.prefix(1))
                    if filtered != keyBinding {
                        keyBinding = filtered
                    }
                    onKeyBindingChange(app.name, filtered)
                }
        }
        .padding(.vertical, 4)
    }
}

struct AppData: Identifiable {
    let id = UUID()
    let name: String
    let pid: pid_t
    let icon: NSImage?
    let keyBinding: String
}

@available(macOS 10.15, *)
struct ConfigView: View {
    @ObservedObject var hotkeyHandler: HotkeyHandler
    @State private var apps: [AppData] = []
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("App Switcher Configuration")
                .font(.title)
                .fontWeight(.medium)

            Text("Assign number keys (0-9) to quickly switch between apps using Cmd+[number]")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(apps) { app in
                        AppRowView(app: app) { appName, key in
                            hotkeyHandler.updateKeybinding(for: appName, key: key)
                        }
                        .padding(.horizontal)
                    }
                }
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
        .frame(width: 600, height: 500)
        .onAppear {
            loadApps()
        }
    }

    private func loadApps() {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        apps = runningApps.compactMap { app in
            guard app.activationPolicy == .regular else { return nil }

            let appName = app.localizedName ?? "Unknown App"
            var appIcon = app.icon

            if appIcon == nil, let bundleURL = app.bundleURL {
                appIcon = workspace.icon(forFile: bundleURL.path)
            }

            appIcon?.size = NSSize(width: 32, height: 32)

            return AppData(
                name: appName,
                pid: app.processIdentifier,
                icon: appIcon,
                keyBinding: hotkeyHandler.appKeybindings[appName] ?? ""
            )
        }
        .sorted { $0.name < $1.name }
    }
}