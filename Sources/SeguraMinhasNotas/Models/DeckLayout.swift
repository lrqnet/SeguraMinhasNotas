import Foundation

/// Shared geometry for the deck, its viewport and the editor's opening origin.
struct DeckLayout {
    static let canvasWidth: CGFloat = 400
    static let cardWidth: CGFloat = 320
    static let cardHeight: CGFloat = 112
    static let previewHeight: CGFloat = 190
    static let edgeInset: CGFloat = 8
    static let restingWidth: CGFloat = 44
    static let fannedWidth: CGFloat = 214
    static func restingHeight(count: Int) -> CGFloat { max(70, CGFloat(count) * 23 + 48) }

    let count: Int
    let height: CGFloat

    var stride: CGFloat {
        min(76, max(0, (height - Self.previewHeight - 116) / CGFloat(max(1, count - 1))))
    }

    var top: CGFloat { 32 }
    var controlsY: CGFloat { top + CGFloat(max(0, count - 1)) * stride + Self.previewHeight + 28 }

    static func height(count: Int, available: CGFloat) -> CGFloat {
        min(CGFloat(max(0, count - 1)) * 76 + previewHeight + 116, max(300, available - 40))
    }

    func cardFrame(index: Int, expanded: Bool, preview: Bool, left: Bool) -> CGRect {
        let x: CGFloat = preview ? 36 : (expanded ? 252 - CGFloat(index) * 4 : Self.canvasWidth + 24)
        let width = Self.cardWidth
        return CGRect(
            x: left ? Self.canvasWidth - x - width : x,
            y: top + CGFloat(index) * stride,
            width: width,
            height: preview ? Self.previewHeight : Self.cardHeight
        )
    }

    static func screenRect(_ rect: CGRect, window: CGRect, left: Bool) -> CGRect {
        let canvasX = left ? window.minX : window.maxX - canvasWidth
        return CGRect(x: canvasX + rect.minX, y: window.maxY - rect.maxY, width: rect.width, height: rect.height)
    }
}
