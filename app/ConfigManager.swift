import Foundation
import SwiftUI

class ConfigManager: ObservableObject {
  static let shared = ConfigManager()

  private let configFileName = "config"
  private let appName = "cmdn"

  private var configDirectoryPath: String {
    if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"],
      !xdgConfigHome.isEmpty
    {
      return "\(xdgConfigHome)/\(appName)"
    } else {
      return "\(NSHomeDirectory())/.config/\(appName)"
    }
  }

  private var configFilePath: String {
    return "\(configDirectoryPath)/\(configFileName)"
  }

  // Published properties for real-time updates
  @Published var useCmdModifier: Bool = true {
    didSet { if !isLoading { saveConfiguration() } }
  }
  @Published var useOptionModifier: Bool = false {
    didSet { if !isLoading { saveConfiguration() } }
  }
  @Published var useShiftModifier: Bool = false {
    didSet { if !isLoading { saveConfiguration() } }
  }
  @Published var configHotkeyKey: String = "," {
    didSet { if !isLoading { saveConfiguration() } }
  }
  @Published var configHotkeyUseCmdModifier: Bool = true {
    didSet { if !isLoading { saveConfiguration() } }
  }
  @Published var configHotkeyUseOptionModifier: Bool = false {
    didSet { if !isLoading { saveConfiguration() } }
  }
  @Published var configHotkeyUseShiftModifier: Bool = false {
    didSet { if !isLoading { saveConfiguration() } }
  }
  @Published var keyAppBindings: [String: String] = [:] {
    didSet { if !isLoading { saveConfiguration() } }
  }
  @Published var enableLinuxWordMovementMapping: Bool = false {
    didSet { if !isLoading { saveConfiguration() } }
  }
  @Published var enableChromeOSWorkspaceSwitching: Bool = false {
    didSet { if !isLoading { saveConfiguration() } }
  }

  private var isLoading = false

  private init() {
    createConfigDirectoryIfNeeded()
    loadConfigurationFromDisk()
  }

  // MARK: - Private Implementation

