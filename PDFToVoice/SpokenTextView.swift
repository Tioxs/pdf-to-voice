import AppKit
import SwiftUI

/// Native text storage keeps long pages responsive and scrolls the spoken word into view.
struct SpokenTextView: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    let text: String
    let spokenRange: NSRange?
    let fontSize: Double

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 32, height: 28)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        _ = colorScheme // Refresh semantic AppKit colors when the system theme changes.
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let value = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: value.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.paragraphSpacing = 10
        paragraphStyle.lineBreakMode = .byWordWrapping

        // SwiftUI's AttributedString bridge can resolve `.primary` as black.
        // Applying AppKit's semantic color keeps the text readable in both themes.
        value.addAttributes([
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: fontSize),
            .paragraphStyle: paragraphStyle
        ], range: fullRange)

        if let spokenRange, NSMaxRange(spokenRange) <= value.length {
            value.addAttributes([
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.3)
            ], range: spokenRange)
        }

        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        if !textView.attributedString().isEqual(to: value) {
            textView.textStorage?.setAttributedString(value)
            textView.invalidateIntrinsicContentSize()
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        }
        if let spokenRange, NSMaxRange(spokenRange) <= value.length {
            textView.scrollRangeToVisible(spokenRange)
        }
    }
}
