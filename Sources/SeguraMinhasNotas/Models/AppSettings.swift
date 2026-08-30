import AppKit
import Combine
import Foundation
import SwiftUI

enum DeckSide: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }
    var label: String { L10n.tr(self == .left ? "Esquerda" : "Direita") }
}

enum FanMode: String, CaseIterable, Identifiable {
    case hover
    case click

    var id: String { rawValue }
    var label: String { L10n.tr(self == .hover ? "Ao passar o cursor" : "Ao clicar") }
}

enum MotionSpeed: String, CaseIterable, Identifiable {
    case quick
    case balanced
    case calm

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quick: return L10n.tr("Rápida")
        case .balanced: return L10n.tr("Equilibrada")
        case .calm: return L10n.tr("Suave")
        }
    }

    var duration: TimeInterval {
        switch self {
        case .quick: return 0.18
        case .balanced: return 0.28
        case .calm: return 0.42
        }
    }
}

enum NoteFont: String, CaseIterable, Identifiable {
    case rounded
    case standard
    case serif
    case mono

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rounded: return L10n.tr("Arredondada")
        case .standard: return L10n.tr("Sistema")
        case .serif: return L10n.tr("Serifada")
        case .mono: return L10n.tr("Monoespaçada")
        }
    }

    func swiftUIFont(size: CGFloat) -> Font {
        switch self {
        case .rounded: return .system(size: size, design: .rounded)
        case .standard: return .system(size: size, design: .default)
        case .serif: return .system(size: size, design: .serif)
        case .mono: return .system(size: size, design: .monospaced)
        }
    }

    func nsFont(size: CGFloat) -> NSFont {
        switch self {
        case .rounded:
            let descriptor = NSFont.systemFont(ofSize: size).fontDescriptor.withDesign(.rounded)
            return descriptor.flatMap { NSFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size)
        case .standard: return .systemFont(ofSize: size)
        case .serif: return NSFont(name: "New York", size: size) ?? .systemFont(ofSize: size)
        case .mono: return .monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let deckSide = "deckSide"
        static let fanMode = "fanMode"
        static let motionSpeed = "motionSpeed"
        static let keepDeckOpen = "keepDeckOpen"
        static let showOverFullScreen = "showOverFullScreen"
        static let hideOnLock = "hideOnLock"
        static let requireAuthentication = "requireAuthentication"
        static let font = "font"
        static let fontSize = "fontSize"
        static let onboardingComplete = "onboardingComplete"
        static let syncEnabled = "syncEnabled"
        static let syncFolderBookmark = "syncFolderBookmark"
        static let syncFolderPath = "syncFolderPath"
    }

    private let defaults: UserDefaults
    private let isEphemeral: Bool

    @Published var deckSide: DeckSide { didSet { save(deckSide.rawValue, Key.deckSide) } }
    @Published var fanMode: FanMode { didSet { save(fanMode.rawValue, Key.fanMode) } }
    @Published var motionSpeed: MotionSpeed { didSet { save(motionSpeed.rawValue, Key.motionSpeed) } }
    @Published var keepDeckOpen: Bool { didSet { save(keepDeckOpen, Key.keepDeckOpen) } }
    @Published var showOverFullScreen: Bool { didSet { save(showOverFullScreen, Key.showOverFullScreen) } }
    @Published var hideOnLock: Bool { didSet { save(hideOnLock, Key.hideOnLock) } }
    @Published var requireAuthentication: Bool { didSet { save(requireAuthentication, Key.requireAuthentication) } }
    @Published var font: NoteFont { didSet { save(font.rawValue, Key.font) } }
    @Published var fontSize: Double { didSet { save(fontSize, Key.fontSize) } }
    @Published var onboardingComplete: Bool { didSet { save(onboardingComplete, Key.onboardingComplete) } }
    @Published var syncEnabled: Bool { didSet { save(syncEnabled, Key.syncEnabled) } }
    @Published var syncFolderPath: String { didSet { save(syncFolderPath, Key.syncFolderPath) } }

    var syncFolderBookmark: Data? {
        get { isEphemeral ? nil : defaults.data(forKey: Key.syncFolderBookmark) }
        set {
            guard !isEphemeral else { return }
            defaults.set(newValue, forKey: Key.syncFolderBookmark)
        }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEphemeral = AppRuntime.isScreenshotMode

        if AppRuntime.isScreenshotMode {
            deckSide = .right
            fanMode = .click
            motionSpeed = .balanced
            keepDeckOpen = AppRuntime.keepsDeckOpenForScreenshot
            showOverFullScreen = true
            hideOnLock = true
            requireAuthentication = AppRuntime.screenshotScenario == "locked"
            font = .rounded
            fontSize = 18
            onboardingComplete = AppRuntime.screenshotScenario != "onboarding"
            syncEnabled = false
            syncFolderPath = ""
        } else {
            deckSide = DeckSide(rawValue: defaults.string(forKey: Key.deckSide) ?? "") ?? .right
            fanMode = FanMode(rawValue: defaults.string(forKey: Key.fanMode) ?? "") ?? .hover
            motionSpeed = MotionSpeed(rawValue: defaults.string(forKey: Key.motionSpeed) ?? "") ?? .balanced
            keepDeckOpen = defaults.bool(forKey: Key.keepDeckOpen)
            showOverFullScreen = defaults.bool(forKey: Key.showOverFullScreen)
            hideOnLock = defaults.object(forKey: Key.hideOnLock) as? Bool ?? true
            requireAuthentication = defaults.bool(forKey: Key.requireAuthentication)
            font = NoteFont(rawValue: defaults.string(forKey: Key.font) ?? "") ?? .rounded
            let savedSize = defaults.double(forKey: Key.fontSize)
            fontSize = savedSize == 0 ? 18 : savedSize
            onboardingComplete = defaults.bool(forKey: Key.onboardingComplete)
            syncEnabled = defaults.bool(forKey: Key.syncEnabled)
            syncFolderPath = defaults.string(forKey: Key.syncFolderPath) ?? ""
        }
    }

    private func save(_ value: Any, _ key: String) {
        guard !isEphemeral else { return }
        defaults.set(value, forKey: key)
    }
}
