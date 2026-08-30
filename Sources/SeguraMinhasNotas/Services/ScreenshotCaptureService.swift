import AppKit
import Foundation

@MainActor
enum ScreenshotCaptureService {
    static func captureWhenReady(scenario: String) {
        guard let outputPath = ProcessInfo.processInfo.environment["SMN_SCREENSHOT_OUTPUT"] else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard let window = window(for: scenario), let frameView = window.contentView?.superview else {
                fputs("Não foi possível encontrar a janela do cenário \(scenario).\n", stderr)
                NSApp.terminate(nil)
                return
            }

            window.displayIfNeeded()
            frameView.displayIfNeeded()
            let bounds = frameView.bounds
            guard let representation = frameView.bitmapImageRepForCachingDisplay(in: bounds) else {
                fputs("Não foi possível criar a representação da janela.\n", stderr)
                NSApp.terminate(nil)
                return
            }

            frameView.cacheDisplay(in: bounds, to: representation)
            guard let rawData = representation.representation(using: .png, properties: [:]),
                  let data = sanitizedPNG(rawData) else {
                fputs("Não foi possível codificar o PNG.\n", stderr)
                NSApp.terminate(nil)
                return
            }

            do {
                let url = URL(fileURLWithPath: outputPath)
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: url, options: .atomic)
                print("Screenshot salvo em \(url.path)")
            } catch {
                fputs("Falha ao salvar screenshot: \(error.localizedDescription)\n", stderr)
            }
            NSApp.terminate(nil)
        }
    }

    private static func window(for scenario: String) -> NSWindow? {
        switch scenario {
        case "all-notes", "locked":
            return NSApp.windows.first { $0.title == L10n.tr("Todas as notas") }
        case let value where value.hasPrefix("settings-"):
            return NSApp.windows.first { $0.title == L10n.tr("Ajustes do SeguraMinhasNotas") }
        case "editor":
            return NSApp.windows.first { $0.identifier != nil && $0.canBecomeKey && $0.title.isEmpty }
        case "onboarding":
            return NSApp.windows.first { $0.isVisible && $0.frame.width >= 600 && $0.title.isEmpty }
        default:
            return NSApp.windows.first { !$0.canBecomeKey }
        }
    }

    private static func sanitizedPNG(_ data: Data) -> Data? {
        let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        guard data.count >= signature.count, data.prefix(signature.count) == signature else { return nil }

        let metadataChunks: Set<String> = ["eXIf", "tEXt", "zTXt", "iTXt", "tIME", "iCCP"]
        var output = signature
        var offset = signature.count

        while offset + 12 <= data.count {
            let lengthBytes = data[offset..<(offset + 4)]
            let length = lengthBytes.reduce(0) { ($0 << 8) | Int($1) }
            let chunkSize = 12 + length
            guard chunkSize >= 12, offset + chunkSize <= data.count else { return nil }

            let typeData = data[(offset + 4)..<(offset + 8)]
            guard let type = String(data: typeData, encoding: .ascii) else { return nil }
            if !metadataChunks.contains(type) {
                output.append(data[offset..<(offset + chunkSize)])
            }

            offset += chunkSize
            if type == "IEND" { return output }
        }

        return nil
    }
}
