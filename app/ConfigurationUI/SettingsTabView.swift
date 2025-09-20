import SwiftUI

private enum Constants {
  static let sectionSpacing: CGFloat = 16
  static let contentSpacing: CGFloat = 16
  static let toggleSpacing: CGFloat = 20
  static let contentLeadingPadding: CGFloat = 8
  static let accessibilitySpacing: CGFloat = 12
  static let errorSpacing: CGFloat = 8
  static let delayTime: Double = 0.5
}

struct SettingsTabView: View {
  @Binding var globalHotkey: Hotkey
  @Binding var configHotkey: Hotkey
  @Binding var appSwitcherHotkey: Hotkey
  @Binding var enableLinuxWordMovementMapping: Bool
  @Binding var enableChromeOSWorkspaceSwitching: Bool
  let onSettingsChanged: () -> Void

  @State private var hasAccessibilityPermission = false
  @State private var loginItemEnabled = false
  @State private var loginItemValidation = LoginItemManager.ValidationResult.valid
  private let accessibilityManager = AccessibilityManager.shared
  private let loginItemManager = LoginItemManager.shared

  var body: some View {
    VStack(spacing: Constants.sectionSpacing) {
      VStack(spacing: Constants.contentSpacing) {
        Text("App Switching Modifier Keys")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: Constants.toggleSpacing) {
          Toggle("Command (⌘)", isOn: Binding(
            get: { globalHotkey.cmd },
            set: { globalHotkey = Hotkey(key: globalHotkey.key, cmd: $0, opt: globalHotkey.opt, ctrl: globalHotkey.ctrl, shift: globalHotkey.shift); onSettingsChanged() }
          ))
          Toggle("Option (⌥)", isOn: Binding(
            get: { globalHotkey.opt },
            set: { globalHotkey = Hotkey(key: globalHotkey.key, cmd: globalHotkey.cmd, opt: $0, ctrl: globalHotkey.ctrl, shift: globalHotkey.shift); onSettingsChanged() }
          ))
          Toggle("Control (⌃)", isOn: Binding(
            get: { globalHotkey.ctrl },
            set: { globalHotkey = Hotkey(key: globalHotkey.key, cmd: globalHotkey.cmd, opt: globalHotkey.opt, ctrl: $0, shift: globalHotkey.shift); onSettingsChanged() }
          ))
          Toggle("Shift (⇧)", isOn: Binding(
            get: { globalHotkey.shift },
            set: { globalHotkey = Hotkey(key: globalHotkey.key, cmd: globalHotkey.cmd, opt: globalHotkey.opt, ctrl: globalHotkey.ctrl, shift: $0); onSettingsChanged() }
          ))
          Spacer()
        }
        .padding(.leading, Constants.contentLeadingPadding)
      }

      Divider()

      VStack(spacing: Constants.contentSpacing) {
        Text("Quick Config Access")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack {
          KeybindingCaptureView(hotkey: $configHotkey)
          .onChange(of: configHotkey) { _ in onSettingsChanged() }
          Spacer()
        }
        .padding(.leading, Constants.contentLeadingPadding)
      }

      Divider()

      VStack(spacing: Constants.contentSpacing) {
        Text("App Back and Forth")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack {
          KeybindingCaptureView(hotkey: $appSwitcherHotkey)
          .onChange(of: appSwitcherHotkey) { _ in onSettingsChanged() }
          Spacer()
        }
        .padding(.leading, Constants.contentLeadingPadding)

        HStack {
          Text("Toggle between two most recently used apps (i3's \"workspace back and forth\")")
            .font(.caption)
            .foregroundColor(.secondary)
          Spacer()
        }
        .padding(.leading, Constants.contentLeadingPadding)
      }

      Divider()

      VStack(spacing: Constants.contentSpacing) {
        Text("Startup")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack {
          Toggle("Start at login", isOn: $loginItemEnabled)
            .disabled(!isLoginItemToggleEnabled)
            .onChange(of: loginItemEnabled) { newValue in
              handleLoginItemToggle(newValue)
            }
          Spacer()
        }
        .padding(.leading, Constants.contentLeadingPadding)

        if case .invalidLocation(let message) = loginItemValidation {
          HStack {
            Text(message)
              .font(.caption)
              .foregroundColor(.orange)
            Spacer()
          }
          .padding(.leading, Constants.contentLeadingPadding)
        }

        if case .duplicateInstallation(let message) = loginItemValidation {
          HStack {
            Text("⚠️ \(message)")
              .font(.caption)
              .foregroundColor(.red)
            Spacer()
          }
          .padding(.leading, Constants.contentLeadingPadding)
        }
      }

      Divider()

      VStack(spacing: Constants.contentSpacing) {
        Text("Other goodies")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: Constants.accessibilitySpacing) {
          // Accessibility permission status
          HStack {
            Image(
              systemName: hasAccessibilityPermission
                ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .foregroundColor(hasAccessibilityPermission ? .green : .orange)

            Text(
              hasAccessibilityPermission
                ? "Accessibility permission granted" : "Accessibility permission required"
            )
            .font(.subheadline)

            Spacer()

            if !hasAccessibilityPermission {
              Button("Grant Permission") {
                requestAccessibilityPermission()
              }
              .buttonStyle(BorderlessButtonStyle())
              .foregroundColor(.blue)
            }
          }

          if !hasAccessibilityPermission {
            Text("Some features below require accessibility permission to function properly.")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Divider()

          // Linux word movement mapping
          VStack(alignment: .leading, spacing: Constants.errorSpacing) {
            Toggle("Enable Linux-style word movement", isOn: $enableLinuxWordMovementMapping)
              .disabled(!hasAccessibilityPermission)
              .onChange(of: enableLinuxWordMovementMapping) { _ in onSettingsChanged() }

            Text("Maps Ctrl+Left/Right to Option+Left/Right (includes Shift combinations)")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Divider()

          // ChromeOS workspace switching
          VStack(alignment: .leading, spacing: Constants.errorSpacing) {
            Toggle("Enable ChromeOS workspace switching", isOn: $enableChromeOSWorkspaceSwitching)
              .disabled(!hasAccessibilityPermission)
              .onChange(of: enableChromeOSWorkspaceSwitching) { _ in onSettingsChanged() }

            Text("Maps Cmd+[/] to Ctrl+Left/Right for workspace switching")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .padding(.leading, Constants.contentLeadingPadding)
      }

      Spacer()
    }
    .onAppear {
      checkAccessibilityPermission()
      checkLoginItemStatus()
    }
  }

  private func checkAccessibilityPermission() {
    hasAccessibilityPermission = accessibilityManager.hasAccessibilityPermission()
  }

  private func requestAccessibilityPermission() {
    _ = accessibilityManager.requestAccessibilityPermission()
    // Check again after a short delay to update UI
    DispatchQueue.main.asyncAfter(deadline: .now() + Constants.delayTime) {
      checkAccessibilityPermission()
    }
  }

  private func checkLoginItemStatus() {
    loginItemValidation = loginItemManager.validateInstallationForLoginItem()
    loginItemEnabled = loginItemManager.isLoginItemEnabled()
  }

  private var isLoginItemToggleEnabled: Bool {
    switch loginItemValidation {
    case .valid:
      return true
    case .invalidLocation, .duplicateInstallation:
      return false
    }
  }

  private func handleLoginItemToggle(_ enabled: Bool) {
    let success = loginItemManager.setLoginItemEnabled(enabled)
    if !success {
      // Revert the toggle if it failed
      loginItemEnabled = loginItemManager.isLoginItemEnabled()
    }
  }
}
