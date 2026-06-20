import SwiftUI

/// Renders multi-paragraph body text with comfortable spacing.
///
/// Rendered as a **single** `Text` (paragraphs joined by a blank line) rather
/// than a `VStack` of separate `Text` views. A stack of long `Text` views inside
/// a horizontally-padded container reports an oversized ideal width and lays out
/// left of the parent's padding — making the reader body hug the screen edge
/// while its siblings (title, byline, summary) sit at the correct margin. A
/// single `Text` respects the parent padding exactly like the thread summary,
/// keeping reader bodies consistent.
struct ParagraphText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(paragraphs.joined(separator: "\n\n"))
            .lineSpacing(5)
            .textSelection(.enabled)
    }

    private var paragraphs: [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
