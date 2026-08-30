import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class DeckCoordinator {
    private let store: NoteStore
    private let settings: AppSettings
    private var panels: [String: DeckPanelController] = [:]
    private let editorManager: EditorWindowManager
    private let allNotesController: AllNotesWindowController
    private let settingsController: SettingsWindowController
    private let onboardingController: OnboardingWindowController
    private var settingsCancellable: AnyCancellable?

    init(store: NoteStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        editorManager = EditorWindowManager(store: store, settings: settings)
        allNotesController = AllNotesWindowController(store: store, settings: settings)
        settingsController = SettingsWindowController(store: store, settings: settings)
        onboardingController = OnboardingWindowController(settings: settings)

        editorManager.onShowAll = { [weak self] filter in self?.showAllNotes(filter: filter) }
        allNotesController.onOpenNote = { [weak self] id in self?.openNote(id: id) }
        store.onOpenNote = { [weak self] id in self?.openNote(id: id) }
        store.onNotesChanged = { [weak self] in
            self?.refreshPanelFrames()
            self?.editorManager.closeUnavailableEditors()
        }
        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.settingsDidChange() }
        }
    }

    func start() {
        refreshScreens()
        editorManager.restorePinnedNotes()
    }

    func refreshScreens() {
        let currentKeys = Set(NSScreen.screens.map(screenKey))
        let staleKeys = panels.keys.filter { !currentKeys.contains($0) }
        for key in staleKeys {
            panels.removeValue(forKey: key)?.close()
        }

        for screen in NSScreen.screens {
            let key = screenKey(screen)
            if let panel = panels[key] {
                panel.update(screen: screen)
            } else {
                let panel = DeckPanelController(
                    screen: screen,
                    store: store,
                    settings: settings,
                    onOpen: { [weak self] id in self?.openNote(id: id) },
                    onShowAll: { [weak self] filter in self?.showAllNotes(filter: filter) },
                    onShowSettings: { [weak self] in self?.showSettings() }
                )
                panels[key] = panel
                panel.show()
            }
        }
    }

    func refreshPanelFrames() {
        panels.values.forEach { $0.refreshFrame(animated: true) }
    }

    func openNote(id: UUID) {
        guard store.note(id: id)?.isArchived == false else { return }
        if settings.requireAuthentication && !AuthenticationService.shared.isUnlocked {
            AuthenticationService.shared.unlock { [weak self] success in
                if success { self?.openNote(id: id) }
            }
            return
        }
        editorManager.open(id: id)
    }

    func createNote() {
        _ = store.addNote(open: true)
    }

    func showAllNotes(filter: NoteFilter = .all) {
        allNotesController.show(filter: filter)
    }

    func showSettings() {
        settingsController.show()
    }

    func showOnboardingIfNeeded() {
        guard !settings.onboardingComplete else { return }
        onboardingController.show { [weak self] in
            self?.settings.onboardingComplete = true
            self?.onboardingController.close()
            self?.createNoteIfWelcomeIsMissing()
        }
    }

    func prepareScreenshot(scenario: String) {
        switch scenario {
        case "editor":
            if let id = store.visibleNotes.first?.id { openNote(id: id) }
        case "all-notes", "locked":
            showAllNotes(filter: .all)
        case let value where value.hasPrefix("settings-"):
            showSettings()
        default:
            break
        }
    }

    private func createNoteIfWelcomeIsMissing() {
        if store.liveNotes.isEmpty { _ = store.addNote() }
    }

    private func settingsDidChange() {
        panels.values.forEach { $0.settingsDidChange() }
    }

    private func screenKey(_ screen: NSScreen) -> String {
        "\(screen.localizedName)-\(Int(screen.frame.origin.x))-\(Int(screen.frame.origin.y))-\(Int(screen.frame.width))-\(Int(screen.frame.height))"
    }
}

private final class EdgePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class DeckPanelController: NSWindowController {
    private var targetScreen: NSScreen
    private let store: NoteStore
    private let settings: AppSettings
    private var fanned = false
    private let panelWidth: CGFloat = 340

