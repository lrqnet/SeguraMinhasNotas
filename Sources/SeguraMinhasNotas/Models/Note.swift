import AppKit
import Foundation
import SwiftUI

enum NoteColor: String, Codable, CaseIterable, Identifiable {
    case sun
    case coral
    case mint
    case sky
    case lilac

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sun: return L10n.tr("Sol")
        case .coral: return L10n.tr("Coral")
        case .mint: return L10n.tr("Menta")
        case .sky: return L10n.tr("Céu")
        case .lilac: return L10n.tr("Lilás")
        }
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    var nsColor: NSColor {
        switch self {
        case .sun: return NSColor(srgbRed: 1.00, green: 0.82, blue: 0.32, alpha: 1)
        case .coral: return NSColor(srgbRed: 1.00, green: 0.57, blue: 0.47, alpha: 1)
        case .mint: return NSColor(srgbRed: 0.55, green: 0.88, blue: 0.73, alpha: 1)
        case .sky: return NSColor(srgbRed: 0.53, green: 0.76, blue: 0.98, alpha: 1)
        case .lilac: return NSColor(srgbRed: 0.75, green: 0.66, blue: 0.96, alpha: 1)
        }
    }
}

struct Note: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var body: String
    var tags: [String]
    var color: NoteColor
    var isArchived: Bool
    var isPinned: Bool
    var sortOrder: Double
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String = "",
        body: String = "",
        tags: [String] = [],
        color: NoteColor = .sun,
        isArchived: Bool = false,
        isPinned: Bool = false,
        sortOrder: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
        self.color = color
        self.isArchived = isArchived
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    var displayTitle: String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? L10n.tr("Nota sem título") : cleaned
    }

    var bodyPreview: String {
        body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func matches(_ query: String) -> Bool {
        let needle = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !needle.isEmpty else { return true }
        let haystack = ([title, body] + tags)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return haystack.contains(needle)
    }
}

enum NoteFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case archived

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return L10n.tr("Todas")
        case .active: return L10n.tr("Ativas")
        case .archived: return L10n.tr("Arquivadas")
        }
    }
}
