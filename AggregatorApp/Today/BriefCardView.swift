import SwiftUI

struct BriefCardView: View {
    let brief: Brief
    let isLatest: Bool

    private var dateLine: String {
        let date = DateDisplay.mediumDate(brief.periodStart)
        return isLatest ? "Today · \(date)" : date
    }

    private var topicCountLine: String {
        let count = brief.topics.count
        return count == 1 ? "1 topic" : "\(count) topics"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(brief.headline ?? "Daily Brief")
                .font(.headline)
                .lineLimit(2)

            Text(topicCountLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowBackground(Color.clear)
    }
}
