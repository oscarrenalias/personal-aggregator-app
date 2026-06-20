import SwiftUI
import UIKit

/// Read-only, user-selectable body text backed by `UITextView`.
///
/// SwiftUI's `Text` + `.textSelection(.enabled)` only selects the whole block and
/// offers a limited menu. A non-editable `UITextView` gives word/range selection
/// and the full system edit menu (Copy, Look Up, Translate, Share, …). Scrolling
/// is disabled so it grows to fit inside the enclosing `ScrollView`; paragraph
/// and line spacing match the reader's `ParagraphText`.
struct SelectableText: UIViewRepresentable {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    /// Paragraphs joined by a blank line (same normalisation as ParagraphText).
    private var normalized: String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false                // grow to fit inside the SwiftUI ScrollView
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.adjustsFontForContentSizeCategory = true
        tv.dataDetectorTypes = []                 // links are handled by the reader, not here
        tv.setContentHuggingPriority(.required, for: .vertical)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        tv.attributedText = NSAttributedString(
            string: normalized,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label,
                .paragraphStyle: style,
            ]
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }
}
