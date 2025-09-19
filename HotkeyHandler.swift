import ApplicationServices
import Carbon
import Cocoa
import SwiftUI

class HotkeyHandler: ObservableObject {
  private var registeredHotkeys: [EventHotKeyRef] = []
  private weak var appDelegate: AppDelegate?
  private var handlerRef: EventHandlerRef?
  @Published private(set) var keyAppBindings: [String: String] = [:]
  @Published private(set) var isPaused: Bool = false
  @Published var useCmdModifier: Bool = true
  @Published var useOptionModifier: Bool = false
  @Published var useShiftModifier: Bool = false
  @Published var configHotkeyKey: String = ","
  @Published var configHotkeyUseCmdModifier: Bool = true
  @Published var configHotkeyUseOptionModifier: Bool = false
  @Published var configHotkeyUseShiftModifier: Bool = false

  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
    loadKeybindings()
    installEventHandler()
  }

  deinit {
    clearGlobalKeybindings()
    if let handlerRef = handlerRef {
      RemoveEventHandler(handlerRef)
    }
  }

  private func installEventHandler() {
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

    let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

    InstallEventHandler(
      GetApplicationEventTarget(),
      { (nextHandler, event, userData) -> OSStatus in
        guard let userData = userData else { return OSStatus(eventNotHandledErr) }
        let handler = Unmanaged<HotkeyHandler>.fromOpaque(userData).takeUnretainedValue()
        return handler.handleHotkey(nextHandler: nextHandler, event: event)
      },
      1,
      &eventType,
      userData,
      &handlerRef
    )
  }

  private func handleHotkey(nextHandler: EventHandlerCallRef?, event: EventRef?) -> OSStatus {
    guard !isPaused else { return noErr }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
      event,
      EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &hotkeyID
    )

    guard status == noErr else { return status }

    // Check if this is the config hotkey
    if hotkeyID.id == 2000 {
      if let delegate = appDelegate {
        delegate.showConfigWindow()
      }
      return noErr
    }

    // Handle app switching hotkeys
    let keyNumber = Int(hotkeyID.id - 1000)
    let targetKey = String(keyNumber)

    if let delegate = appDelegate,
      let appName = keyAppBindings[targetKey]
    {
      _ = delegate.switchToApp(named: appName)
    }

    return noErr
  }

  func registerGlobalKeybindings() {
    clearGlobalKeybindings()
    registerAllNumberKeys()
    if !configHotkeyKey.isEmpty {
      registerConfigHotkey()
    }
  }

  func setKeyBinding(key: String, appName: String?) {
    if let appName = appName, key.count == 1 && key.first?.isNumber == true {
      keyAppBindings[key] = appName
    } else {
      keyAppBindings.removeValue(forKey: key)
    }
  }

  func removeKeyBinding(key: String) {
    keyAppBindings.removeValue(forKey: key)
  }

  func saveKeybindings() {
    let filePath = NSHomeDirectory().appending("/.appswitch_keybindings")
    let dict = NSDictionary(dictionary: keyAppBindings)
    dict.write(toFile: filePath, atomically: true)
    saveModifierSettings()
  }

  func saveModifierSettings() {
    let settingsPath = NSHomeDirectory().appending("/.appswitch_settings")
    let settings: [String: Any] = [
      "useCmdModifier": useCmdModifier,
      "useOptionModifier": useOptionModifier,
      "useShiftModifier": useShiftModifier,
      "configHotkeyKey": configHotkeyKey,
      "configHotkeyUseCmdModifier": configHotkeyUseCmdModifier,
      "configHotkeyUseOptionModifier": configHotkeyUseOptionModifier,
      "configHotkeyUseShiftModifier": configHotkeyUseShiftModifier,
    ]
    let dict = NSDictionary(dictionary: settings)
    dict.write(toFile: settingsPath, atomically: true)
    registerGlobalKeybindings()
  }

  func pause() {
    isPaused = true
  }

  func resume() {
    isPaused = false
  }

  func togglePause() {
    isPaused.toggle()
  }

  private func loadKeybindings() {
    let filePath = NSHomeDirectory().appending("/.appswitch_keybindings")
    if let data = NSDictionary(contentsOfFile: filePath) as? [String: String] {
      keyAppBindings = data
    }
    loadModifierSettings()
  }

  private func loadModifierSettings() {
    let settingsPath = NSHomeDirectory().appending("/.appswitch_settings")
    if let data = NSDictionary(contentsOfFile: settingsPath) as? [String: Any] {
      useCmdModifier = data["useCmdModifier"] as? Bool ?? true
      useOptionModifier = data["useOptionModifier"] as? Bool ?? false
      useShiftModifier = data["useShiftModifier"] as? Bool ?? false
      configHotkeyKey = data["configHotkeyKey"] as? String ?? ","
      configHotkeyUseCmdModifier = data["configHotkeyUseCmdModifier"] as? Bool ?? true
      configHotkeyUseOptionModifier = data["configHotkeyUseOptionModifier"] as? Bool ?? false
      configHotkeyUseShiftModifier = data["configHotkeyUseShiftModifier"] as? Bool ?? false
    }
  }

  private func clearGlobalKeybindings() {
    for hotkey in registeredHotkeys {
      UnregisterEventHotKey(hotkey)
    }
    registeredHotkeys.removeAll()
  }

  private func registerAllNumberKeys() {
    let numberKeys: [(Character, UInt32)] = [
      ("0", UInt32(kVK_ANSI_0)),
      ("1", UInt32(kVK_ANSI_1)),
      ("2", UInt32(kVK_ANSI_2)),
      ("3", UInt32(kVK_ANSI_3)),
      ("4", UInt32(kVK_ANSI_4)),
      ("5", UInt32(kVK_ANSI_5)),
      ("6", UInt32(kVK_ANSI_6)),
      ("7", UInt32(kVK_ANSI_7)),
      ("8", UInt32(kVK_ANSI_8)),
      ("9", UInt32(kVK_ANSI_9)),
    ]

    var modifierFlags: UInt32 = 0
    if useCmdModifier { modifierFlags |= UInt32(cmdKey) }
    if useOptionModifier { modifierFlags |= UInt32(optionKey) }
    if useShiftModifier { modifierFlags |= UInt32(shiftKey) }

    // If no modifiers are selected, default to Command
    if modifierFlags == 0 { modifierFlags = UInt32(cmdKey) }

    for (keyChar, keyCode) in numberKeys {
      var hotKeyRef: EventHotKeyRef?
      let hotKeyID = EventHotKeyID(
        signature: fourCharCodeFrom("SWCH"), id: UInt32(1000 + keyChar.wholeNumberValue!))

      let status = RegisterEventHotKey(
        keyCode,
        modifierFlags,
        hotKeyID,
        GetApplicationEventTarget(),
        0,
        &hotKeyRef
      )

      if status == noErr, let hotkey = hotKeyRef {
        registeredHotkeys.append(hotkey)
      }
    }
  }

  private func registerConfigHotkey() {
    let keyCode = keyCodeForCharacter(configHotkeyKey)
    guard keyCode != 0 else { return }

    var configModifierFlags: UInt32 = 0
    if configHotkeyUseCmdModifier { configModifierFlags |= UInt32(cmdKey) }
    if configHotkeyUseOptionModifier { configModifierFlags |= UInt32(optionKey) }
    if configHotkeyUseShiftModifier { configModifierFlags |= UInt32(shiftKey) }

    // If no modifiers are selected, default to Command
    if configModifierFlags == 0 { configModifierFlags = UInt32(cmdKey) }

    var hotKeyRef: EventHotKeyRef?
    let hotKeyID = EventHotKeyID(signature: fourCharCodeFrom("CONF"), id: 2000)

    let status = RegisterEventHotKey(
      keyCode,
      configModifierFlags,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )

    if status == noErr, let hotkey = hotKeyRef {
      registeredHotkeys.append(hotkey)
    }
  }

  private func keyCodeForCharacter(_ character: String) -> UInt32 {
    switch character.lowercased() {
    case ",": return 43  // kVK_Comma
    case ".": return 47  // kVK_Period
    case ";": return 41  // kVK_Semicolon
    case "'": return 39  // kVK_Quote
    case "[": return 33  // kVK_LeftBracket
    case "]": return 30  // kVK_RightBracket
    case "\\": return 42  // kVK_Backslash
    case "/": return 44  // kVK_Slash
    case "`": return 50  // kVK_Grave
    case "-": return 27  // kVK_Minus
    case "=": return 24  // kVK_Equal
    case "space": return 49  // kVK_Space
    case "a": return UInt32(kVK_ANSI_A)
    case "b": return UInt32(kVK_ANSI_B)
    case "c": return UInt32(kVK_ANSI_C)
    case "d": return UInt32(kVK_ANSI_D)
    case "e": return UInt32(kVK_ANSI_E)
    case "f": return UInt32(kVK_ANSI_F)
    case "g": return UInt32(kVK_ANSI_G)
    case "h": return UInt32(kVK_ANSI_H)
    case "i": return UInt32(kVK_ANSI_I)
    case "j": return UInt32(kVK_ANSI_J)
    case "k": return UInt32(kVK_ANSI_K)
    case "l": return UInt32(kVK_ANSI_L)
    case "m": return UInt32(kVK_ANSI_M)
    case "n": return UInt32(kVK_ANSI_N)
    case "o": return UInt32(kVK_ANSI_O)
    case "p": return UInt32(kVK_ANSI_P)
    case "q": return UInt32(kVK_ANSI_Q)
    case "r": return UInt32(kVK_ANSI_R)
    case "s": return UInt32(kVK_ANSI_S)
    case "t": return UInt32(kVK_ANSI_T)
    case "u": return UInt32(kVK_ANSI_U)
    case "v": return UInt32(kVK_ANSI_V)
    case "w": return UInt32(kVK_ANSI_W)
    case "x": return UInt32(kVK_ANSI_X)
    case "y": return UInt32(kVK_ANSI_Y)
    case "z": return UInt32(kVK_ANSI_Z)
    default: return 0
    }
  }
}

private func fourCharCodeFrom(_ string: String) -> FourCharCode {
  let chars = Array(string.utf8)
  return FourCharCode(chars[0]) << 24 | FourCharCode(chars[1]) << 16 | FourCharCode(chars[2]) << 8
    | FourCharCode(chars[3])
}
