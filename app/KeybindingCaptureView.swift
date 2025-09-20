import Cocoa
import SwiftUI

struct KeybindingCaptureView: View {
  @Binding var hotkey: Hotkey

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
    .onChange(of: hotkey) { _ in updateDisplayText() }
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
    let hasCtrl = modifierFlags.contains(.control)
    let hasShift = modifierFlags.contains(.shift)

    // Convert keyCode to character
    if let keyChar = keyCodeToCharacter(keyCode) {
      // Update the hotkey
      hotkey = Hotkey(key: keyChar, cmd: hasCmd, opt: hasOption, ctrl: hasCtrl, shift: hasShift)

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
    hotkey = Hotkey(key: nil, cmd: false, opt: false, ctrl: false, shift: false)
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

    if hotkey.cmd { components.append("⌘") }
    if hotkey.opt { components.append("⌥") }
    if hotkey.ctrl { components.append("⌃") }
    if hotkey.shift { components.append("⇧") }

    if let key = hotkey.key, !key.isEmpty {
      components.append(key.uppercased())
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
