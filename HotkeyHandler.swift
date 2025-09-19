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

    for (keyChar, keyCode) in numberKeys {
      var hotKeyRef: EventHotKeyRef?
      let hotKeyID = EventHotKeyID(
        signature: fourCharCodeFrom("SWCH"), id: UInt32(1000 + keyChar.wholeNumberValue!))

      let status = RegisterEventHotKey(
        keyCode,
        UInt32(cmdKey),
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
}

private func fourCharCodeFrom(_ string: String) -> FourCharCode {
  let chars = Array(string.utf8)
  return FourCharCode(chars[0]) << 24 | FourCharCode(chars[1]) << 16 | FourCharCode(chars[2]) << 8
    | FourCharCode(chars[3])
}
