import Foundation

struct AppConfiguration {
  // App switching modifier keys
  var useCmdModifier: Bool = true
  var useOptionModifier: Bool = false
  var useShiftModifier: Bool = false

  // Config hotkey settings
  var configHotkeyKey: String = ","
  var configHotkeyUseCmdModifier: Bool = true
  var configHotkeyUseOptionModifier: Bool = false
  var configHotkeyUseShiftModifier: Bool = false

  // Key-app bindings
  var keyAppBindings: [String: String] = [:]
}

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

class ConfigManager {
  static let shared = ConfigManager()

  private let rawConfig = RawConfig()

  private init() {}

  // MARK: - Public API

  func loadConfiguration() -> AppConfiguration {
    var appConfig = AppConfiguration()

    // Load modifier settings
    appConfig.useCmdModifier = rawConfig.getBool(key: "use_cmd_modifier", default: true)
    appConfig.useOptionModifier = rawConfig.getBool(key: "use_option_modifier", default: false)
    appConfig.useShiftModifier = rawConfig.getBool(key: "use_shift_modifier", default: false)

    // Load config hotkey settings
    appConfig.configHotkeyKey = rawConfig.getString(key: "config_hotkey_key", default: ",")
    appConfig.configHotkeyUseCmdModifier = rawConfig.getBool(
      key: "config_hotkey_use_cmd", default: true)
    appConfig.configHotkeyUseOptionModifier = rawConfig.getBool(
      key: "config_hotkey_use_option", default: false)
    appConfig.configHotkeyUseShiftModifier = rawConfig.getBool(
      key: "config_hotkey_use_shift", default: false)

    // Load key-app bindings
    appConfig.keyAppBindings = rawConfig.getKeysWithPrefix("keybinding.")

    return appConfig
  }

  func saveConfiguration(_ appConfig: AppConfiguration) {
    // Save modifier settings
    rawConfig.setBool(appConfig.useCmdModifier, forKey: "use_cmd_modifier")
    rawConfig.setBool(appConfig.useOptionModifier, forKey: "use_option_modifier")
    rawConfig.setBool(appConfig.useShiftModifier, forKey: "use_shift_modifier")

    // Save config hotkey settings
    rawConfig.setValue(appConfig.configHotkeyKey, forKey: "config_hotkey_key")
    rawConfig.setBool(appConfig.configHotkeyUseCmdModifier, forKey: "config_hotkey_use_cmd")
    rawConfig.setBool(appConfig.configHotkeyUseOptionModifier, forKey: "config_hotkey_use_option")
    rawConfig.setBool(appConfig.configHotkeyUseShiftModifier, forKey: "config_hotkey_use_shift")

    // Clear existing keybindings
    let existingBindings = rawConfig.getKeysWithPrefix("keybinding.")
    for key in existingBindings.keys {
      rawConfig.removeValue(forKey: "keybinding.\(key)")
    }

    // Save new key-app bindings
    for (key, appName) in appConfig.keyAppBindings {
      rawConfig.setValue(appName, forKey: "keybinding.\(key)")
    }

    rawConfig.save()
  }

  func setKeyAppBinding(key: String, appName: String?) {
    if let appName = appName {
      rawConfig.setValue(appName, forKey: "keybinding.\(key)")
    } else {
      rawConfig.removeValue(forKey: "keybinding.\(key)")
    }
    rawConfig.save()
  }

  func removeKeyAppBinding(key: String) {
    setKeyAppBinding(key: key, appName: nil)
  }
}
