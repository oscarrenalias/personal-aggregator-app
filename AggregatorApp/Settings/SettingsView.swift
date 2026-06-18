import SwiftUI

struct SettingsView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    @State private var connectionStatus: ConnectionStatus?
    @State private var isTesting = false

    private enum ConnectionStatus {
        case success(String)
        case failure(String)
    }

    var body: some View {
        @Bindable var credentialsStore = credentialsStore

        NavigationStack {
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
            .navigationTitle("Settings")
        }
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
