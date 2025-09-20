import SwiftUI

struct SettingsTabView: View {
  @Binding var useCmdModifier: Bool
  @Binding var useOptionModifier: Bool
  @Binding var useShiftModifier: Bool
  @Binding var configHotkeyKey: String
  @Binding var configHotkeyUseCmdModifier: Bool
  @Binding var configHotkeyUseOptionModifier: Bool
  @Binding var configHotkeyUseShiftModifier: Bool
  @Binding var enableLinuxWordMovementMapping: Bool
  @Binding var enableChromeOSWorkspaceSwitching: Bool
  let onSettingsChanged: () -> Void

  @State private var hasAccessibilityPermission = false
  @State private var loginItemEnabled = false
  @State private var loginItemValidation = LoginItemManager.ValidationResult.valid
  private let accessibilityManager = AccessibilityManager.shared
  private let loginItemManager = LoginItemManager.shared

  var body: some View {
    VStack(spacing: 16) {
      VStack(spacing: 16) {
        Text("App Switching Modifier Keys")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 20) {
          Toggle("Command (⌘)", isOn: $useCmdModifier)
            .onChange(of: useCmdModifier) { _ in onSettingsChanged() }
          Toggle("Option (⌥)", isOn: $useOptionModifier)
            .onChange(of: useOptionModifier) { _ in onSettingsChanged() }
          Toggle("Shift (⇧)", isOn: $useShiftModifier)
            .onChange(of: useShiftModifier) { _ in onSettingsChanged() }
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
          .onChange(of: configHotkeyKey) { _ in onSettingsChanged() }
          .onChange(of: configHotkeyUseCmdModifier) { _ in onSettingsChanged() }
          .onChange(of: configHotkeyUseOptionModifier) { _ in onSettingsChanged() }
          .onChange(of: configHotkeyUseShiftModifier) { _ in onSettingsChanged() }
          Spacer()
        }
        .padding(.leading, 20)
      }

      Divider()

      VStack(spacing: 16) {
        Text("Startup")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: 8) {
          Toggle("Start at login", isOn: $loginItemEnabled)
            .disabled(!isLoginItemToggleEnabled)
            .onChange(of: loginItemEnabled) { newValue in
              handleLoginItemToggle(newValue)
            }

          if case .invalidLocation(let message) = loginItemValidation {
            Text(message)
              .font(.caption)
              .foregroundColor(.orange)
          }

          if case .duplicateInstallation(let message) = loginItemValidation {
            Text("⚠️ \(message)")
              .font(.caption)
              .foregroundColor(.red)
          }
        }
        .padding(.leading, 20)
      }

      Divider()

      VStack(spacing: 16) {
        Text("Accessibility Features")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: 12) {
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
          VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable Linux-style word movement", isOn: $enableLinuxWordMovementMapping)
              .disabled(!hasAccessibilityPermission)
              .onChange(of: enableLinuxWordMovementMapping) { _ in onSettingsChanged() }

            Text("Maps Ctrl+Left/Right to Option+Left/Right (includes Shift combinations)")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Divider()

          // ChromeOS workspace switching
          VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable ChromeOS workspace switching", isOn: $enableChromeOSWorkspaceSwitching)
              .disabled(!hasAccessibilityPermission)
              .onChange(of: enableChromeOSWorkspaceSwitching) { _ in onSettingsChanged() }

            Text("Maps Cmd+[/] to Ctrl+Left/Right for workspace switching")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .padding(.leading, 20)
      }

      Spacer()
    }
    .frame(maxHeight: 500)
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
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
