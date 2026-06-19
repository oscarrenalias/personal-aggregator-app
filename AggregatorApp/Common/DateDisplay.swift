import Foundation

enum DateDisplay {
    static func relative(_ iso: String?, now: Date = Date()) -> String {
        guard let iso else { return "" }
        guard let date = parseISO8601(iso) else { return "" }

        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        if seconds < 604800 { return "\(Int(seconds / 86400))d ago" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private static func parseISO8601(_ iso: String) -> Date? {
        // Try fractional seconds first (e.g. 2026-06-17T04:41:10.929002+00:00)
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: iso) { return date }

        // Fall back to whole-second ISO-8601
        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]
        return withoutFractional.date(from: iso)
    }
}
