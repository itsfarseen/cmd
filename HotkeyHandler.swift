import ApplicationServices
import Carbon
import Cocoa
import SwiftUI

class HotkeyHandler: ObservableObject {
    private var registeredHotkeys: [EventHotKeyRef] = []
    private weak var appDelegate: AppDelegate?
    private var handlerRef: EventHandlerRef?
    @Published private(set) var appKeybindings: [String: String] = [:]

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

        if let delegate = appDelegate {
            for (appName, keyValue) in appKeybindings {
                if keyValue == targetKey {
                    _ = delegate.switchToApp(named: appName)
                    break
                }
            }
        }

        return noErr
    }

    func registerGlobalKeybindings() {
        clearGlobalKeybindings()

        for (appName, keyValue) in appKeybindings {
            if keyValue.count == 1, let keyChar = keyValue.first, keyChar.isNumber {
                registerKeybinding(for: keyChar, appName: appName)
            }
        }
    }

    func updateKeybinding(for appName: String, key: String) {
        if key.isEmpty {
            appKeybindings.removeValue(forKey: appName)
        } else if key.count == 1 && key.first?.isNumber == true {
            appKeybindings[appName] = key
        }
    }

    func saveKeybindings() {
        let filePath = NSHomeDirectory().appending("/.appswitch_keybindings")
        let dict = NSDictionary(dictionary: appKeybindings)
        dict.write(toFile: filePath, atomically: true)
        registerGlobalKeybindings()
    }

    private func loadKeybindings() {
        let filePath = NSHomeDirectory().appending("/.appswitch_keybindings")
        if let data = NSDictionary(contentsOfFile: filePath) as? [String: String] {
            appKeybindings = data
        }
    }

    private func clearGlobalKeybindings() {
        for hotkey in registeredHotkeys {
            UnregisterEventHotKey(hotkey)
        }
        registeredHotkeys.removeAll()
    }

    private func registerKeybinding(for keyChar: Character, appName: String) {
        let keyCode: UInt32

        switch keyChar {
        case "0": keyCode = UInt32(kVK_ANSI_0)
        case "1": keyCode = UInt32(kVK_ANSI_1)
        case "2": keyCode = UInt32(kVK_ANSI_2)
        case "3": keyCode = UInt32(kVK_ANSI_3)
        case "4": keyCode = UInt32(kVK_ANSI_4)
        case "5": keyCode = UInt32(kVK_ANSI_5)
        case "6": keyCode = UInt32(kVK_ANSI_6)
        case "7": keyCode = UInt32(kVK_ANSI_7)
        case "8": keyCode = UInt32(kVK_ANSI_8)
        case "9": keyCode = UInt32(kVK_ANSI_9)
        default: return
        }

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

private func fourCharCodeFrom(_ string: String) -> FourCharCode {
    let chars = Array(string.utf8)
    return FourCharCode(chars[0]) << 24 | FourCharCode(chars[1]) << 16 | FourCharCode(chars[2]) << 8
        | FourCharCode(chars[3])
}