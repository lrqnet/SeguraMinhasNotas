import CryptoKit
import Foundation
import Security

enum PersistenceError: LocalizedError {
    case keychain(OSStatus)
    case malformedCiphertext

    var errorDescription: String? {
        switch self {
        case .keychain(let status): return L10n.format("Não foi possível acessar a chave local (código %d).", status)
        case .malformedCiphertext: return L10n.tr("O arquivo de notas está corrompido ou pertence a outra instalação.")
        }
    }
}

private struct StoredEnvelope: Codable {
    var version: Int
    var notes: [StoredNote]
}

private struct StoredNote: Codable {
    var id: UUID
    var title: String
    var encryptedBody: Data
    var tags: [String]
    var color: NoteColor
    var isArchived: Bool
    var isPinned: Bool
    var sortOrder: Double
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

final class EncryptedPersistence {
    static let shared = EncryptedPersistence()

    private let service = "app.seguraminhasnotas.notes"
    private let account = "notes-encryption-key-v1"
    private let fileManager = FileManager.default

    var fileURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SeguraMinhasNotas", isDirectory: true)
            .appendingPathComponent("notes.json")
    }

    func load() throws -> [Note] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let envelope = try JSONDecoder.seguraNotas.decode(StoredEnvelope.self, from: data)
        let key = try symmetricKey(service: service)

        let notes = try envelope.notes.map { stored in
            let box = try AES.GCM.SealedBox(combined: stored.encryptedBody)
            let bodyData = try AES.GCM.open(box, using: key)
            guard let body = String(data: bodyData, encoding: .utf8) else {
                throw PersistenceError.malformedCiphertext
            }
            return Note(
                id: stored.id,
                title: stored.title,
                body: body,
                tags: stored.tags,
                color: stored.color,
                isArchived: stored.isArchived,
                isPinned: stored.isPinned,
                sortOrder: stored.sortOrder,
                createdAt: stored.createdAt,
                updatedAt: stored.updatedAt,
                deletedAt: stored.deletedAt
            )
        }
        return notes
    }

    func save(_ notes: [Note]) throws {
        let key = try symmetricKey(service: service)
        let stored = try notes.map { note -> StoredNote in
            let sealed = try AES.GCM.seal(Data(note.body.utf8), using: key)
            guard let combined = sealed.combined else { throw PersistenceError.malformedCiphertext }
            return StoredNote(
                id: note.id,
                title: note.title,
                encryptedBody: combined,
                tags: note.tags,
                color: note.color,
                isArchived: note.isArchived,
                isPinned: note.isPinned,
                sortOrder: note.sortOrder,
                createdAt: note.createdAt,
                updatedAt: note.updatedAt,
                deletedAt: note.deletedAt
            )
        }
        let envelope = StoredEnvelope(version: 1, notes: stored)
        let data = try JSONEncoder.seguraNotas.encode(envelope)
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    private func symmetricKey(service: String) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else { throw PersistenceError.keychain(status) }

        var bytes = [UInt8](repeating: 0, count: 32)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard randomStatus == errSecSuccess else { throw PersistenceError.keychain(randomStatus) }
        let data = Data(bytes)
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw PersistenceError.keychain(addStatus) }
        return SymmetricKey(data: data)
    }
}

extension JSONEncoder {
    static var seguraNotas: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }
}

extension JSONDecoder {
    static var seguraNotas: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
