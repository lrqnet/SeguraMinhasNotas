import Combine
import Foundation

@MainActor
final class NoteStore: ObservableObject {
    static let shared = NoteStore()

    @Published private(set) var notes: [Note] = []
    @Published var lastError: String?
    @Published var lastDeletedTitle: String?
    @Published var isScreenLocked = false

    var onOpenNote: ((UUID) -> Void)?
    var onNotesChanged: (() -> Void)?

    private lazy var persistence = EncryptedPersistence.shared
    private let persistenceQueue = DispatchQueue(label: "app.seguraminhasnotas.persistence", qos: .utility)
    private let isEphemeral = AppRuntime.isScreenshotMode
    private var lastDeletedID: UUID?
    private var saveGeneration = 0

    private init() {
        if isEphemeral {
            notes = Self.screenshotNotes()
            return
        }

        do {
            notes = try persistence.load()
        } catch {
            lastError = error.localizedDescription
        }

        if notes.isEmpty {
            notes = [Note(
                title: L10n.tr("Bem-vindo ao SeguraMinhasNotas"),
                body: L10n.tr("Leve o cursor até a borda da tela.\n\n☐ Clique em uma aba para escrever\n☐ Arraste para reorganizar\n☐ Use ⌥⌘N para criar uma nota"),
                tags: [L10n.tr("começar")],
                color: .sky,
                sortOrder: 0
            )]
            persist()
        }
    }

    var visibleNotes: [Note] {
        notes
            .filter { $0.deletedAt == nil && !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var archivedNotes: [Note] {
        notes
            .filter { $0.deletedAt == nil && $0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var liveNotes: [Note] {
        notes.filter { $0.deletedAt == nil }
    }

    @discardableResult
    func addNote(open: Bool = true) -> Note {
        let order = (visibleNotes.map(\.sortOrder).max() ?? -1) + 1
        let color = NoteColor.allCases[notes.count % NoteColor.allCases.count]
        let note = Note(color: color, sortOrder: order)
        notes.append(note)
        changed()
        if open { onOpenNote?(note.id) }
        return note
    }

    func note(id: UUID) -> Note? {
        notes.first { $0.id == id && $0.deletedAt == nil }
    }

    func update(id: UUID, title: String? = nil, body: String? = nil, tags: [String]? = nil) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        if let title { notes[index].title = title }
        if let body { notes[index].body = body }
        if let tags { notes[index].tags = tags }
        notes[index].updatedAt = Date()
        changed()
    }

    func setColor(id: UUID, color: NoteColor) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].color = color
        notes[index].updatedAt = Date()
        changed()
    }

    func cycleColor(id: UUID) {
        guard let note = note(id: id), let current = NoteColor.allCases.firstIndex(of: note.color) else { return }
        setColor(id: id, color: NoteColor.allCases[(current + 1) % NoteColor.allCases.count])
    }

    func togglePinned(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isPinned.toggle()
        notes[index].updatedAt = Date()
        changed()
    }

    func archive(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isArchived = true
        notes[index].isPinned = false
        notes[index].updatedAt = Date()
        changed()
    }

    func restore(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isArchived = false
        notes[index].sortOrder = (visibleNotes.map(\.sortOrder).max() ?? -1) + 1
        notes[index].updatedAt = Date()
        changed()
    }

    func delete(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        lastDeletedID = id
        lastDeletedTitle = notes[index].displayTitle
        notes[index].deletedAt = Date()
        notes[index].isPinned = false
        notes[index].updatedAt = Date()
        changed()
        let capturedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard self?.lastDeletedID == capturedID else { return }
            self?.lastDeletedID = nil
            self?.lastDeletedTitle = nil
        }
    }

