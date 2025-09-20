import SwiftUI

private enum Constants {
  static let keybindingSpacing: CGFloat = 4
}

struct AppsTabView: View {
  let keybindings: [KeybindingData]
  let globalHotkey: Hotkey
  let onAssign: (String) -> Void
  let onUnassign: (String) -> Void

  var body: some View {
    VStack(spacing: Constants.keybindingSpacing) {
      ForEach(keybindings) { keybinding in
        KeybindingRowView(
          keybinding: keybinding,
          onAssign: {
            onAssign(keybinding.key)
          },
          onUnassign: {
            onUnassign(keybinding.key)
          },
          globalHotkey: globalHotkey
        )
      }
    }
  }
}