    init(
        screen: NSScreen,
        store: NoteStore,
        settings: AppSettings,
        onOpen: @escaping (UUID) -> Void,
        onShowAll: @escaping (NoteFilter) -> Void,
        onShowSettings: @escaping () -> Void
    ) {
        targetScreen = screen
        self.store = store
        self.settings = settings

        let panel = EdgePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = false

        super.init(window: panel)

        let root = DeckView(
            store: store,
            settings: settings,
            onOpen: onOpen,
            onShowAll: onShowAll,
            onShowSettings: onShowSettings,
            onFanChanged: { [weak self] value in
                self?.fanned = value
                self?.refreshFrame(animated: true)
            }
        )
        panel.contentView = NSHostingView(rootView: root)
        applyCollectionBehavior()
        refreshFrame(animated: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        window?.orderFrontRegardless()
    }

    func update(screen: NSScreen) {
        targetScreen = screen
        refreshFrame(animated: false)
    }

    func settingsDidChange() {
        applyCollectionBehavior()
        if settings.keepDeckOpen { fanned = true }
        refreshFrame(animated: true)
    }

    func refreshFrame(animated: Bool) {
        guard let window else { return }
        let count = max(1, min(store.visibleNotes.count, 8))
        let height = min(max(CGFloat(count) * 76 + 72, 170), targetScreen.visibleFrame.height - 80)
        let visibleWidth: CGFloat = (fanned || settings.keepDeckOpen) ? 126 : 17
        let frame = targetScreen.frame
        let x: CGFloat
        if settings.deckSide == .right {
            x = frame.maxX - visibleWidth
        } else {
            x = frame.minX - panelWidth + visibleWidth
        }
        let y = min(max(targetScreen.visibleFrame.midY - height / 2, targetScreen.visibleFrame.minY + 20), targetScreen.visibleFrame.maxY - height - 20)
        let target = NSRect(x: x, y: y, width: panelWidth, height: height)

        guard animated else {
            window.setFrame(target, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = settings.motionSpeed.duration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.88, 0.3, 1)
            window.animator().setFrame(target, display: true)
        }
    }

    private func applyCollectionBehavior() {
        guard let window else { return }
        if settings.showOverFullScreen {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        } else {
            window.collectionBehavior = [.moveToActiveSpace, .stationary]
        }
    }
}

private final class StickyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class EditorWindowManager: NSObject, NSWindowDelegate {
    private let store: NoteStore
    private let settings: AppSettings
    private var controllers: [UUID: NSWindowController] = [:]
    var onShowAll: ((NoteFilter) -> Void)?

    init(store: NoteStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    func open(id: UUID) {
        guard let note = store.note(id: id), !note.isArchived else { return }
        if let existing = controllers[id]?.window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = StickyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 360),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = settings.showOverFullScreen ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.moveToActiveSpace]
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 330, height: 280)
        panel.maxSize = NSSize(width: 680, height: 820)
        panel.delegate = self
        panel.identifier = NSUserInterfaceItemIdentifier(id.uuidString)

        let controller = NSWindowController(window: panel)
        controllers[id] = controller
        let root = EditorView(store: store, settings: settings, note: note) { [weak self] in
            self?.close(id: id)
        }
        panel.contentView = NSHostingView(rootView: root)

        if let storedFrame = UserDefaults.standard.string(forKey: "lastEditorFrame") {
            panel.setFrame(NSRectFromString(storedFrame), display: false)
        } else {
            position(panel, beside: NSScreen.main ?? NSScreen.screens[0])
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close(id: UUID) {
        guard let controller = controllers.removeValue(forKey: id) else { return }
        if let frame = controller.window?.frame { UserDefaults.standard.set(NSStringFromRect(frame), forKey: "lastEditorFrame") }
        controller.window?.orderOut(nil)
        controller.close()
    }

    func closeUnavailableEditors() {
        let ids = controllers.keys.filter { id in
            guard let note = store.note(id: id) else { return true }
            return note.isArchived
        }
        ids.forEach(close)
    }

    func restorePinnedNotes() {
        store.visibleNotes.filter(\.isPinned).forEach { open(id: $0.id) }
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: "lastEditorFrame")
    }

    private func position(_ panel: NSPanel, beside screen: NSScreen) {
        let visible = screen.visibleFrame
        let x = settings.deckSide == .right ? visible.maxX - panel.frame.width - 46 : visible.minX + 46
        let y = visible.midY - panel.frame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

@MainActor
private final class AllNotesWindowController: NSWindowController {
    private let store: NoteStore
    private let settings: AppSettings
    var onOpenNote: ((UUID) -> Void)?

    init(store: NoteStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 680),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("Todas as notas")
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 860, height: 520)
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(filter: NoteFilter) {
        guard let window else { return }
        window.contentView = NSHostingView(rootView: AllNotesView(
            store: store,
            initialFilter: filter,
            onOpen: { [weak self] id in self?.onOpenNote?(id) }
        ))
        window.center()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
private final class SettingsWindowController: NSWindowController {
    init(store: NoteStore, settings: AppSettings) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("Ajustes do SeguraMinhasNotas")
        window.titlebarAppearsTransparent = true
        window.contentView = NSHostingView(rootView: SettingsView(settings: settings, store: store))
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
private final class OnboardingWindowController: NSWindowController {
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(onFinish: @escaping () -> Void) {
        window?.contentView = NSHostingView(rootView: OnboardingView(onFinish: onFinish))
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
