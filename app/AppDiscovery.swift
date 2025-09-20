import Cocoa

struct AvailableApp: Identifiable {
  let id = UUID()
  let name: String
  let icon: NSImage?
  let bundleURL: URL?
}

class AppDiscovery {
  static let shared = AppDiscovery()

  private let applicationPaths = [
    "/Applications",
    "/System/Applications",
    "\(NSHomeDirectory())/Applications",
  ]

  private let workspace = NSWorkspace.shared
  private var appNameToAppMapping: [String: AvailableApp] = [:]

  private init() {}

  func refresh() {
    var apps: [String: AvailableApp] = [:]

    for appDir in applicationPaths {
      guard
        let enumerator = FileManager.default.enumerator(
          at: URL(fileURLWithPath: appDir),
          includingPropertiesForKeys: [.isApplicationKey],
          options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
      else { continue }

      for case let fileURL as URL in enumerator {
        guard fileURL.pathExtension == "app" else { continue }

        let appName = fileURL.deletingPathExtension().lastPathComponent
        let appIcon = workspace.icon(forFile: fileURL.path)
        appIcon.size = NSSize(width: 32, height: 32)

        apps[appName] = AvailableApp(name: appName, icon: appIcon, bundleURL: fileURL)
      }
    }

    appNameToAppMapping = apps
  }

  func getInstalledApps() -> [AvailableApp] {
    if appNameToAppMapping.isEmpty {
      refresh()
    }

    return Array(appNameToAppMapping.values).sorted { $0.name < $1.name }
  }

  func findAppIcon(for appName: String) -> NSImage? {
    if appNameToAppMapping.isEmpty {
      refresh()
    }

    return appNameToAppMapping[appName]?.icon
  }

  func findAppBundleURL(for appName: String) -> URL? {
    if appNameToAppMapping.isEmpty {
      refresh()
    }

    return appNameToAppMapping[appName]?.bundleURL
  }
}
