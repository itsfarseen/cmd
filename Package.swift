// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "CmdN",
  platforms: [
    .macOS(.v12)
  ],
  targets: [
    .executableTarget(
      name: "CmdN",
      path: "app",
      sources: [
        "main.swift",
        "Hotkey.swift",
        "HotkeyHandler.swift",
        "AppDelegate.swift",
        "AppDiscovery.swift",
        "KeybindingCaptureView.swift",
        "ConfigManager.swift",
        "AccessibilityManager.swift",
        "LoginItemManager.swift",
        "ConfigurationUI/ConfigView.swift",
        "ConfigurationUI/ConfigHeader.swift",
        "ConfigurationUI/ConfigFooter.swift",
        "ConfigurationUI/AppsTabView.swift",
        "ConfigurationUI/SettingsTabView.swift",
        "ConfigurationUI/AppAssignmentModal.swift",
        "ConfigurationUI/AppRowView.swift",
      ]
    )
  ]
)
