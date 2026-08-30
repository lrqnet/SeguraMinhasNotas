import SwiftUI
import UniformTypeIdentifiers

struct DeckView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var settings: AppSettings
    @ObservedObject private var authentication = AuthenticationService.shared
    let onOpen: (UUID) -> Void
    let onShowAll: (NoteFilter) -> Void
    let onShowSettings: () -> Void
    let onFanChanged: (Bool) -> Void

    @State private var isFanned = false
    @State private var hoveredID: UUID?
    @State private var hoverTask: Task<Void, Never>?
    @State private var draggingID: UUID?

    private var side: DeckSide { settings.deckSide }
    private var displayNotes: [Note] { Array(store.visibleNotes.prefix(8)) }
    private var contentLocked: Bool {
        (store.isScreenLocked && settings.hideOnLock) || (settings.requireAuthentication && !authentication.isUnlocked)
    }

    var body: some View {
        ZStack(alignment: side == .right ? .leading : .trailing) {
            if !isFanned {
                dormantPill
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            if isFanned {
                fannedDeck
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: side == .right ? .leading : .trailing)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                setFanned(true)
            } else if !settings.keepDeckOpen {
                hoveredID = nil
                hoverTask?.cancel()
                setFanned(false)
            }
        }
        .onAppear {
            isFanned = settings.keepDeckOpen
            onFanChanged(isFanned)
        }
        .onChange(of: settings.keepDeckOpen) { keepOpen in setFanned(keepOpen) }
        .contextMenu { deckMenu }
    }

    private var dormantPill: some View {
        VStack(spacing: 7) {
            ForEach(displayNotes) { note in
                Capsule()
                    .fill(note.color.color)
                    .frame(width: 7, height: 18)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.6))
        .shadow(color: .black.opacity(0.28), radius: 12, y: 4)
        .padding(side == .right ? .leading : .trailing, 1)
    }

    private var fannedDeck: some View {
        VStack(alignment: side == .right ? .leading : .trailing, spacing: -8) {
            ForEach(Array(displayNotes.enumerated()), id: \.element.id) { index, note in
                deckCard(note, index: index)
                    .zIndex(hoveredID == note.id ? 100 : Double(displayNotes.count - index))
                    .offset(x: side == .right ? Double(index * 3) : Double(-index * 3))
                    .animation(
                        .spring(response: settings.motionSpeed.duration + 0.12, dampingFraction: 0.82)
                            .delay(Double(index) * 0.045),
                        value: isFanned
                    )
                    .onDrag {
                        draggingID = note.id
                        return NSItemProvider(object: note.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: DeckDropDelegate(destinationID: note.id, draggingID: $draggingID, store: store)
                    )
            }

            if store.visibleNotes.count > 8 {
                Button { onShowAll(.active) } label: {
                    let remaining = store.visibleNotes.count - 8
                    Text(L10n.format(remaining == 1 ? "+%d nota" : "+%d notas", remaining))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SeguraNotasStyle.ink)
                        .frame(width: 96, height: 34)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }

            Button { _ = store.addNote() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SeguraNotasStyle.ink)
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(side == .right ? .leading : .trailing, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: side == .right ? .leading : .trailing)
        .padding(.vertical, 10)
    }

    private func deckCard(_ note: Note, index: Int) -> some View {
        Button {
            onOpen(note.id)
        } label: {
            HStack(spacing: 0) {
                if side == .right { tabLabel(note) }
                cardBody(note)
                if side == .left { tabLabel(note) }
            }
            .frame(width: 320, height: 84)
            .background(note.color.color)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(hoveredID == note.id ? 0.34 : 0.22), radius: hoveredID == note.id ? 22 : 13, x: 0, y: 5)
            .scaleEffect(hoveredID == note.id ? 1.025 : 1, anchor: side == .right ? .leading : .trailing)
            .offset(x: hoveredID == note.id ? (side == .right ? -8 : 8) : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: hoveredID)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredID = hovering ? note.id : (hoveredID == note.id ? nil : hoveredID)
            hoverTask?.cancel()
            guard hovering, settings.fanMode == .hover else { return }
            hoverTask = Task {
                try? await Task.sleep(nanoseconds: 420_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if hoveredID == note.id { onOpen(note.id) }
                }
            }
        }
    }

    private func tabLabel(_ note: Note) -> some View {
        Text(contentLocked ? L10n.tr("NOTA") : note.displayTitle.uppercased())
            .lineLimit(1)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(SeguraNotasStyle.ink.opacity(0.72))
            .rotationEffect(.degrees(side == .right ? -90 : 90))
            .frame(width: 42, height: 84)
            .overlay(alignment: side == .right ? .trailing : .leading) {
                Rectangle().fill(Color.black.opacity(0.09)).frame(width: 1).padding(.vertical, 12)
            }
    }

    private func cardBody(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(contentLocked ? L10n.tr("Conteúdo oculto") : note.displayTitle)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(SeguraNotasStyle.ink)
                .lineLimit(1)
            Text(contentLocked ? L10n.tr("Autentique-se para ler") : note.bodyPreview)
                .font(settings.font.swiftUIFont(size: 13))
                .foregroundStyle(SeguraNotasStyle.secondaryInk)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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

    private func setFanned(_ value: Bool) {
        guard value != isFanned else { return }
        withAnimation(.spring(response: settings.motionSpeed.duration + 0.08, dampingFraction: 0.86)) {
            isFanned = value
        }
        onFanChanged(value)
    }
}

@MainActor
private struct DeckDropDelegate: DropDelegate {
    let destinationID: UUID
    @Binding var draggingID: UUID?
    let store: NoteStore

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != destinationID else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            store.moveVisible(noteID: draggingID, before: destinationID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
