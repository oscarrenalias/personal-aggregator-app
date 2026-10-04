import SwiftUI
import UIKit

/// Identifies an article pushed from a thread. A dedicated type rather than a
/// bare `Int` because surrounding stacks already register `Int` destinations
/// for thread, episode, and search-result ids.
struct ThreadArticleRef: Hashable {
    let articleId: Int
}

struct ThreadDetailView: View {
    let threadId: Int

    @Environment(CredentialsStore.self) private var credentialsStore
    @Environment(ThreadSeenStore.self) private var seenStore
    @State private var thread: Thread? = nil
    @State private var members: [ThreadMember] = []
    @State private var nextCursor: String? = nil
    @State private var previousLastViewedAt: String? = nil
    @State private var isLoadingMore = false
    @State private var isInitialLoad = true
    @State private var loadError: Error? = nil
    @State private var showKnownFacts: Bool = false

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

    private func hasHero(_ thread: Thread) -> Bool {
        guard let s = thread.imageURL else { return false }
        return URL(string: s) != nil
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
        // No navigationTitle: the title is shown once, prominently, below the
        // hero in the content. A redundant inline title would also render black
        // over the hero image, which reads poorly.
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ThreadArticleRef.self) { ref in
            ArticleDetailView(articleId: ref.articleId)
        }
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

                    let qualifying = newDeltas(thread)
                    let all = allDeltas(thread)
                    let coveredFacts = Self.factsCoveredByDeltas(qualifying)
                    let residualFacts = thread.knownFacts.filter { !coveredFacts.contains($0) }
                    if !residualFacts.isEmpty {
                        knownFactsSection(residualFacts)
                    }

