import SwiftUI

struct MenuBarView: View {
    @ObservedObject var focusManager: FocusManager
    @State private var searchText = ""

    var filteredApps: [RunningApp] {
        if searchText.isEmpty {
            return focusManager.runningApps
        }
        return focusManager.runningApps.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Kaka")
                    .font(.system(size: 24, weight: .bold))
                Spacer()
                if focusManager.isFocusActive {
                    Circle()
                        .fill(focusManager.isDistracted ? Color.red : Color.green)
                        .frame(width: 12, height: 12)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if focusManager.isFocusActive {
                // Focus active view
                focusActiveView
            } else {
                // App selection view
                appSelectionView
            }
        }
        .frame(width: 320, height: 400)
        .onReceive(NotificationCenter.default.publisher(for: .returnToFocusApp)) { _ in
            focusManager.returnToFocusApp()
        }
    }

    var focusActiveView: some View {
        VStack(spacing: 20) {
            Spacer()

            if let app = focusManager.selectedApp {
                VStack(spacing: 12) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 64, height: 64)
                    }

                    Text("Focusing on")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(app.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }

            if focusManager.isDistracted {
                Text("You're distracted!")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding(.top, 20)
            } else {
                Text("Stay focused!")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding(.top, 20)
            }

            Spacer()

            Button(action: {
                focusManager.stopFocus()
            }) {
                Text("End Focus Session")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding()
        }
    }

    var appSelectionView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding()

            // Instructions
            Text("Select an app to focus on:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // App list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredApps) { app in
                        AppRow(app: app, isSelected: focusManager.selectedApp?.id == app.id)
                            .onTapGesture {
                                focusManager.selectedApp = app
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Divider()

            // Start button
            Button(action: {
                focusManager.startFocus()
            }) {
                HStack {
                    Text("Start Focus")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(focusManager.selectedApp != nil ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(focusManager.selectedApp == nil)
            .padding()

            // Refresh button
            Button(action: {
                focusManager.loadRunningApps()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Apps")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
        }
    }
}

struct AppRow: View {
    let app: RunningApp
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary)
            }

            Text(app.name)
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}
