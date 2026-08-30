import AppKit
import Foundation
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case plainText
    case singleFile
    case archive
    case stickies

    var id: String { rawValue }

    var label: String {
        switch self {
        case .markdown: return L10n.tr("Markdown (um arquivo por nota)")
        case .plainText: return L10n.tr("Texto simples (um arquivo por nota)")
        case .singleFile: return L10n.tr("Um único documento")
        case .archive: return L10n.tr("Arquivo SeguraMinhasNotas (.seguranotas)")
        case .stickies: return L10n.tr("Arquivo portátil (.stickies)")
        }
    }
}

private struct SeguraNotasArchive: Codable {
    var format: String = "app.seguraminhasnotas.archive"
    var version: Int = 2
    var exportedAt: Date = Date()
    var notes: [Note]
}

private enum ImportError: LocalizedError {
    case unsupported
    case empty

    var errorDescription: String? {
        switch self {
        case .unsupported: return L10n.tr("O arquivo não contém notas em um formato reconhecido.")
        case .empty: return L10n.tr("Nenhuma nota foi encontrada para importar.")
        }
    }
}

@MainActor
enum ExportService {
    static func exportNotes(_ notes: [Note], format: ExportFormat, completion: ((Result<URL, Error>) -> Void)? = nil) {
        guard !notes.isEmpty else { return }
        switch format {
        case .markdown, .plainText:
            chooseDirectory { directory in
                guard let directory else { return }
                do {
                    let ext = format == .markdown ? "md" : "txt"
                    for note in notes {
                        let filename = safeFilename(note.displayTitle) + "." + ext
                        let body = format == .markdown
                            ? "# \(note.displayTitle)\n\n\(ChecklistSyntax.markdownText(from: note.body))\n"
                            : "\(note.displayTitle)\n\n\(note.body)\n"
                        try body.write(to: directory.appendingPathComponent(filename), atomically: true, encoding: .utf8)
                    }
                    completion?(.success(directory))
                } catch { completion?(.failure(error)) }
            }
        case .singleFile:
            let panel = NSSavePanel()
            panel.nameFieldStringValue = L10n.tr("Notas do SeguraMinhasNotas.md")
            panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    let document = notes.map {
                        "# \($0.displayTitle)\n\n\(ChecklistSyntax.markdownText(from: $0.body))"
                    }.joined(separator: "\n\n---\n\n")
                    try document.write(to: url, atomically: true, encoding: .utf8)
                    completion?(.success(url))
                } catch { completion?(.failure(error)) }
            }
        case .archive, .stickies:
            let ext = format == .archive ? "seguranotas" : "stickies"
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "SeguraMinhasNotas.\(ext)"
            panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .json]
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    var archive = SeguraNotasArchive(notes: notes)
                    if format == .stickies { archive.format = "app.seguraminhasnotas.stickies" }
                    let data = try JSONEncoder.seguraNotas.encode(archive)
                    try data.write(to: url, options: .atomic)
                    completion?(.success(url))
                } catch { completion?(.failure(error)) }
            }
        }
    }

    static func importArchive(completion: @escaping (Result<[Note], Error>) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = L10n.tr("Importar")
        panel.message = L10n.tr("Escolha .seguranotas, .stickies, Markdown, texto, RTF ou pacotes RTFD do Stickies.")
        panel.allowedContentTypes = [
            UTType(filenameExtension: "seguranotas") ?? .json,
            UTType(filenameExtension: "stickies") ?? .data,
            .rtf,
            .rtfd,
            UTType(filenameExtension: "md") ?? .plainText,
            .plainText,
            .folder
        ]
        panel.begin { response in
            guard response == .OK else { return }
            do {
                let notes = try panel.urls.flatMap(importNotes(from:))
                guard !notes.isEmpty else { throw ImportError.empty }
                completion(.success(notes))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func importNotes(from url: URL) throws -> [Note] {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if isDirectory.boolValue && url.pathExtension.lowercased() != "rtfd" {
            let children = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            return try children
                .filter { ["rtfd", "rtf", "txt", "md", "stickies", "seguranotas"].contains($0.pathExtension.lowercased()) }
                .flatMap(importNotes(from:))
        }

        let ext = url.pathExtension.lowercased()
        if ext == "rtfd" || ext == "rtf" {
            return [try noteFromRichText(at: url)]
        }

        let data = try Data(contentsOf: url)
        if let archive = try? JSONDecoder.seguraNotas.decode(SeguraNotasArchive.self, from: data),
           ["app.seguraminhasnotas.archive", "app.seguraminhasnotas.stickies"].contains(archive.format) {
            return archive.notes
        }
        if ext == "stickies" {
            let notes = notesFromStructuredData(data)
            if !notes.isEmpty { return notes }
        }
        if ["md", "markdown", "txt", "text"].contains(ext) || String(data: data, encoding: .utf8) != nil {
            let text = String(decoding: data, as: UTF8.self)
            return [Note(
                title: url.deletingPathExtension().lastPathComponent,
                body: ChecklistSyntax.editorText(from: text)
            )]
        }
        throw ImportError.unsupported
    }

    private static func noteFromRichText(at url: URL) throws -> Note {
        let type: NSAttributedString.DocumentType = url.pathExtension.lowercased() == "rtfd" ? .rtfd : .rtf
        let attributed = try NSAttributedString(
            url: url,
            options: [.documentType: type],
            documentAttributes: nil
        )
        let body = attributed.string.trimmingCharacters(in: .newlines)
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let title = body.components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            .map { String($0.prefix(80)) }
            ?? url.deletingPathExtension().lastPathComponent
        var color = NoteColor.sun
        if attributed.length > 0,
           let background = attributed.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor {
            color = nearestColor(to: background)
        }
        return Note(
            title: title,
            body: ChecklistSyntax.editorText(from: body),
            color: color,
            createdAt: values?.creationDate ?? Date(),
            updatedAt: values?.contentModificationDate ?? Date()
        )
    }

    private static func notesFromStructuredData(_ data: Data) -> [Note] {
        let root: Any?
        if let json = try? JSONSerialization.jsonObject(with: data) {
            root = json
        } else {
            root = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        }
        guard let root else { return [] }
        let objects: [[String: Any]]
        if let dictionary = root as? [String: Any], let notes = dictionary["notes"] as? [[String: Any]] {
            objects = notes
        } else if let notes = root as? [[String: Any]] {
            objects = notes
        } else {
            return []
        }

        return objects.compactMap { object in
            let body = firstString(in: object, keys: ["body", "text", "content", "plainText"]) ?? ""
            let title = firstString(in: object, keys: ["title", "name"])
                ?? body.components(separatedBy: .newlines).first
            ?? L10n.tr("Nota importada")
            let colorName = firstString(in: object, keys: ["color", "colour"])
            let createdAt = firstDate(in: object, keys: ["createdAt", "created", "creationDate"]) ?? Date()
            let updatedAt = firstDate(in: object, keys: ["updatedAt", "modified", "modificationDate"]) ?? createdAt
            return Note(
                title: title,
                body: ChecklistSyntax.editorText(from: body),
                color: noteColor(named: colorName),
                isArchived: (object["isArchived"] as? Bool) ?? false,
                sortOrder: (object["sortOrder"] as? Double) ?? 0,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    private static func firstString(in object: [String: Any], keys: [String]) -> String? {
        keys.lazy.compactMap { object[$0] as? String }.first
    }

    private static func firstDate(in object: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            if let date = object[key] as? Date { return date }
            if let seconds = object[key] as? Double { return Date(timeIntervalSince1970: seconds) }
            if let seconds = object[key] as? Int { return Date(timeIntervalSince1970: Double(seconds)) }
            if let string = object[key] as? String, let date = ISO8601DateFormatter().date(from: string) { return date }
        }
        return nil
    }

    private static func noteColor(named name: String?) -> NoteColor {
        switch name?.lowercased() {
        case "red", "orange", "coral": return .coral
        case "green", "mint": return .mint
        case "blue", "sky": return .sky
        case "purple", "lilac": return .lilac
        default: return .sun
        }
    }

    private static func nearestColor(to color: NSColor) -> NoteColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return .sun }
        return NoteColor.allCases.min { lhs, rhs in
            distance(rgb, lhs.nsColor) < distance(rgb, rhs.nsColor)
        } ?? .sun
    }

    private static func distance(_ lhs: NSColor, _ rhs: NSColor) -> CGFloat {
        let rhs = rhs.usingColorSpace(.sRGB) ?? rhs
        return pow(lhs.redComponent - rhs.redComponent, 2)
            + pow(lhs.greenComponent - rhs.greenComponent, 2)
            + pow(lhs.blueComponent - rhs.blueComponent, 2)
    }

    private static func chooseDirectory(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.tr("Exportar")
        panel.begin { response in completion(response == .OK ? panel.url : nil) }
    }

    private static func safeFilename(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = title.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? L10n.tr("Nota") : String(cleaned.prefix(96))
    }
}
