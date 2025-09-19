import SwiftUI

struct AppAssignmentModal: View {
  let runningApps: [AvailableApp]
  let installedApps: [AvailableApp]
  let onSelectApp: (String) -> Void
  let onCancel: () -> Void
  let onRefreshRunning: () -> Void
  let onRefreshInstalled: () -> Void

  @State private var selectedTab = 0
  @State private var isRefreshing = false

  var body: some View {
    VStack(spacing: 16) {
      Text("Select App")
        .font(.headline)

      // Tab picker
      Picker("", selection: $selectedTab) {
        Text("Running").tag(0)
        Text("Installed").tag(1)
      }
      .pickerStyle(SegmentedPickerStyle())
      .frame(width: 200)

      // Refresh button
      HStack {
        Spacer()
        Button(action: {
          isRefreshing = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if selectedTab == 0 {
              onRefreshRunning()
            } else {
              onRefreshInstalled()
            }
            isRefreshing = false
          }
        }) {
          HStack(spacing: 4) {
            Image(systemName: "arrow.clockwise")
              .rotationEffect(.degrees(isRefreshing ? 360 : 0))
              .animation(.easeInOut(duration: 0.5), value: isRefreshing)
            Text("Refresh")
          }
        }
        .buttonStyle(BorderlessButtonStyle())
        .foregroundColor(isRefreshing ? .gray : .blue)
        .disabled(isRefreshing)
      }
      .padding(.horizontal)

      ScrollView {
        VStack(spacing: 4) {
          let appsToShow = selectedTab == 0 ? runningApps : installedApps
          ForEach(appsToShow) { app in
            Button(action: {
              onSelectApp(app.name)
            }) {
              HStack(spacing: 12) {
                if let icon = app.icon {
                  Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                } else {
                  RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                }

                Text(app.name)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .foregroundColor(.primary)
              }
              .padding(.vertical, 8)
              .padding(.horizontal, 12)
              .background(Color(NSColor.controlBackgroundColor))
              .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
      }
      .frame(maxHeight: 300)

      Button("Cancel") {
        onCancel()
      }
    }
    .padding()
    .frame(width: 450, height: 450)
  }
}
