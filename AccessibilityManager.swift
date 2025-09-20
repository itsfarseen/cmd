import ApplicationServices
import Carbon
import Cocoa

class AccessibilityManager: ObservableObject {
  static let shared = AccessibilityManager()

  private var eventTap: CFMachPort?
  private let configManager = ConfigManager.shared
  private weak var hotkeyHandler: HotkeyHandler?

  private init() {}

  func setHotkeyHandler(_ handler: HotkeyHandler) {
    hotkeyHandler = handler
  }

  // MARK: - Accessibility Permission

  func requestAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    return AXIsProcessTrustedWithOptions(options as CFDictionary)
  }

  func hasAccessibilityPermission() -> Bool {
    return AXIsProcessTrusted()
  }

  // MARK: - Key Remapping

  func startKeyRemapping() {
    guard hasAccessibilityPermission() else {
      return
    }

    stopKeyRemapping()

    let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

    eventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(eventMask),
      callback: { proxy, type, event, userInfo in
        return AccessibilityManager.shared.handleKeyEvent(
          proxy: proxy, type: type, event: event)
      },
      userInfo: nil
    )

    guard let eventTap = eventTap else {
      return
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
  }

  func stopKeyRemapping() {
    if let eventTap = eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      CFMachPortInvalidate(eventTap)
      self.eventTap = nil
    }
  }

  private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent)
    -> Unmanaged<CGEvent>?
  {
    guard configManager.enableLinuxWordMovementMapping else {
      return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    // Check if this Ctrl+Arrow event is within the workspace switching threshold - if so, ignore it
    if let handler = hotkeyHandler, handler.isWithinWorkspaceEventThreshold(),
      flags.contains(.maskControl) && (keyCode == 123 || keyCode == 124)
    {
      return Unmanaged.passUnretained(event)
    }

    // Remap Ctrl+Left/Right and Ctrl+Shift+Left/Right to Option equivalents
    // Check for Control + Left/Right arrow (with or without Shift)
    if flags.contains(.maskControl) && !flags.contains(.maskAlternate)
      && !flags.contains(.maskCommand) && (keyCode == 123 || keyCode == 124)
    {
      // Create new event with Option instead of Control (preserve Shift if present)
      let newEvent = event.copy()
      if let newEvent = newEvent {
        var newFlags = flags
        newFlags.remove(.maskControl)
        newFlags.insert(.maskAlternate)
        newEvent.flags = newFlags
        return Unmanaged.passRetained(newEvent)
      }
    }

    return Unmanaged.passUnretained(event)
  }

  deinit {
    stopKeyRemapping()
  }
}
