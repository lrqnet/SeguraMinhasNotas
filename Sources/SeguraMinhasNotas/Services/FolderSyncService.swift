import AppKit
import Foundation

private struct SyncedNoteFile: Codable {
    var format: String = "app.seguraminhasnotas.note"
    var version: Int = 1
    var note: Note
}

@MainActor
final class FolderSyncService: ObservableObject {
    static let shared = FolderSyncService()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncAt: Date?
    @Published var lastError: String?

    private init() {}

    func chooseFolder(settings: AppSettings, completion: (() -> Void)? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.tr("Usar esta pasta")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                settings.syncFolderBookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                settings.syncFolderPath = url.path
                settings.syncEnabled = true
                completion?()
            } catch { self.lastError = error.localizedDescription }
        }
    }

    func sync(store: NoteStore, settings: AppSettings) {
        guard settings.syncEnabled else { return }
        guard let folder = resolveFolder(settings: settings) else {
            lastError = L10n.tr("Escolha novamente a pasta de sincronização.")
            return
        }
        isSyncing = true
        let accessed = folder.startAccessingSecurityScopedResource()
        defer {
            if accessed { folder.stopAccessingSecurityScopedResource() }
            isSyncing = false
        }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var remoteNotes: [Note] = []
            let files = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension.lowercased() == "seguranota" }

            for file in files {
                guard let data = try? Data(contentsOf: file),
                      let envelope = try? JSONDecoder.seguraNotas.decode(SyncedNoteFile.self, from: data),
                      envelope.format == "app.seguraminhasnotas.note" else { continue }
                remoteNotes.append(envelope.note)
            }

            store.mergeSynced(remoteNotes)
            for note in store.notes {
                let file = folder.appendingPathComponent(note.id.uuidString).appendingPathExtension("seguranota")
                let data = try JSONEncoder.seguraNotas.encode(SyncedNoteFile(note: note))
                try data.write(to: file, options: .atomic)
            }
            lastSyncAt = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func resolveFolder(settings: AppSettings) -> URL? {
        guard let data = settings.syncFolderBookmark else { return nil }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if stale {
                settings.syncFolderBookmark = try url.bookmarkData(options: .withSecurityScope)
            }
            return url
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
}
