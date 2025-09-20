// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "AppSwitcher",
  platforms: [
    .macOS(.v12)
  ],
  targets: [
    .executableTarget(
      name: "AppSwitcher",
      path: ".",
      sources: [
        "main.swift",
        "HotkeyHandler.swift",
        "AppDelegate.swift",
        "AppDiscovery.swift",
        "KeybindingCaptureView.swift",
        "ConfigManager.swift",
        "AccessibilityManager.swift",
        "ConfigurationUI/ConfigView.swift",
        "ConfigurationUI/AppsTabView.swift",
        "ConfigurationUI/SettingsTabView.swift",
        "ConfigurationUI/AppAssignmentModal.swift",
        "ConfigurationUI/AppRowView.swift",
      ]
    )
  ]
)
