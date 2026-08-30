import SwiftUI

struct EditorView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var settings: AppSettings
    @ObservedObject private var authentication = AuthenticationService.shared
    let noteID: UUID
    let onClose: () -> Void

    @State private var title: String
    @State private var bodyText: String
    @State private var tagsText: String
    @State private var saveTask: Task<Void, Never>?

    init(store: NoteStore, settings: AppSettings, note: Note, onClose: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        noteID = note.id
        self.onClose = onClose
        _title = State(initialValue: note.title)
        _bodyText = State(initialValue: ChecklistSyntax.editorText(from: note.body))
        _tagsText = State(initialValue: note.tags.joined(separator: ", "))
    }

    private var note: Note? { store.note(id: noteID) }
    private var contentLocked: Bool {
        (store.isScreenLocked && settings.hideOnLock) || (settings.requireAuthentication && !authentication.isUnlocked)
    }

    var body: some View {
        ZStack {
            (note?.color.color ?? NoteColor.sun.color)

            if contentLocked {
                lockedOverlay
            } else {
                VStack(spacing: 0) {
                    header
                    Divider().opacity(0.16)
                    editor
                    Divider().opacity(0.16)
                    footer
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 28, y: 12)
        .onChange(of: title) { _ in scheduleSave() }
        .onChange(of: bodyText) { _ in scheduleSave() }
        .onChange(of: tagsText) { _ in scheduleSave() }
        .onDisappear { saveNow() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Circle().fill(Color.red.opacity(0.82)).frame(width: 13, height: 13)
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Fechar nota (⌘W)"))

            TextField(L10n.tr("Título"), text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(SeguraNotasStyle.ink)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SeguraNotasStyle.secondaryInk)
                .help(L10n.tr("Arraste a nota pela barra superior"))

            Button {
                store.togglePinned(id: noteID)
            } label: {
                Image(systemName: note?.isPinned == true ? "pin.fill" : "pin")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(L10n.tr(note?.isPinned == true ? "Desafixar da mesa" : "Fixar na mesa"))
        }
        .padding(.horizontal, 15)
        .frame(height: 48)
    }

    private var editor: some View {
        VStack(spacing: 8) {
            ChecklistTextEditor(
                text: $bodyText,
                font: settings.font.nsFont(size: settings.fontSize),
                textColor: SeguraNotasStyle.nsInk
            )
            .padding(.horizontal, 8)

            TextField(L10n.tr("tags separadas por vírgula"), text: $tagsText)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SeguraNotasStyle.secondaryInk)
                .padding(.horizontal, 16)
                .padding(.bottom, 5)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    let prefix = bodyText.isEmpty || bodyText.hasSuffix("\n") ? "" : "\n"
                    bodyText += prefix + ChecklistSyntax.unchecked
                } label: {
                    Image(systemName: "checklist")
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Adicionar item de checklist"))

                ForEach(NoteColor.allCases) { color in
                    Button { store.setColor(id: noteID, color: color) } label: {
                        ColorDot(noteColor: color, selected: note?.color == color)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(L10n.tr("salva automaticamente"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SeguraNotasStyle.secondaryInk)
            }

            HStack {
                Button(L10n.tr("Arquivar"), systemImage: "archivebox") {
                    saveNow()
                    store.archive(id: noteID)
                    onClose()
                }
                .buttonStyle(SeguraNotasButtonStyle())

                Spacer()

                Button(L10n.tr("Fechar"), action: onClose)
                    .buttonStyle(SeguraNotasButtonStyle(emphasized: true))
                    .keyboardShortcut("w", modifiers: .command)
            }
        }
        .padding(13)
    }

    private var lockedOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.system(size: 28))
            Text(L10n.tr("Conteúdo protegido"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(L10n.tr("Use Touch ID, Apple Watch ou a senha deste Mac."))
                .font(.system(size: 12))
            Button(L10n.tr(authentication.isAuthenticating ? "Autenticando…" : "Desbloquear")) {
                authentication.unlock()
            }
            .buttonStyle(SeguraNotasButtonStyle(emphasized: true))
            .disabled(authentication.isAuthenticating)
            Button(L10n.tr("Fechar"), action: onClose)
                .buttonStyle(.plain)
                .keyboardShortcut("w", modifiers: .command)
        }
        .foregroundStyle(SeguraNotasStyle.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(note?.color.color ?? NoteColor.sun.color)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { saveNow() }
        }
    }

    private func saveNow() {
        saveTask?.cancel()
        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        store.update(id: noteID, title: title, body: bodyText, tags: tags)
    }
}
