// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "AppSwitcher",
  platforms: [
    .macOS(.v11)
  ],
  targets: [
    .executableTarget(
      name: "AppSwitcher",
      path: ".",
      sources: [
        "main.swift",
        "AppInfo.swift",
        "HotkeyHandler.swift",
        "ConfigView.swift",
        "AppDelegate.swift",
      ]
    )
  ]
)
