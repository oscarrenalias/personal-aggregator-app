import SwiftUI

struct ThreadDetailView: View {
    let threadId: Int

    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(ThreadSeenStore.self) private var seenStore
    @State private var thread: Thread? = nil
    @State private var members: [ThreadMember] = []
    @State private var nextCursor: String? = nil
    @State private var isLoadingMore = false
    @State private var isInitialLoad = true
    @State private var loadError: Error? = nil

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    private var activeMembers: [ThreadMember] {
        members
            .filter { !$0.suppressed }
            .sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") }
    }

    private var suppressedMembers: [ThreadMember] {
        members.filter { $0.suppressed }
    }

    var body: some View {
        Group {
            if let error = loadError {
                errorView(error)
            } else if isInitialLoad {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let thread {
                scrollContent(thread)
            } else {
                ContentUnavailableView(
                    "Thread unavailable",
                    systemImage: "bubble.left.and.bubble.right"
                )
            }
        }
        .navigationTitle(thread?.representativeTitle ?? "Thread")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadInitial()
        }
    }

    // MARK: - Error view

    @ViewBuilder
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadInitial() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Main scroll content

    @ViewBuilder
    private func scrollContent(_ thread: Thread) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroSection(thread)

                VStack(alignment: .leading, spacing: 20) {
                    headerSection(thread)

                    if !thread.knownFacts.isEmpty {
                        knownFactsSection(thread.knownFacts)
                    }

                    membersSection()
                }
                .padding(.horizontal, ReaderLayout.hPadding)
                .padding(.vertical)
            }
        }
    }

    // MARK: - Hero image

    @ViewBuilder
    private func heroSection(_ thread: Thread) -> some View {
        if let imageURLString = thread.imageURL, let imageURL = URL(string: imageURLString) {
            // Fixed-size container + clipped image overlay so scaledToFill cannot
            // overflow and force the content column wider than the screen. Rectangle
            // (not Color) so the hero respects the safe area (Color slides under the bar).
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .overlay {
                    AsyncImage(url: imageURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        }
                    }
                }
                .clipped()
                .accessibilityHidden(true)
        }
    }

    // MARK: - Header section

    @ViewBuilder
    private func headerSection(_ thread: Thread) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(thread.representativeTitle)
                .font(.title3.bold())

            let sourceWord = thread.sourceCount == 1 ? "source" : "sources"
            Text("Updated \(DateDisplay.relative(thread.lastUpdated)) · \(thread.sourceCount) \(sourceWord)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let summary = thread.rollingSummary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
            }
        }
    }

    // MARK: - Known facts

    @ViewBuilder
    private func knownFactsSection(_ facts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Known facts")
                .font(.headline)

            ForEach(facts, id: \.self) { fact in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(fact)
                        .font(.body)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Members

    @ViewBuilder
    private func membersSection() -> some View {
        if activeMembers.isEmpty && suppressedMembers.isEmpty {
            ContentUnavailableView("No articles", systemImage: "doc.text")
                .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if !activeMembers.isEmpty {
                    Text("Articles")
                        .font(.headline)
                        .padding(.bottom, 12)

                    ForEach(Array(activeMembers.enumerated()), id: \.element.id) { index, member in
                        NavigationLink(destination: ArticleDetailView(articleId: member.articleId)) {
                            activeMemberRow(member)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if index == activeMembers.count - 1 {
                                Task { await loadMoreIfNeeded() }
                            }
                        }

                        if index < activeMembers.count - 1 {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }

                if !suppressedMembers.isEmpty {
                    // Suppressed members show source name only — their titles duplicate content
                    // already captured in the active members or thread summary.
                    Text("Also covered by")
                        .font(.headline)
                        .padding(.top, activeMembers.isEmpty ? 0 : 20)
                        .padding(.bottom, 8)

                    ForEach(suppressedMembers) { member in
                        NavigationLink(destination: ArticleDetailView(articleId: member.articleId)) {
                            Text(member.sourceName ?? "(unknown source)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open article from \(member.sourceName ?? "unknown source")")
                    }
                }

                if isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
            }
        }
    }

    // MARK: - Active member row

    @ViewBuilder
    private func activeMemberRow(_ member: ThreadMember) -> some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                if let raw = member.classificationLabel {
                    classificationBadge(for: raw)
                }

                Text(member.cleanTitle ?? "(untitled)")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                let caption = memberCaption(member)
                if !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 8)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func classificationBadge(for raw: String) -> some View {
        let color = classificationBadgeColor(raw)
        Text(classificationDisplayLabel(raw))
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.25)))
            .accessibilityLabel("Classification: \(classificationDisplayLabel(raw))")
    }

    // MARK: - Helpers

    private func classificationDisplayLabel(_ raw: String) -> String {
        switch raw {
        case "new_thread":                  return "New Thread"
        case "same_thread_new_fact":        return "New Fact"
        case "same_thread_new_angle":       return "New Angle"
        case "same_thread_duplicate":       return "Duplicate"
        case "same_thread_background_only": return "Background"
        case "correction_or_clarification": return "Correction"
        case "related_new_thread":          return "Related"
        case "irrelevant_or_low_value":     return "Low Value"
        default:                            return raw
        }
    }

    private func classificationBadgeColor(_ raw: String) -> Color {
        switch raw {
        case "new_thread", "related_new_thread":
            return .indigo
        case "same_thread_new_fact":
            return .teal
        case "same_thread_new_angle":
            return .purple
        case "correction_or_clarification":
            return .orange
        default:
            return .secondary
        }
    }

    private func memberCaption(_ member: ThreadMember) -> String {
        var parts: [String] = []
        if let name = member.sourceName { parts.append(name) }
        let date = DateDisplay.relative(member.publishedAt)
        if !date.isEmpty { parts.append(date) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Data loading

    private func loadInitial() async {
        isInitialLoad = true
        loadError = nil
        do {
            async let fetchedThread = apiClient.getThread(id: threadId)
            async let fetchedMembers = apiClient.getThreadMembers(id: threadId)
            let (t, m) = try await (fetchedThread, fetchedMembers)
            thread = t
            members = m.items
            nextCursor = m.nextCursor
            seenStore.markSeen(id: t.id, lastUpdated: t.lastUpdated)
        } catch {
            if isCancellation(error) { return }
            loadError = error
        }
        isInitialLoad = false
    }

    private func loadMoreIfNeeded() async {
        guard !isLoadingMore, let cursor = nextCursor else { return }
        isLoadingMore = true
        do {
            let page = try await apiClient.getThreadMembers(id: threadId, cursor: cursor)
            members.append(contentsOf: page.items)
            nextCursor = page.nextCursor
        } catch {
            // Pagination errors are swallowed — the existing content stays visible
        }
        isLoadingMore = false
    }
}