  private func createConfigDirectoryIfNeeded() {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: configDirectoryPath) {
      try? fileManager.createDirectory(
        atPath: configDirectoryPath, withIntermediateDirectories: true, attributes: nil)
    }
  }

  private func loadConfigFromFile() {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: configFilePath)),
      let content = String(data: data, encoding: .utf8)
    else {
      return
    }

    let lines = content.components(separatedBy: .newlines)
    var index = 0

    while index < lines.count {
      let trimmedLine = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)

      if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
        index += 1
        continue
      }

      if let equalIndex = trimmedLine.firstIndex(of: "=") {
        let key = String(trimmedLine[..<equalIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = String(trimmedLine[trimmedLine.index(after: equalIndex)...]).trimmingCharacters(
          in: .whitespacesAndNewlines)

        if !key.isEmpty {
          parseOption(key: key, value: value)
        }
      }

      index += 1
    }
  }

  private func saveConfigToFile() {
    var lines: [String] = []

    lines.append("use_cmd_modifier=\(useCmdModifier ? "true" : "false")")
    lines.append("use_option_modifier=\(useOptionModifier ? "true" : "false")")
    lines.append("use_shift_modifier=\(useShiftModifier ? "true" : "false")")
    lines.append("config_hotkey_key=\(configHotkeyKey)")
    lines.append("config_hotkey_use_cmd=\(configHotkeyUseCmdModifier ? "true" : "false")")
    lines.append("config_hotkey_use_option=\(configHotkeyUseOptionModifier ? "true" : "false")")
    lines.append("config_hotkey_use_shift=\(configHotkeyUseShiftModifier ? "true" : "false")")
    lines.append(
      "enable_linux_word_movement_mapping=\(enableLinuxWordMovementMapping ? "true" : "false")")
    lines.append(
      "enable_chromeos_workspace_switching=\(enableChromeOSWorkspaceSwitching ? "true" : "false")")

    for (key, appName) in keyAppBindings.sorted(by: { $0.key < $1.key }) {
      lines.append("keybinding.\(key)=\(appName)")
    }

    let content = lines.joined(separator: "\n")

    do {
      try content.write(toFile: configFilePath, atomically: true, encoding: .utf8)
    } catch {
      print("Failed to save config: \(error)")
    }
  }

  private func parseOption(key: String, value: String) {
    switch key {
    case "use_cmd_modifier":
      useCmdModifier = parseBoolValue(value, key: key) ?? true
    case "use_option_modifier":
      useOptionModifier = parseBoolValue(value, key: key) ?? false
    case "use_shift_modifier":
      useShiftModifier = parseBoolValue(value, key: key) ?? false
    case "config_hotkey_key":
      configHotkeyKey = parseHotkeyKey(value, key: key) ?? ","
    case "config_hotkey_use_cmd":
      configHotkeyUseCmdModifier = parseBoolValue(value, key: key) ?? true
    case "config_hotkey_use_option":
      configHotkeyUseOptionModifier = parseBoolValue(value, key: key) ?? false
    case "config_hotkey_use_shift":
      configHotkeyUseShiftModifier = parseBoolValue(value, key: key) ?? false
    case "enable_linux_word_movement_mapping":
      enableLinuxWordMovementMapping = parseBoolValue(value, key: key) ?? false
    case "enable_chromeos_workspace_switching":
      enableChromeOSWorkspaceSwitching = parseBoolValue(value, key: key) ?? false
    default:
      if key.hasPrefix("keybinding.") {
        let shortKey = String(key.dropFirst("keybinding.".count))
        if let (validKey, validAppName) = parseKeybinding(key: shortKey, appName: value) {
          keyAppBindings[validKey] = validAppName
        }
      } else {
        fputs("Warning: Unknown configuration option '\(key)', ignoring\n", stderr)
      }
    }
  }

  private func loadConfigurationFromDisk() {
    isLoading = true

    // Set defaults
    useCmdModifier = true
    useOptionModifier = false
    useShiftModifier = false
    configHotkeyKey = ","
    configHotkeyUseCmdModifier = true
    configHotkeyUseOptionModifier = false
    configHotkeyUseShiftModifier = false
    enableLinuxWordMovementMapping = false
    enableChromeOSWorkspaceSwitching = false
    keyAppBindings = [:]

    // Load from file
    loadConfigFromFile()

    isLoading = false
  }

  private func saveConfiguration() {
    saveConfigToFile()
  }

  // MARK: - Public API

  func setKeyAppBinding(key: String, appName: String?) {
    if let appName = appName {
      keyAppBindings[key] = appName
    } else {
      keyAppBindings.removeValue(forKey: key)
    }
  }

  func removeKeyAppBinding(key: String) {
    setKeyAppBinding(key: key, appName: nil)
  }
}

private func parseBoolValue(_ value: String, key: String) -> Bool? {
  let lowercased = value.lowercased()
  if lowercased == "true" || lowercased == "false" {
    return lowercased == "true"
  } else {
    fputs("Warning: Invalid boolean value '\(value)' for \(key)\n", stderr)
    return nil
  }
}

private func parseHotkeyKey(_ key: String, key keyName: String) -> String? {
  if key.count == 1
    && key.rangeOfCharacter(from: .alphanumerics.union(.punctuationCharacters)) != nil
  {
    return key
  } else {
    fputs("Warning: Invalid hotkey key '\(key)' for \(keyName)\n", stderr)
    return nil
  }
}

private func parseKeybinding(key: String, appName: String) -> (String, String)? {
  if key.count == 1 && key.rangeOfCharacter(from: .alphanumerics) != nil
    && !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  {
    return (key, appName)
  } else {
    fputs("Warning: Invalid keybinding '\(key)=\(appName)'\n", stderr)
    return nil
  }
}
