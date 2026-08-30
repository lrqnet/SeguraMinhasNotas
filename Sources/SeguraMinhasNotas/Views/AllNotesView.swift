import SwiftUI

struct AllNotesView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var authentication = AuthenticationService.shared
    let initialFilter: NoteFilter
    let onOpen: (UUID) -> Void

    @State private var filter: NoteFilter
    @State private var search = ""
    @State private var selectedID: UUID?
    @State private var checked = Set<UUID>()
    @State private var exportFormat: ExportFormat = .markdown
    @State private var operationMessage: String?

    init(store: NoteStore, initialFilter: NoteFilter, onOpen: @escaping (UUID) -> Void) {
        self.store = store
        self.initialFilter = initialFilter
        self.onOpen = onOpen
        _filter = State(initialValue: initialFilter)
    }

    private var filteredNotes: [Note] {
        store.liveNotes
            .filter { note in
                switch filter {
                case .all: return true
                case .active: return !note.isArchived
                case .archived: return note.isArchived
                }
            }
            .filter { $0.matches(search) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var selectedNote: Note? {
        guard let selectedID else { return filteredNotes.first }
        return store.note(id: selectedID)
    }

    private var contentLocked: Bool {
        (store.isScreenLocked && settings.hideOnLock) || (settings.requireAuthentication && !authentication.isUnlocked)
    }

    var body: some View {
        Group {
            if contentLocked {
                ProtectedContentView()
            } else {
                HSplitView {
                    sidebar.frame(minWidth: 420, idealWidth: 470)
                    preview.frame(minWidth: 430)
                }
            }
        }
        .background(SeguraNotasStyle.canvas)
        .overlay(alignment: .bottom) { undoToast }
        .onAppear {
            selectedID = filteredNotes.first?.id
            if AppRuntime.isScreenshotMode {
                checked = Set(filteredNotes.prefix(3).map(\.id))
            }
        }
        .alert(L10n.tr("SeguraMinhasNotas"), isPresented: Binding(
            get: { operationMessage != nil },
            set: { if !$0 { operationMessage = nil } }
        )) {
            Button(L10n.tr("OK"), role: .cancel) { operationMessage = nil }
        } message: {
            Text(operationMessage ?? "")
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.tr("Todas as notas"))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Spacer()
                Button(L10n.tr("Importar…"), systemImage: "square.and.arrow.down") { importNotes() }
                    .buttonStyle(SeguraNotasButtonStyle())
            }
            .padding(20)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(L10n.tr("Buscar em títulos, textos e tags"), text: $search)
                    .textFieldStyle(.plain)
                Text("\(filteredNotes.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(Color.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .padding(.horizontal, 20)

            Picker(L10n.tr("Filtro"), selection: $filter) {
                ForEach(NoteFilter.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(20)

            Divider()

            if filteredNotes.isEmpty {
                emptyState(
                    title: L10n.tr(search.isEmpty ? "Nenhuma nota" : "Nada encontrado"),
                    icon: search.isEmpty ? "note.text" : "magnifyingglass",
                    detail: L10n.tr(search.isEmpty ? "Crie uma nota na borda da tela." : "Tente outro termo de busca.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredNotes) { note in
                            row(note)
                        }
                    }
                    .padding(10)
                }
            }

            Divider()
            HStack {
                Text(checked.isEmpty
                    ? L10n.tr("Selecione notas para exportar")
                    : L10n.format(checked.count == 1 ? "%d nota selecionada" : "%d notas selecionadas", checked.count)
                )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu(L10n.tr("Exportar")) {
                    ForEach(ExportFormat.allCases) { format in
                        Button(format.label) { export(format: format) }
                    }
                }
                .disabled(checked.isEmpty)
            }
            .padding(14)
        }
    }

    private func row(_ note: Note) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { checked.contains(note.id) },
                set: { value in
                    if value { checked.insert(note.id) }
                    else { checked.remove(note.id) }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            RoundedRectangle(cornerRadius: 3)
                .fill(note.color.color)
                .frame(width: 6, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.displayTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(L10n.tr(note.isArchived ? "ARQUIVADA" : "ATIVA"))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.7)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.06), in: Capsule())
                    Text(note.updatedAt.seguraNotasRelative)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Text(note.bodyPreview.isEmpty ? L10n.tr("Sem conteúdo") : note.bodyPreview)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(selectedNote?.id == note.id ? Color.primary.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture { selectedID = note.id }
        .onTapGesture(count: 2) { onOpen(note.id) }
    }

    @ViewBuilder
    private var preview: some View {
        if let note = selectedNote {
            VStack(spacing: 20) {
                HStack {
                    Circle().fill(note.color.color).frame(width: 11, height: 11)
                    Text(L10n.tr(note.isArchived ? "ARQUIVADA" : "ATIVA · NA BORDA"))
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Spacer()

                    Button(L10n.tr("Abrir"), systemImage: "arrow.up.left.and.arrow.down.right") { onOpen(note.id) }
                        .buttonStyle(SeguraNotasButtonStyle())
                    Button(L10n.tr(note.isArchived ? "Restaurar" : "Arquivar")) {
                        note.isArchived ? store.restore(id: note.id) : store.archive(id: note.id)
                    }
                    .buttonStyle(SeguraNotasButtonStyle())
                    Button(L10n.tr("Apagar"), role: .destructive) { store.delete(id: note.id) }
                        .buttonStyle(SeguraNotasButtonStyle())
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(note.displayTitle)
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(SeguraNotasStyle.ink)
                        Spacer()
                        Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    ScrollView {
                        Text(note.body.isEmpty ? L10n.tr("Esta nota está vazia.") : note.body)
                            .font(AppSettings.shared.font.swiftUIFont(size: AppSettings.shared.fontSize))
                            .foregroundStyle(note.body.isEmpty ? .secondary : SeguraNotasStyle.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }

                    if !note.tags.isEmpty {
                        HStack {
                            ForEach(note.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.06), in: Capsule())
                            }
                        }
                    }

                    Divider().opacity(0.25)
                    Text(L10n.format(
                        "Criada em %@ · atualizada %@",
                        note.createdAt.formatted(date: .abbreviated, time: .shortened) as NSString,
                        note.updatedAt.seguraNotasRelative as NSString
                    ))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(note.color.color.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 20, y: 8)
            }
            .padding(22)
        } else {
            emptyState(
                title: L10n.tr("Selecione uma nota"),
                icon: "note.text",
                detail: L10n.tr("Escolha uma nota na lista para ver a prévia.")
            )
        }
    }

    @ViewBuilder
    private var undoToast: some View {
        if let title = store.lastDeletedTitle {
            HStack(spacing: 12) {
                Text(L10n.format("“%@” foi apagada", title as NSString))
                Button(L10n.tr("Desfazer")) { store.undoDelete() }
                    .fontWeight(.bold)
                    .buttonStyle(.plain)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .shadow(radius: 12)
            .padding(.bottom, 18)
        }
    }

    private func export(format: ExportFormat) {
        let notes = store.liveNotes.filter { checked.contains($0.id) }
        ExportService.exportNotes(notes, format: format) { result in
            if case .failure(let error) = result { operationMessage = error.localizedDescription }
        }
    }

    private func importNotes() {
        ExportService.importArchive { result in
            switch result {
            case .success(let notes):
                store.mergeSynced(notes)
                operationMessage = L10n.format(
                    notes.count == 1 ? "%d nota importada." : "%d notas importadas.",
                    notes.count
                )
            case .failure(let error): operationMessage = error.localizedDescription
            }
        }
    }

    private func emptyState(title: String, icon: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
            Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
