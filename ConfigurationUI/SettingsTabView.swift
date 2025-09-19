import SwiftUI

struct SettingsTabView: View {
  @Binding var useCmdModifier: Bool
  @Binding var useOptionModifier: Bool
  @Binding var useShiftModifier: Bool
  @Binding var configHotkeyKey: String
  @Binding var configHotkeyUseCmdModifier: Bool
  @Binding var configHotkeyUseOptionModifier: Bool
  @Binding var configHotkeyUseShiftModifier: Bool
  let onSettingsChanged: () -> Void

  var body: some View {
    VStack(spacing: 20) {
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

      Spacer()
    }
    .frame(maxHeight: 400)
  }
}
