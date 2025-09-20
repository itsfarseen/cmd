import SwiftUI

private enum Constants {
  static let horizontalPadding: CGFloat = 20
  static let verticalPadding: CGFloat = 16
}

struct ConfigFooter: View {
  let onDismiss: () -> Void

  private var bundleIdentifier: String {
    Bundle.main.bundleIdentifier ?? "(not bundled)"
  }

  var body: some View {
    VStack(spacing: 0) {
      Divider()
        .padding(.horizontal, Constants.horizontalPadding)

      HStack {
        Text(bundleIdentifier)
          .font(.caption2)
          .foregroundColor(.secondary)

        Spacer()

        Button("Done") {
          onDismiss()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
      }
      .padding(.horizontal, Constants.horizontalPadding)
      .padding(.vertical, Constants.verticalPadding)
    }
  }
}
