import SwiftUI

struct AppRowView: View {
  let appName: String?
  let appIcon: NSImage?
  let shortcut: String?
  let isAssigned: Bool
  let onTap: () -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 12) {
      // Keyboard shortcut display (optional)
      if let shortcut = shortcut {
        Text(shortcut)
          .font(.system(size: 14, weight: .medium))
          .frame(width: 60, alignment: .leading)
          .foregroundColor(.primary)
      }

      // App content
      HStack(spacing: 8) {
        // App icon or placeholder
        if let icon = appIcon {
          Image(nsImage: icon)
            .resizable()
            .frame(width: 20, height: 20)
        } else if isAssigned {
          RoundedRectangle(cornerRadius: 3)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 20, height: 20)
        } else {
          RoundedRectangle(cornerRadius: 3)
            .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(width: 20, height: 20)
        }

        // App name or placeholder text
        if let name = appName {
          Text(name)
            .font(.system(size: 13))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          Text("Tap to assign app")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      onTap()
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 10)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(isHovered ? Color.blue.opacity(0.08) : Color(NSColor.controlBackgroundColor))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    )
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovered = hovering
      }
    }
    .animation(.easeInOut(duration: 0.15), value: isHovered)
  }
}
