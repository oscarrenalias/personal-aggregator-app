import SwiftUI
import UIKit

private enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case credentials = "Credentials"
    case about = "About"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .credentials: return "key"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Credentials form (credential entry, connection test)

private struct CredentialsSettingsView: View {
    @Environment(CredentialsStore.self) private var credentialsStore

    @State private var connectionStatus: ConnectionStatus?
    @State private var isTesting = false

    private enum ConnectionStatus {
        case success(String)
        case failure(String)
    }

    var body: some View {
        @Bindable var credentialsStore = credentialsStore

        Form {
            Section("Server") {
                TextField("Base URL", text: $credentialsStore.baseURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                Button("Test Connection") {
                    Task { await testConnection() }
                }

                if isTesting {
                    ProgressView()
                } else if let status = connectionStatus {
                    switch status {
                    case .success(let version):
                        Label("Connected · v\(version)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color(.systemGreen))
                    case .failure(let message):
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(.systemRed))
                    }
                }
            }

            Section("Cloudflare Access") {
                TextField("Client ID", text: $credentialsStore.clientId)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("Client Secret", text: $credentialsStore.clientSecret)
            }
        }
        .navigationTitle("Credentials")
    }

    private func testConnection() async {
        isTesting = true
        connectionStatus = nil
        let client = APIClient(store: credentialsStore)
        do {
            let response = try await client.healthCheck()
            connectionStatus = .success(response.version)
        } catch {
            connectionStatus = .failure(error.localizedDescription)
        }
        isTesting = false
    }
}

// MARK: - About screen

private struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section("App") {
                LabeledContent("Version") {
                    Text(
                        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                    )
                    .foregroundStyle(.secondary)
                }
                LabeledContent("Build") {
                    Text(
                        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("About")
    }
}

// MARK: - Main iPad Settings view

struct SettingsIPadView: View {
    @State private var selectedSection: SettingsSection? = .credentials
    @State private var isPortrait = UIScreen.main.bounds.width < UIScreen.main.bounds.height

    var body: some View {
        Group {
            if isPortrait {
                portraitLayout
            } else {
                landscapeLayout
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            isPortrait = UIScreen.main.bounds.width < UIScreen.main.bounds.height
        }
    }

    // MARK: Landscape: section list pane + detail pane

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            sectionListPane
                .frame(width: 260)

            Divider()

            Group {
                if let section = selectedSection {
                    NavigationStack {
                        sectionDetail(for: section)
                    }
                } else {
                    ContentUnavailableView(
                        "Select a setting",
                        systemImage: "gearshape",
                        description: Text("Choose a category from the list.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Settings")
    }

    // MARK: Portrait: full-width list, tap pushes detail

    private var portraitLayout: some View {
        NavigationStack {
            sectionListPane
                .navigationTitle("Settings")
                .navigationDestination(for: SettingsSection.self) { section in
                    sectionDetail(for: section)
                }
        }
    }

    // MARK: Section list

    private var sectionListPane: some View {
        GlassEffectContainer {
            List {
                ForEach(SettingsSection.allCases) { section in
                    sectionRow(section: section)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func sectionRow(section: SettingsSection) -> some View {
        if isPortrait {
            NavigationLink(value: section) {
                Label(section.rawValue, systemImage: section.systemImage)
            }
            .listRowBackground(Color.clear)
            .accessibilityLabel(section.rawValue)
        } else {
            Button {
                selectedSection = section
            } label: {
                Label(section.rawValue, systemImage: section.systemImage)
            }
            .buttonStyle(.plain)
            .listRowBackground(
                selectedSection == section
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear
            )
            .accessibilityLabel(section.rawValue)
        }
    }

    // MARK: Section detail routing

    @ViewBuilder
    private func sectionDetail(for section: SettingsSection) -> some View {
        switch section {
        case .credentials:
            CredentialsSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}
