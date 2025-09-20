import ApplicationServices
import Carbon
import Cocoa
import SwiftUI

class HotkeyHandler: ObservableObject {
  private var registeredHotkeys: [EventHotKeyRef] = []
  private weak var appDelegate: AppDelegate?
  private var handlerRef: EventHandlerRef?
  @Published private(set) var isPaused: Bool = false
  private let configManager = ConfigManager.shared
  private var workspaceEventTap: CFMachPort?
  private var lastWorkspaceEventTime: TimeInterval = 0
  private let workspaceEventThreshold: TimeInterval = 0.1  // 100ms threshold

  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
    installEventHandler()
    updateGlobalKeybindings()
    updateWorkspaceSwitching()
  }

  deinit {
    clearGlobalKeybindings()
    disableWorkspaceSwitching()
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

    // Check if this is the app switcher hotkey
    if hotkeyID.id == 3000 {
      if let delegate = appDelegate {
        _ = delegate.switchToPreviousApp()
      }
      return noErr
    }

    // Handle app switching hotkeys
    let keyNumber = Int(hotkeyID.id - 1000)
    let targetKey = String(keyNumber)

    if let delegate = appDelegate,
      let appName = configManager.keyAppBindings[targetKey]
    {
      _ = delegate.switchToApp(named: appName)
    }

    return noErr
  }

  func updateGlobalKeybindings() {
    clearGlobalKeybindings()
    registerAllNumberKeys()
    if let key = configManager.configHotkey.key, !key.isEmpty {
      registerConfigHotkey()
    }
    if let key = configManager.appSwitcherHotkey.key, !key.isEmpty {
      registerAppSwitcherHotkey()
    }
    updateWorkspaceSwitching()
  }

  private func updateWorkspaceSwitching() {
    disableWorkspaceSwitching()
    if configManager.enableChromeOSWorkspaceSwitching {
      enableWorkspaceSwitching()
    }
  }

  private func enableWorkspaceSwitching() {
    let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
          guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
          let handler = Unmanaged<HotkeyHandler>.fromOpaque(refcon).takeUnretainedValue()
          return handler.workspaceEventCallback(proxy: proxy, type: type, event: event)
        },
        userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
      )
    else {
      return
    }

    workspaceEventTap = eventTap

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
  }

  private func disableWorkspaceSwitching() {
    if let eventTap = workspaceEventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      CFMachPortInvalidate(eventTap)
      workspaceEventTap = nil
    }
  }

  private func workspaceEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent)
    -> Unmanaged<CGEvent>?
  {
    guard !isPaused, type == .keyDown else {
      return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    // Check for Cmd+[ (simulate Ctrl+Left for previous workspace)
    if keyCode == 33 && flags.contains(.maskCommand) {  // kVK_LeftBracket = 33
      sendCtrlArrow(keyCode: 123)  // kVK_LeftArrow = 123
      return nil  // Consume the event
    }

    // Check for Cmd+] (simulate Ctrl+Right for next workspace)
    if keyCode == 30 && flags.contains(.maskCommand) {  // kVK_RightBracket = 30
      sendCtrlArrow(keyCode: 124)  // kVK_RightArrow = 124
      return nil  // Consume the event
    }

    return Unmanaged.passUnretained(event)
  }

  private func sendCtrlArrow(keyCode: CGKeyCode) {
    let kVK_Control: CGKeyCode = 59

    // Record the time we're generating workspace events
    lastWorkspaceEventTime = Date().timeIntervalSince1970

    // Control down
    guard
      let controlDown = CGEvent(keyboardEventSource: nil, virtualKey: kVK_Control, keyDown: true)
    else {
      return
    }
    controlDown.flags = .maskControl

    // Arrow down (with control flag)
    guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
      return
    }
    keyDown.flags = [.maskControl, .maskSecondaryFn]

    // Arrow up (with control flag)
    guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
      return
    }
    keyUp.flags = [.maskControl, .maskSecondaryFn]

    // Control up
    guard let controlUp = CGEvent(keyboardEventSource: nil, virtualKey: kVK_Control, keyDown: false)
    else {
      return
    }

    controlDown.post(tap: .cghidEventTap)
    keyDown.post(tap: .cghidEventTap)

    // Small delay between down and up
    usleep(10000)  // 10ms

    keyUp.post(tap: .cghidEventTap)
    controlUp.post(tap: .cghidEventTap)
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

  func isWithinWorkspaceEventThreshold() -> Bool {
    let currentTime = Date().timeIntervalSince1970
    return (currentTime - lastWorkspaceEventTime) < workspaceEventThreshold
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
    if configManager.globalHotkey.cmd { modifierFlags |= UInt32(cmdKey) }
    if configManager.globalHotkey.opt { modifierFlags |= UInt32(optionKey) }
    if configManager.globalHotkey.ctrl { modifierFlags |= UInt32(controlKey) }
    if configManager.globalHotkey.shift { modifierFlags |= UInt32(shiftKey) }

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
    guard let key = configManager.configHotkey.key else { return }
    let keyCode = keyCodeForCharacter(key)
    guard keyCode != 0 else { return }

    var configModifierFlags: UInt32 = 0
    if configManager.configHotkey.cmd { configModifierFlags |= UInt32(cmdKey) }
    if configManager.configHotkey.opt { configModifierFlags |= UInt32(optionKey) }
    if configManager.configHotkey.ctrl { configModifierFlags |= UInt32(controlKey) }
    if configManager.configHotkey.shift { configModifierFlags |= UInt32(shiftKey) }

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

  private func registerAppSwitcherHotkey() {
    guard let key = configManager.appSwitcherHotkey.key else { return }
    let keyCode = keyCodeForCharacter(key)
    guard keyCode != 0 else { return }

    var appSwitcherModifierFlags: UInt32 = 0
    if configManager.appSwitcherHotkey.cmd { appSwitcherModifierFlags |= UInt32(cmdKey) }
    if configManager.appSwitcherHotkey.opt { appSwitcherModifierFlags |= UInt32(optionKey) }
    if configManager.appSwitcherHotkey.ctrl { appSwitcherModifierFlags |= UInt32(controlKey) }
    if configManager.appSwitcherHotkey.shift { appSwitcherModifierFlags |= UInt32(shiftKey) }

    // If no modifiers are selected, default to Command
    if appSwitcherModifierFlags == 0 { appSwitcherModifierFlags = UInt32(cmdKey) }

    var hotKeyRef: EventHotKeyRef?
    let hotKeyID = EventHotKeyID(signature: fourCharCodeFrom("APPS"), id: 3000)

    let status = RegisterEventHotKey(
      keyCode,
      appSwitcherModifierFlags,
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
