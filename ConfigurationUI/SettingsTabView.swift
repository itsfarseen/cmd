import SwiftUI

struct SettingsTabView: View {
  @Binding var useCmdModifier: Bool
  @Binding var useOptionModifier: Bool
  @Binding var useShiftModifier: Bool
  @Binding var configHotkeyKey: String
  @Binding var configHotkeyUseCmdModifier: Bool
  @Binding var configHotkeyUseOptionModifier: Bool
  @Binding var configHotkeyUseShiftModifier: Bool

  var body: some View {
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
}