    func undoDelete() {
        guard let id = lastDeletedID, let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].deletedAt = nil
        notes[index].updatedAt = Date()
        lastDeletedID = nil
        lastDeletedTitle = nil
        changed()
    }

    func moveVisible(from source: IndexSet, to destination: Int) {
        var ordered = visibleNotes
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, note) in ordered.enumerated() {
            if let storageIndex = notes.firstIndex(where: { $0.id == note.id }) {
                notes[storageIndex].sortOrder = Double(index)
            }
        }
        changed()
    }

    func moveVisible(noteID: UUID, before destinationID: UUID) {
        var ordered = visibleNotes
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == noteID }),
              sourceIndex != ordered.firstIndex(where: { $0.id == destinationID }) else { return }
        let moving = ordered.remove(at: sourceIndex)
        guard let destinationIndex = ordered.firstIndex(where: { $0.id == destinationID }) else { return }
        ordered.insert(moving, at: destinationIndex)
        for (index, note) in ordered.enumerated() {
            if let storageIndex = notes.firstIndex(where: { $0.id == note.id }) {
                notes[storageIndex].sortOrder = Double(index)
                if note.id == noteID { notes[storageIndex].updatedAt = Date() }
            }
        }
        changed()
    }

    func mergeSynced(_ incoming: [Note]) {
        for remote in incoming {
            if let index = notes.firstIndex(where: { $0.id == remote.id }) {
                if remote.updatedAt > notes[index].updatedAt { notes[index] = remote }
            } else {
                notes.append(remote)
            }
        }
        changed()
    }

    func flush() {
        guard !isEphemeral else { return }
        do { try persistence.save(notes) }
        catch { lastError = error.localizedDescription }
    }

    private func changed() {
        saveGeneration += 1
        persist()
        onNotesChanged?()
    }

    private func persist() {
        guard !isEphemeral else { return }
        let snapshot = notes
        let generation = saveGeneration
        persistenceQueue.async { [weak self] in
            do {
                try EncryptedPersistence.shared.save(snapshot)
                DispatchQueue.main.async {
                    guard let self, generation == self.saveGeneration else { return }
                    self.lastError = nil
                }
            } catch {
                DispatchQueue.main.async { [weak self] in self?.lastError = error.localizedDescription }
            }
        }
    }

    private static func screenshotNotes(now: Date = Date()) -> [Note] {
        [
            Note(
                id: UUID(uuidString: "B9D68C93-BE64-40C8-BF3D-37FCD348CBF1")!,
                title: L10n.tr("Planejamento da semana"),
                body: L10n.tr("☑ Revisar prioridades\n☐ Preparar apresentação\n☐ Organizar próximas entregas\n\nFoco: avançar uma tarefa de cada vez."),
                tags: [L10n.tr("trabalho"), L10n.tr("semana")],
                color: .sun,
                sortOrder: 0,
                createdAt: now.addingTimeInterval(-172_800),
                updatedAt: now.addingTimeInterval(-420)
            ),
            Note(
                id: UUID(uuidString: "8D83E82D-5902-4550-93F8-B91B31D1F578")!,
                title: L10n.tr("Ideias para o projeto"),
                body: L10n.tr("Simplificar o primeiro acesso\nOrganizar referências em um só lugar\nReservar tempo para revisar detalhes"),
                tags: [L10n.tr("projeto"), L10n.tr("ideias")],
                color: .mint,
                sortOrder: 1,
                createdAt: now.addingTimeInterval(-432_000),
                updatedAt: now.addingTimeInterval(-3_600)
            ),
            Note(
                id: UUID(uuidString: "910C9BDC-C9A0-4EB8-8143-B4613ED67BF5")!,
                title: L10n.tr("Lista de compras"),
                body: L10n.tr("☑ Café\n☐ Frutas\n☐ Pão de queijo\n☐ Flores para a sala"),
                tags: [L10n.tr("casa")],
                color: .coral,
                sortOrder: 2,
                createdAt: now.addingTimeInterval(-86_400),
                updatedAt: now.addingTimeInterval(-7_200)
            ),
            Note(
                id: UUID(uuidString: "A23F8BE2-63AD-4D3A-BC9F-EF955F333CD7")!,
                title: L10n.tr("Leituras para depois"),
                body: "Designing Interfaces\nThe Humane Interface\nMacOS Human Interface Guidelines",
                tags: [L10n.tr("leitura"), "design"],
                color: .sky,
                sortOrder: 3,
                createdAt: now.addingTimeInterval(-691_200),
                updatedAt: now.addingTimeInterval(-28_800)
            ),
            Note(
                id: UUID(uuidString: "0384945C-9525-430D-8900-B41B1BD71C62")!,
                title: L10n.tr("Viagem de fim de semana"),
                body: L10n.tr("☑ Reservar hospedagem\n☐ Separar documentos\n☐ Montar roteiro\n☐ Conferir a previsão do tempo"),
                tags: [L10n.tr("viagem"), L10n.tr("planejamento")],
                color: .lilac,
                sortOrder: 4,
                createdAt: now.addingTimeInterval(-1_209_600),
                updatedAt: now.addingTimeInterval(-43_200)
            ),
            Note(
                id: UUID(uuidString: "274AF29D-9F7A-457D-B29B-38421B2D87AB")!,
                title: L10n.tr("Referências visuais"),
                body: L10n.tr("Paleta de cores\nTipografia\nComposição\nFotografia"),
                tags: ["design"],
                color: .mint,
                isArchived: true,
                sortOrder: 5,
                createdAt: now.addingTimeInterval(-1_555_200),
                updatedAt: now.addingTimeInterval(-172_800)
            )
        ]
    }
}
