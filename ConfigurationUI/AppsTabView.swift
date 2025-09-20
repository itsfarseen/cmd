import SwiftUI

struct AppsTabView: View {
  let keybindings: [KeybindingData]
  let useCmdModifier: Bool
  let useOptionModifier: Bool
  let useShiftModifier: Bool
  let onAssign: (String) -> Void
  let onUnassign: (String) -> Void

  var body: some View {
    VStack(spacing: 16) {
      ScrollView {
        VStack(spacing: 4) {
          ForEach(keybindings) { keybinding in
            KeybindingRowView(
              keybinding: keybinding,
              onAssign: {
                onAssign(keybinding.key)
              },
              onUnassign: {
                onUnassign(keybinding.key)
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
}
