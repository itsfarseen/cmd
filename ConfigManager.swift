import Foundation
import SwiftUI

class RawConfig {
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

  private var cache: [String: String] = [:]
  private var isLoaded = false

  init() {
    createConfigDirectoryIfNeeded()
  }

  private func createConfigDirectoryIfNeeded() {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: configDirectoryPath) {
      try? fileManager.createDirectory(
        atPath: configDirectoryPath, withIntermediateDirectories: true, attributes: nil)
    }
  }

  private func ensureLoaded() {
    if !isLoaded {
      cache = loadFromFile()
      isLoaded = true
    }
  }

  private func loadFromFile() -> [String: String] {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: configFilePath)),
      let content = String(data: data, encoding: .utf8)
    else {
      return [:]
    }

    var config: [String: String] = [:]

    for line in content.components(separatedBy: .newlines) {
      let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

      // Skip empty lines and comments
      if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
        continue
      }

      // Parse key=value pairs
      if let equalIndex = trimmedLine.firstIndex(of: "=") {
        let key = String(trimmedLine[..<equalIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = String(trimmedLine[trimmedLine.index(after: equalIndex)...]).trimmingCharacters(
          in: .whitespacesAndNewlines)

        if !key.isEmpty {
          config[key] = value
        }
      }
    }

    return config
  }

  func getString(key: String, default defaultValue: String = "") -> String {
    ensureLoaded()
    return cache[key] ?? defaultValue
  }

  func getBool(key: String, default defaultValue: Bool = false) -> Bool {
    ensureLoaded()
    guard let stringValue = cache[key] else { return defaultValue }
    return stringValue.lowercased() == "true"
  }

  func setValue(_ value: String, forKey key: String) {
    ensureLoaded()
    cache[key] = value
  }

  func setBool(_ value: Bool, forKey key: String) {
    ensureLoaded()
    cache[key] = value ? "true" : "false"
  }

  func removeValue(forKey key: String) {
    ensureLoaded()
    cache.removeValue(forKey: key)
  }

  func getKeysWithPrefix(_ prefix: String) -> [String: String] {
    ensureLoaded()
    var result: [String: String] = [:]
    for (key, value) in cache {
      if key.hasPrefix(prefix) {
        let shortKey = String(key.dropFirst(prefix.count))
        result[shortKey] = value
      }
    }
    return result
  }

  func save() {
    let sortedKeys = cache.keys.sorted()
    let content = sortedKeys.map { key in
      "\(key)=\(cache[key] ?? "")"
    }.joined(separator: "\n")

    do {
      try content.write(toFile: configFilePath, atomically: true, encoding: .utf8)
    } catch {
      print("Failed to save config: \(error)")
    }
  }
}

class ConfigManager: ObservableObject {
  static let shared = ConfigManager()

  private let rawConfig = RawConfig()

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

  private var isLoading = false

  private init() {
    loadConfigurationFromDisk()
  }

  // MARK: - Public API

  private func loadConfigurationFromDisk() {
    isLoading = true

    // Load modifier settings
    useCmdModifier = rawConfig.getBool(key: "use_cmd_modifier", default: true)
    useOptionModifier = rawConfig.getBool(key: "use_option_modifier", default: false)
    useShiftModifier = rawConfig.getBool(key: "use_shift_modifier", default: false)

    // Load config hotkey settings
    configHotkeyKey = rawConfig.getString(key: "config_hotkey_key", default: ",")
    configHotkeyUseCmdModifier = rawConfig.getBool(key: "config_hotkey_use_cmd", default: true)
    configHotkeyUseOptionModifier = rawConfig.getBool(
      key: "config_hotkey_use_option", default: false)
    configHotkeyUseShiftModifier = rawConfig.getBool(key: "config_hotkey_use_shift", default: false)

    // Load key-app bindings
    keyAppBindings = rawConfig.getKeysWithPrefix("keybinding.")

    isLoading = false
  }

  private func saveConfiguration() {
    // Save modifier settings
    rawConfig.setBool(useCmdModifier, forKey: "use_cmd_modifier")
    rawConfig.setBool(useOptionModifier, forKey: "use_option_modifier")
    rawConfig.setBool(useShiftModifier, forKey: "use_shift_modifier")

    // Save config hotkey settings
    rawConfig.setValue(configHotkeyKey, forKey: "config_hotkey_key")
    rawConfig.setBool(configHotkeyUseCmdModifier, forKey: "config_hotkey_use_cmd")
    rawConfig.setBool(configHotkeyUseOptionModifier, forKey: "config_hotkey_use_option")
    rawConfig.setBool(configHotkeyUseShiftModifier, forKey: "config_hotkey_use_shift")

    // Clear existing keybindings
    let existingBindings = rawConfig.getKeysWithPrefix("keybinding.")
    for key in existingBindings.keys {
      rawConfig.removeValue(forKey: "keybinding.\(key)")
    }

    // Save new key-app bindings
    for (key, appName) in keyAppBindings {
      rawConfig.setValue(appName, forKey: "keybinding.\(key)")
    }

    rawConfig.save()
  }

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
