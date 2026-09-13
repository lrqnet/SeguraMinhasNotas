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
                    onOpen: { [weak self] id, source in self?.openNote(id: id, from: source) },
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

    func openNote(id: UUID, from source: CGRect? = nil) {
        guard store.note(id: id)?.isArchived == false else { return }
        if settings.requireAuthentication && !AuthenticationService.shared.isUnlocked {
            AuthenticationService.shared.unlock { [weak self] success in
                if success { self?.openNote(id: id, from: source) }
            }
            return
        }
        editorManager.open(id: id, from: source)
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
    private var previewing = false
    private var resizeTask: Task<Void, Never>?

    init(
        screen: NSScreen,
        store: NoteStore,
        settings: AppSettings,
        onOpen: @escaping (UUID, CGRect) -> Void,
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
        panel.acceptsMouseMovedEvents = true

        super.init(window: panel)

        let root = DeckView(
            store: store,
            settings: settings,
            onOpen: { [weak self] id, rect in
                guard let self, let window = self.window else { return }
                let source = DeckLayout.screenRect(rect, window: window.frame, left: settings.deckSide == .left)
                onOpen(id, source.intersection(self.targetScreen.visibleFrame))
            },
            onShowAll: onShowAll,
            onShowSettings: onShowSettings,
            onPresentationChanged: { [weak self] value, preview in
                self?.fanned = value
                self?.previewing = preview
                self?.refreshFrame(animated: true)
            }
        )
        refreshFrame(animated: false)
        let hostingView = NSHostingView(rootView: root)
        hostingView.sizingOptions = []
        let container = NSView(frame: NSRect(origin: .zero, size: panel.frame.size))
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)
        panel.contentView = container
        applyCollectionBehavior()
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
        refreshFrame(animated: true)
    }

    func refreshFrame(animated: Bool) {
        guard let window else { return }
        resizeTask?.cancel()
        let count = max(1, min(store.visibleNotes.count, 8))
        let expanded = fanned || settings.keepDeckOpen
        let height = expanded
            ? DeckLayout.height(count: count, available: targetScreen.visibleFrame.height)
            : DeckLayout.restingHeight(count: store.visibleNotes.prefix(8).count)
        let width = previewing ? DeckLayout.canvasWidth : ((fanned || settings.keepDeckOpen) ? DeckLayout.fannedWidth : DeckLayout.restingWidth)
        let frame = targetScreen.visibleFrame
        let x: CGFloat
        if settings.deckSide == .right {
            x = frame.maxX - DeckLayout.edgeInset - width
        } else {
            x = frame.minX + DeckLayout.edgeInset
        }
        let y = frame.midY - height / 2
        let target = NSRect(x: x, y: y, width: width, height: height)
        guard window.frame != target else { return }

        // Expand the viewport before moving cards. Contract after their spring settles.
        // Its outer edge stays fixed; SwiftUI alone animates the visible content.
        guard animated, width < window.frame.width || height < window.frame.height else {
            window.setFrame(target, display: true)
            return
        }
        let delay = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.13 : settings.motionSpeed.duration + 0.4
        resizeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.window?.setFrame(target, display: true)
        }
    }

    override func close() {
        resizeTask?.cancel()
        super.close()
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

    func open(id: UUID, from source: CGRect? = nil) {
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
        panel.hasShadow = true
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

        if let source {
            let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: source.midX, y: source.midY)) } ?? NSScreen.main ?? NSScreen.screens[0]
            let safeFrame = screen.visibleFrame.insetBy(dx: 24, dy: 24)
            let x = settings.deckSide == .right ? source.maxX - panel.frame.width : source.minX
            panel.setFrameOrigin(NSPoint(
                x: min(max(x, safeFrame.minX), safeFrame.maxX - panel.frame.width),
                y: min(max(source.maxY - panel.frame.height, safeFrame.minY), safeFrame.maxY - panel.frame.height)
            ))
        } else if !AppRuntime.isScreenshotMode, let storedFrame = UserDefaults.standard.string(forKey: "lastEditorFrame") {
            panel.setFrame(NSRectFromString(storedFrame), display: false)
        } else {
            position(panel, beside: NSScreen.main ?? NSScreen.screens[0])
        }
        let destination = panel.frame
        let animate = source != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if animate, let source {
            // Keep the editor's layout stable while moving out of the selected card.
            panel.setFrameOrigin(NSPoint(x: destination.minX + (settings.deckSide == .right ? 36 : -36), y: source.maxY - destination.height))
            panel.alphaValue = 0
        }
        panel.makeKeyAndOrderFront(nil)
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = settings.motionSpeed.duration + 0.06
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.88, 0.3, 1)
                panel.animator().setFrame(destination, display: true)
                panel.animator().alphaValue = 1
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func close(id: UUID) {
        guard let controller = controllers.removeValue(forKey: id) else { return }
        if !AppRuntime.isScreenshotMode, let frame = controller.window?.frame {
            UserDefaults.standard.set(NSStringFromRect(frame), forKey: "lastEditorFrame")
        }
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
        guard !AppRuntime.isScreenshotMode else { return }
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
