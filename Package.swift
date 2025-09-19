// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "AppSwitcher",
  platforms: [
    .macOS(.v10_15)
  ],
  targets: [
    .executableTarget(
      name: "AppSwitcher",
      path: ".",
      sources: [
        "main.swift",
        "AppInfo.swift",
        "HotkeyHandler.swift",
        "AppList.swift",
        "ConfigWindow.swift",
        "ConfigView.swift",
        "AppDelegate.swift",
      ]
    )
  ]
)
