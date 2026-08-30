import AppKit
import SwiftUI

struct ChecklistTextEditor: NSViewRepresentable {
    @Binding var text: String
    let font: NSFont
    let textColor: NSColor

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = InteractiveChecklistTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = font
        textView.textColor = textColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? InteractiveChecklistTextView else { return }
        context.coordinator.parent = self
        textView.font = font
        textView.textColor = textColor
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChecklistTextEditor

        init(parent: ChecklistTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

private final class InteractiveChecklistTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if point.x <= textContainerInset.width + 34, toggleChecklist(at: point) {
            return
        }
        super.mouseDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        let value = string as NSString
        let cursor = min(selectedRange().location, value.length)
        let lineRange = value.lineRange(for: NSRange(location: cursor, length: 0))
        let rawLine = value.substring(with: lineRange).trimmingCharacters(in: .newlines)

        guard let marker = ChecklistSyntax.marker(in: rawLine) else {
            super.insertNewline(sender)
            return
        }

        if ChecklistSyntax.content(afterMarkerIn: rawLine)?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            let markerLength = (marker as NSString).length
            shouldChangeText(in: NSRange(location: lineRange.location, length: markerLength), replacementString: "")
            textStorage?.replaceCharacters(in: NSRange(location: lineRange.location, length: markerLength), with: "")
            didChangeText()
            return
        }

        super.insertNewline(sender)
        insertText(ChecklistSyntax.unchecked, replacementRange: selectedRange())
    }

    private func toggleChecklist(at point: NSPoint) -> Bool {
        guard let layoutManager, let textContainer, !string.isEmpty else { return false }
        let containerPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let value = string as NSString
        let lineRange = value.lineRange(for: NSRange(location: min(characterIndex, value.length - 1), length: 0))
        let original = value.substring(with: lineRange)
        let trailingNewline = original.hasSuffix("\n")
        let line = original.trimmingCharacters(in: .newlines)
        guard let toggled = ChecklistSyntax.toggled(line) else { return false }
        let replacement = toggled + (trailingNewline ? "\n" : "")
        guard shouldChangeText(in: lineRange, replacementString: replacement) else { return false }
        textStorage?.replaceCharacters(in: lineRange, with: replacement)
        didChangeText()
        return true
    }
}
