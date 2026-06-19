import SwiftUI

struct SourcesView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    // nil = not yet fetched (loading); [] = loaded empty; non-empty = loaded
    @State private var sources: [Source]? = nil
    @State private var loadError: Error? = nil

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
                } else if let error = loadError {
                    VStack(spacing: 16) {
                        Text(error.localizedDescription)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadSources() }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loaded = sources {
                    if loaded.isEmpty {
                        ContentUnavailableView(
                            "No sources",
                            systemImage: "antenna.radiowaves.left.and.right"
                        )
                    } else {
                        GlassEffectContainer {
                            List(loaded) { source in
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
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        sources = nil
        loadError = nil
        do {
            sources = try await apiClient.getSources()
        } catch {
            if isCancellation(error) { return }
            loadError = error
        }
    }
}
