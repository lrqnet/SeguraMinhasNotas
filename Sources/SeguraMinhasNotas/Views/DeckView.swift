import SwiftUI
import UniformTypeIdentifiers

struct DeckView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var settings: AppSettings
    @ObservedObject private var authentication = AuthenticationService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onOpen: (UUID, CGRect) -> Void
    let onShowAll: (NoteFilter) -> Void
    let onShowSettings: () -> Void
    let onPresentationChanged: (Bool, Bool) -> Void

    @State private var isFanned = false
    @State private var hoveredID: UUID?
    @State private var collapseTask: Task<Void, Never>?
    @State private var draggingID: UUID?
    @State private var reopenAfter = Date.distantPast

    private var left: Bool { settings.deckSide == .left }
    private var displayNotes: [Note] { Array(store.visibleNotes.prefix(8)) }
    private var contentLocked: Bool {
        (store.isScreenLocked && settings.hideOnLock) || (settings.requireAuthentication && !authentication.isUnlocked)
    }
    private var motion: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: settings.motionSpeed.duration + 0.06, dampingFraction: 0.86)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = DeckLayout(count: displayNotes.count, height: geometry.size.height)
            ZStack(alignment: .topLeading) {
                dormantPill
                    .position(x: left ? 17 : DeckLayout.canvasWidth - 17, y: geometry.size.height / 2)
                    .opacity(isFanned ? 0 : 1)
                    .allowsHitTesting(!isFanned)

                ForEach(Array(displayNotes.enumerated()), id: \.element.id) { index, note in
                    let preview = hoveredID == note.id
                    let rect = layout.cardFrame(index: index, expanded: isFanned, preview: preview, left: left)
                    deckCard(note, preview: preview, rect: rect)
                        .rotationEffect(.degrees(reduceMotion || preview ? 0 : (left ? -1 : 1) * (Double(index) * 0.5 - 1.8)))
                        .position(x: rect.midX, y: rect.midY)
                        .opacity(isFanned ? 1 : 0)
                        .zIndex(preview ? 100 : Double(displayNotes.count - index))
                        .animation(reduceMotion ? motion : motion.delay(isFanned ? Double(index) * 0.035 : 0), value: isFanned)
                        .allowsHitTesting(isFanned)
                        .onDrag {
                            draggingID = note.id
                            collapseTask?.cancel()
                            return NSItemProvider(object: note.id.uuidString as NSString)
                        }
                        .onDrop(of: [UTType.text], delegate: DeckDropDelegate(
                            destinationID: note.id, draggingID: $draggingID, store: store, animation: motion
                        ))
                }

                controls
                    .position(x: left ? 74 : DeckLayout.canvasWidth - 74, y: layout.controlsY)
                    .opacity(isFanned ? 1 : 0)
                    .allowsHitTesting(isFanned)
            }
            .frame(width: DeckLayout.canvasWidth, height: geometry.size.height)
            .overlay {
                DeckPointerRegion { point in
                    guard !AppRuntime.isScreenshotMode || AppRuntime.isInteractivePreview else { return }
                    handlePointer(point, layout: layout)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: left ? .leading : .trailing)
        }
        .transaction { if reduceMotion { $0.animation = nil } }
        .onAppear {
            setFanned(settings.keepDeckOpen)
            if AppRuntime.screenshotScenario?.hasPrefix("deck-preview") == true {
                setFanned(true)
                setPreview(displayNotes.dropFirst().first?.id ?? displayNotes.first?.id)
            }
        }
        .onChange(of: settings.keepDeckOpen) { setFanned($0) }
        .onChange(of: settings.deckSide) { _ in setPreview(nil) }
        .onChange(of: store.visibleNotes.map(\.id)) { ids in
            if let hoveredID, !ids.contains(hoveredID) { setPreview(nil) }
        }
        .onDisappear {
            collapseTask?.cancel()
        }
        .contextMenu { deckMenu }
    }

    private var dormantPill: some View {
        Button { setFanned(true) } label: {
            VStack(spacing: 6) {
                if displayNotes.isEmpty {
                    Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                }
                ForEach(displayNotes) { note in
                    Capsule().fill(note.color.color).frame(width: 6, height: 17)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.16), radius: 8, x: left ? 3 : -3, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.tr("Todas as notas"))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button { _ = store.addNote() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
            }
            .accessibilityLabel(L10n.tr("Nova nota"))
            if store.visibleNotes.count > 8 {
                Button { onShowAll(.active) } label: {
                    Text("+\(store.visibleNotes.count - 8)")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(10)
                        .background(.regularMaterial, in: Capsule())
                }
                .accessibilityLabel(L10n.tr("Todas as notas"))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(SeguraNotasStyle.ink)
    }

    private func deckCard(_ note: Note, preview: Bool, rect: CGRect) -> some View {
        Button {
            reopenAfter = Date().addingTimeInterval(0.6)
            if !settings.keepDeckOpen { setFanned(false) }
            onOpen(note.id, rect)
        } label: {
            HStack(spacing: 0) {
                if !left { tabLabel(note, height: rect.height) }
                VStack(alignment: .leading, spacing: 10) {
                    Text(contentLocked ? L10n.tr("Conteúdo oculto") : note.displayTitle)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .lineLimit(preview ? 2 : 1)
                    Text(contentLocked ? L10n.tr("Autentique-se para ler") : note.body)
                        .font(settings.font.swiftUIFont(size: min(settings.fontSize, 16)))
                        .foregroundStyle(SeguraNotasStyle.secondaryInk)
                        .lineSpacing(3)
                        .lineLimit(preview ? 5 : 2)
                    Spacer(minLength: 0)
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(preview ? 1 : 0)
                if left { tabLabel(note, height: rect.height) }
            }
            .frame(width: rect.width, height: rect.height)
            .foregroundStyle(SeguraNotasStyle.ink)
            .background(note.color.color)
            .overlay {
                LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.42), lineWidth: 0.8))
            .shadow(color: .black.opacity(preview ? 0.20 : 0.10), radius: preview ? 18 : 10, y: preview ? 10 : 5)
            .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(contentLocked ? L10n.tr("NOTA") : note.displayTitle)
    }

    private func tabLabel(_ note: Note, height: CGFloat) -> some View {
        Text(contentLocked ? L10n.tr("NOTA") : note.displayTitle.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.1)
            .lineLimit(1)
            .frame(width: height - 26)
            .rotationEffect(.degrees(left ? 90 : -90))
            .frame(width: 44, height: height)
            .foregroundStyle(SeguraNotasStyle.ink.opacity(0.7))
            .overlay(alignment: left ? .leading : .trailing) {
                Rectangle().fill(.black.opacity(0.08)).frame(width: 1).padding(.vertical, 16)
            }
    }

    @ViewBuilder
    private var deckMenu: some View {
        Button(L10n.tr("Nova nota"), systemImage: "square.and.pencil") { _ = store.addNote() }
        Button(L10n.tr("Todas as notas"), systemImage: "rectangle.grid.1x2") { onShowAll(.all) }
        Button(L10n.tr("Arquivo"), systemImage: "archivebox") { onShowAll(.archived) }
        Divider()
        Toggle(L10n.tr("Manter baralho aberto"), isOn: $settings.keepDeckOpen)
        Toggle(L10n.tr("Mostrar sobre tela cheia"), isOn: $settings.showOverFullScreen)
        Picker(L10n.tr("Lado da tela"), selection: $settings.deckSide) {
            ForEach(DeckSide.allCases) { Text($0.label).tag($0) }
        }
        Divider()
        Button(L10n.tr("Ajustes…"), systemImage: "gearshape") { onShowSettings() }
        Button(L10n.tr("Encerrar SeguraMinhasNotas"), systemImage: "power") { NSApp.terminate(nil) }
    }

    private func setPreview(_ id: UUID?) {
        guard id != hoveredID else { return }
        onPresentationChanged(isFanned, id != nil)
        withAnimation(motion) { hoveredID = id }
    }

    private func setFanned(_ value: Bool) {
        collapseTask?.cancel()
        guard value != isFanned else { return }
        onPresentationChanged(value, value && hoveredID != nil)
        withAnimation(motion) {
            isFanned = value
            if !value { hoveredID = nil }
        }
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard !Task.isCancelled else { return }
            draggingID = nil
            if settings.keepDeckOpen { setPreview(nil) }
            else { setFanned(false) }
        }
    }

    private func handlePointer(_ point: CGPoint?, layout: DeckLayout) {
        guard let point else {
            scheduleCollapse()
            return
        }
        collapseTask?.cancel()
        guard isFanned else {
            guard Date() >= reopenAfter else { return }
            if settings.fanMode == .hover { setFanned(true) }
            return
        }
        if let hoveredID, let index = displayNotes.firstIndex(where: { $0.id == hoveredID }) {
            let preview = layout.cardFrame(index: index, expanded: true, preview: true, left: left)
            let bridge = CGRect(x: left ? 0 : preview.maxX, y: preview.minY,
                                width: left ? preview.minX : DeckLayout.canvasWidth - preview.maxX,
                                height: max(24, layout.stride))
            if preview.contains(point) || bridge.contains(point) { return }
        }
        let candidate = displayNotes.enumerated().first { index, _ in
            layout.cardFrame(index: index, expanded: true, preview: false, left: left).contains(point)
        }
        setPreview(candidate?.element.id)
    }
}

/// Tracks only this panel; the transparent view never consumes clicks or drags.
private struct DeckPointerRegion: NSViewRepresentable {
    var onMove: (CGPoint?) -> Void

    func makeNSView(context: Context) -> PointerView { PointerView(onMove: onMove) }
    func updateNSView(_ view: PointerView, context: Context) { view.onMove = onMove }

    final class PointerView: NSView {
        var onMove: (CGPoint?) -> Void
        private var area: NSTrackingArea?
        override var isFlipped: Bool { true }

        init(onMove: @escaping (CGPoint?) -> Void) {
            self.onMove = onMove
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let area { removeTrackingArea(area) }
            let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect, .enabledDuringMouseDrag], owner: self)
            addTrackingArea(area)
            self.area = area
        }
        override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
        override func mouseMoved(with event: NSEvent) { onMove(convert(event.locationInWindow, from: nil)) }
        override func mouseExited(with event: NSEvent) { onMove(nil) }
    }
}

@MainActor
private struct DeckDropDelegate: DropDelegate {
    let destinationID: UUID
    @Binding var draggingID: UUID?
    let store: NoteStore
    let animation: Animation

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != destinationID else { return }
        withAnimation(animation) { store.moveVisible(noteID: draggingID, before: destinationID) }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
}
