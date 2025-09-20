import SwiftUI

private enum Constants {
  static let topPadding: CGFloat = 16
  static let bottomPadding: CGFloat = 20
  static let horizontalPadding: CGFloat = 20
  static let tabPickerWidth: CGFloat = 200
  static let spacing: CGFloat = 12
  static let captionSpacing: CGFloat = 4
}

struct ConfigHeader: View {
  @Binding var selectedTab: Int

  var body: some View {
    VStack(spacing: Constants.spacing) {
      HStack {
        VStack(alignment: .leading, spacing: Constants.captionSpacing) {
          Text("CmdN Configuration")
            .font(.title2)
            .fontWeight(.medium)
          Text("Map apps to number keys and configure shortcuts")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
        // Tab picker
        Picker("", selection: $selectedTab) {
          Text("Apps").tag(0)
          Text("Preferences").tag(1)
        }
        .pickerStyle(SegmentedPickerStyle())
        .frame(width: Constants.tabPickerWidth)
      }
    }
    .padding(.top, Constants.topPadding)
    .padding(.bottom, Constants.bottomPadding)
    .padding(.horizontal, Constants.horizontalPadding)
  }
}