                    membersSection(thread: thread, qualifyingDeltas: qualifying, articleDeltas: all)
                }
                .padding(.horizontal, ReaderLayout.hPadding)
                .padding(.vertical)
            }
        }
        // Bleed under the bars only when there's a hero; otherwise let the system
        // inset the title below the floating toolbar (matches the article reader).
        .ignoresSafeArea(hasHero(thread) ? .all : [], edges: .top)
        // See ArticleContentView: iPad-only suppression of the iOS 26 top-edge blur.
        .scrollEdgeEffectHidden(UIDevice.current.userInterfaceIdiom == .pad, for: .top)
    }

    // MARK: - Hero image

    @ViewBuilder
    private func heroSection(_ thread: Thread) -> some View {
        if hasHero(thread), let imageURLString = thread.imageURL {
            HeroImageView(urlString: imageURLString, height: 220)
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
                Text("Here's the latest")
                    .font(.headline)
                Text(summary)
                    .font(.body)
            }
        }
    }

    // MARK: - Delta filtering helpers

    // Exposed as static (internal) for unit testing; pure — no view state dependency.
    static func filterNewDeltas(in deltas: [ThreadDelta], since cutoff: String?) -> [ThreadDelta] {
        let filtered: [ThreadDelta]
        if let cutoff {
            filtered = deltas.filter { $0.timestamp > cutoff }
        } else {
            filtered = deltas
        }
        return filtered.filter { delta in
            delta.label != nil || !delta.newFacts.isEmpty || (delta.reason.map { !$0.isEmpty } ?? false)
        }
    }

    private func newDeltas(_ thread: Thread) -> [ThreadDelta] {
        Self.filterNewDeltas(in: thread.deltas, since: previousLastViewedAt)
    }

    // All deltas with non-empty content, regardless of timestamp.
    private func allDeltas(_ thread: Thread) -> [ThreadDelta] {
        thread.deltas.filter { delta in
            delta.label != nil || !delta.newFacts.isEmpty || (delta.reason.map { !$0.isEmpty } ?? false)
        }
    }

    // Returns the union of newFacts across all deltas — facts already surfaced inline in article rows.
    static func factsCoveredByDeltas(_ deltas: [ThreadDelta]) -> Set<String> {
        Set(deltas.flatMap { $0.newFacts })
    }

    // Finds the first qualifying delta whose articleId matches the given member's articleId.
    static func delta(for member: ThreadMember, in qualifyingDeltas: [ThreadDelta]) -> ThreadDelta? {
        qualifyingDeltas.first { $0.articleId == member.articleId }
    }

    // MARK: - Known facts

    // Strip leading bullet chars and whitespace the backend embeds in some known_facts strings.
    private func cleanFact(_ raw: String) -> String {
        raw.drop(while: { $0 == "•" || $0 == "-" || $0 == "*" || $0.isWhitespace })
            .trimmingCharacters(in: .whitespaces)
    }

    @ViewBuilder
    private func knownFactsSection(_ facts: [String]) -> some View {
        DisclosureGroup(isExpanded: $showKnownFacts) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(facts, id: \.self) { fact in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(cleanFact(fact))
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Known facts")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Members

    @ViewBuilder
    private func membersSection(thread: Thread, qualifyingDeltas: [ThreadDelta], articleDeltas: [ThreadDelta]) -> some View {
        if activeMembers.isEmpty && suppressedMembers.isEmpty {
            ContentUnavailableView("No articles", systemImage: "doc.text")
                .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                let hasNewDeltaArticles = activeMembers.contains { member in
                    Self.delta(for: member, in: qualifyingDeltas) != nil
                }
                let unlinkedDeltas = qualifyingDeltas.filter { $0.articleId == nil && !$0.newFacts.isEmpty }

                if !activeMembers.isEmpty {
                    if hasNewDeltaArticles {
                        Text("New since last visit")
                            .font(.headline)
                            .padding(.bottom, 12)
                    } else {
                        Text("Articles")
                            .font(.headline)
                            .padding(.bottom, 12)
                    }

                    ForEach(Array(activeMembers.enumerated()), id: \.element.id) { index, member in
                        let matchedDelta = Self.delta(for: member, in: articleDeltas)
                        NavigationLink(value: ThreadArticleRef(articleId: member.articleId)) {
                            activeMemberRow(member, delta: matchedDelta)
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

                if !unlinkedDeltas.isEmpty {
                    Text("Other updates")
                        .font(.headline)
                        .padding(.top, activeMembers.isEmpty ? 0 : 20)
                        .padding(.bottom, 8)

                    ForEach(Array(unlinkedDeltas.enumerated()), id: \.offset) { _, delta in
                        deltaFactRow(delta)
                    }
                }

                if !suppressedMembers.isEmpty {
                    Text("Also covered by")
                        .font(.headline)
                        .padding(.top, (activeMembers.isEmpty && unlinkedDeltas.isEmpty) ? 0 : 20)
                        .padding(.bottom, 8)

                    ForEach(suppressedMembers) { member in
                        NavigationLink(value: ThreadArticleRef(articleId: member.articleId)) {
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
    private func activeMemberRow(_ member: ThreadMember, delta: ThreadDelta?) -> some View {
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

                if let delta, !delta.newFacts.isEmpty {
                    ForEach(delta.newFacts, id: \.self) { fact in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(fact)
                                .font(.body)
                        }
                    }
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

    // Used for unlinked qualifying deltas rendered in the "Other updates" group.
    @ViewBuilder
    private func deltaFactRow(_ delta: ThreadDelta) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = delta.label {
                classificationBadge(for: label)
            }

            ForEach(delta.newFacts, id: \.self) { fact in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(fact)
                        .font(.body)
                }
            }
        }
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
            // Capture the pre-POST value so the articles section shows deltas since the *previous*
            // visit, not the current one. postViewedThread updates last_viewed_at to now on
            // the server, so reading it afterward would hide all current-visit deltas.
            previousLastViewedAt = t.lastViewedAt
            seenStore.markSeen(id: t.id, lastUpdated: t.lastUpdated)
            do {
                _ = try await apiClient.postViewedThread(id: threadId)
            } catch {
                // swallow: thread content already rendered
            }
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
