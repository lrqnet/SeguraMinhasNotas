import Foundation

enum ChecklistSyntax {
    static let unchecked = "☐ "
    static let checked = "☑ "

    static func editorText(from text: String) -> String {
        text.components(separatedBy: "\n").map { line in
            if line.hasPrefix("- [ ] ") { return unchecked + line.dropFirst(6) }
            if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") { return checked + line.dropFirst(6) }
            return line
        }.joined(separator: "\n")
    }

    static func markdownText(from text: String) -> String {
        text.components(separatedBy: "\n").map { line in
            if line.hasPrefix(unchecked) { return "- [ ] " + line.dropFirst(unchecked.count) }
            if line.hasPrefix(checked) { return "- [x] " + line.dropFirst(checked.count) }
            return line
        }.joined(separator: "\n")
    }

    static func marker(in line: String) -> String? {
        if line.hasPrefix(unchecked) { return unchecked }
        if line.hasPrefix(checked) { return checked }
        if line.hasPrefix("- [ ] ") { return "- [ ] " }
        if line.hasPrefix("- [x] ") { return "- [x] " }
        if line.hasPrefix("- [X] ") { return "- [X] " }
        return nil
    }

    static func toggled(_ line: String) -> String? {
        if line.hasPrefix(unchecked) { return checked + line.dropFirst(unchecked.count) }
        if line.hasPrefix(checked) { return unchecked + line.dropFirst(checked.count) }
        if line.hasPrefix("- [ ] ") { return "- [x] " + line.dropFirst(6) }
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") { return "- [ ] " + line.dropFirst(6) }
        return nil
    }

    static func content(afterMarkerIn line: String) -> String? {
        guard let marker = marker(in: line) else { return nil }
        return String(line.dropFirst(marker.count))
    }
}
