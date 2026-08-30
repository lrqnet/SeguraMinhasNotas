import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("Falhou: \(message)\n".utf8))
        exit(1)
    }
}

let note = Note(title: "Reunião", body: "Comprar café", tags: ["trabalho"])
expect(note.matches("reuniao"), "busca deve ignorar diacríticos")
expect(note.matches("CAFE"), "busca deve ignorar caixa")
expect(note.matches("trabalho"), "busca deve incluir tags")
expect(!note.matches("viagem"), "busca não deve gerar falso positivo")

let original = Note(
    title: "Plano",
    body: "- [ ] publicar",
    tags: ["projeto"],
    color: .lilac,
    isArchived: true,
    isPinned: false,
    sortOrder: 4,
    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
    updatedAt: Date(timeIntervalSince1970: 1_700_000_123)
)
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .secondsSince1970
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .secondsSince1970
let data = try encoder.encode(original)
let decoded = try decoder.decode(Note.self, from: data)
expect(decoded == original, "round-trip Codable deve preservar a nota")

let editorChecklist = ChecklistSyntax.editorText(from: "- [ ] publicar\n- [x] revisar")
expect(editorChecklist == "☐ publicar\n☑ revisar", "Markdown deve virar checklist visual")
expect(ChecklistSyntax.markdownText(from: editorChecklist) == "- [ ] publicar\n- [x] revisar", "checklist visual deve exportar Markdown")
expect(ChecklistSyntax.toggled("☐ publicar") == "☑ publicar", "item pendente deve ser marcável")
expect(ChecklistSyntax.toggled("☑ publicar") == "☐ publicar", "item concluído deve ser desmarcável")
expect(ChecklistSyntax.content(afterMarkerIn: "☐ publicar") == "publicar", "conteúdo do item deve ser preservado")

func loadCatalog(_ path: String) throws -> [String: String] {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    guard let catalog = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
        throw NSError(domain: "SeguraMinhasNotasChecks", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Catálogo inválido: \(path)"
        ])
    }
    return catalog
}

func formatMarkers(in text: String) -> [String] {
    let expression = try! NSRegularExpression(pattern: #"%(?:\d+\$)?[@d]"#)
    let range = NSRange(text.startIndex..., in: text)
    return expression.matches(in: text, range: range).compactMap { match in
        Range(match.range, in: text).map { String(text[$0]) }
    }
}

let english = try loadCatalog("Resources/en-US.lproj/Localizable.strings")
let spanish = try loadCatalog("Resources/es-CO.lproj/Localizable.strings")
expect(Set(english.keys) == Set(spanish.keys), "catálogos em inglês e espanhol devem conter as mesmas chaves")
expect(english.values.allSatisfy { !$0.isEmpty }, "traduções em inglês não podem estar vazias")
expect(spanish.values.allSatisfy { !$0.isEmpty }, "traduções em espanhol não podem estar vazias")
for key in english.keys {
    expect(formatMarkers(in: key) == formatMarkers(in: english[key]!), "marcadores de formato devem ser preservados em inglês: \(key)")
    expect(formatMarkers(in: key) == formatMarkers(in: spanish[key]!), "marcadores de formato devem ser preservados em espanhol: \(key)")
}

print("SeguraMinhasNotasChecks: 10 verificações funcionais e \(english.count) traduções por idioma passaram")
