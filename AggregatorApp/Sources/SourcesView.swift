import SwiftUI

struct SourcesView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    @State private var sources: [Source] = []
    @State private var isLoading = false
    @State private var loadError: Error?

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !credentialsStore.isConfigured {
                    ContentUnavailableView(
                        "Not configured",
                        systemImage: "gearshape",
                        description: Text("Enter your server credentials in Settings.")
                    )
                } else if isLoading {
                    ProgressView()
                } else if let error = loadError {
                    VStack(spacing: 16) {
                        Text(error.localizedDescription)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await loadSources() }
                        }
                    }
                } else if sources.isEmpty {
                    ContentUnavailableView(
                        "No sources",
                        systemImage: "antenna.radiowaves.left.and.right"
                    )
                } else {
                    GlassEffectContainer {
                        List(sources) { source in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.name)
                                    .font(.body)
                                Text(source.feedURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("\(source.name), \(source.feedURL)")
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .navigationTitle("Sources")
        }
        .task {
            if credentialsStore.isConfigured {
                await loadSources()
            }
        }
    }

    private func loadSources() async {
        isLoading = true
        loadError = nil
        do {
            sources = try await apiClient.getSources()
        } catch {
            loadError = error
        }
        isLoading = false
    }
}
