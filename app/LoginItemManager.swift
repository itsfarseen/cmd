import Cocoa
import Foundation

class LoginItemManager: ObservableObject {
  static let shared = LoginItemManager()

  private init() {}

  enum ValidationResult {
    case valid
    case invalidLocation(message: String)
    case duplicateInstallation(message: String)
  }

  func validateInstallationForLoginItem() -> ValidationResult {
    let currentPath = Bundle.main.bundlePath
    let systemApps = "/Applications/"
    let userApps = NSHomeDirectory() + "/Applications/"

    // Check if we're in a valid location
    guard currentPath.hasPrefix(systemApps) || currentPath.hasPrefix(userApps) else {
      return .invalidLocation(
        message: "App must be installed in Applications folder to enable login at startup")
    }

    // Check for duplicates
    guard let bundleId = Bundle.main.bundleIdentifier else {
      return .invalidLocation(message: "App bundle identifier not configured")
    }
    if let otherURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
      otherURL.path != currentPath
    {
      return .duplicateInstallation(
        message: "Multiple app copies detected. Remove duplicate from other Applications folder.")
    }

    return .valid
  }

  func isLoginItemEnabled() -> Bool {
    guard let bundleId = Bundle.main.bundleIdentifier else {
      print("Warning: Bundle identifier not found")
      return false
    }
    let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/\(bundleId).plist"
    return FileManager.default.fileExists(atPath: plistPath)
  }

  func setLoginItemEnabled(_ enabled: Bool) -> Bool {
    let validation = validateInstallationForLoginItem()
    guard case .valid = validation else {
      return false
    }

    guard let bundleId = Bundle.main.bundleIdentifier else {
      print("Error: Bundle identifier not found")
      return false
    }
    let launchAgentsDir = NSHomeDirectory() + "/Library/LaunchAgents"
    let plistPath = "\(launchAgentsDir)/\(bundleId).plist"

    if enabled {
      return createLoginItem(at: plistPath)
    } else {
      return removeLoginItem(at: plistPath)
    }
  }

  private func createLoginItem(at plistPath: String) -> Bool {
    guard let bundleId = Bundle.main.bundleIdentifier,
      let executableName = Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
    else {
      print("Error: Bundle not properly configured for login item")
      return false
    }

    let currentPath = Bundle.main.bundlePath

    // Ensure LaunchAgents directory exists
    let launchAgentsDir = URL(fileURLWithPath: plistPath).deletingLastPathComponent().path
    try? FileManager.default.createDirectory(
      atPath: launchAgentsDir, withIntermediateDirectories: true)

    let plistContent = """
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>\(bundleId)</string>
        <key>ProgramArguments</key>
        <array>
          <string>\(currentPath)/Contents/MacOS/\(executableName)</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <false/>
      </dict>
      </plist>
      """

    do {
      try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
      return true
    } catch {
      print("Failed to create login item: \(error)")
      return false
    }
  }

  private func removeLoginItem(at plistPath: String) -> Bool {
    do {
      try FileManager.default.removeItem(atPath: plistPath)
      return true
    } catch {
      // File might not exist, which is fine
      return true
    }
  }
}
