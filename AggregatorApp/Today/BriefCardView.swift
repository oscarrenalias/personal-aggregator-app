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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if isLatest {
                    Text("Today")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }

                Text(brief.headline ?? "Daily Brief")
                    .font(.headline)
                    .lineLimit(2)

                if let intro = brief.intro, !intro.isEmpty {
                    Text(intro)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(topicCountLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            calendarBadge
        }
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(brief.headline ?? "Daily Brief"), \(dateLine), \(topicCountLine)")
    }

    /// A calendar-icon-style date badge (month abbreviation over the day number),
    /// echoing the iOS Calendar app icon. Falls back to nothing if the date is unparseable.
    @ViewBuilder
    private var calendarBadge: some View {
        if let comps = DateDisplay.monthDay(brief.periodStart) {
            VStack(spacing: 1) {
                Text(comps.month)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                Text(comps.day)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .frame(width: 48, height: 48)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            .accessibilityHidden(true)
        }
    }
}
