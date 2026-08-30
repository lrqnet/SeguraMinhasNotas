import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case sync
    case privacy
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return L10n.tr("Geral")
        case .appearance: return L10n.tr("Aparência")
        case .sync: return L10n.tr("Sincronização")
        case .privacy: return L10n.tr("Privacidade")
        case .about: return L10n.tr("Sobre")
        }
    }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .appearance: return "paintpalette"
        case .sync: return "arrow.triangle.2.circlepath"
        case .privacy: return "lock.shield"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: NoteStore
    @ObservedObject private var syncService = FolderSyncService.shared
    @ObservedObject private var authentication = AuthenticationService.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginService.shared
    @ObservedObject private var updates = UpdateService.shared
    @State private var section: SettingsSection?

    init(settings: AppSettings, store: NoteStore) {
        self.settings = settings
        self.store = store
        let initialSection: SettingsSection
        switch AppRuntime.screenshotScenario {
        case "settings-appearance": initialSection = .appearance
        case "settings-sync": initialSection = .sync
        case "settings-privacy": initialSection = .privacy
        case "settings-about": initialSection = .about
        default: initialSection = .general
        }
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsSection.allCases, selection: $section) { item in
                Label(item.label, systemImage: item.icon).tag(item)
            }
            .listStyle(.sidebar)
            .frame(width: 180)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch section ?? .general {
                    case .general: general
                    case .appearance: appearance
                    case .sync: sync
                    case .privacy: privacy
                    case .about: about
                    }
                }
                .padding(30)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 760, height: 520)
    }

    private var general: some View {
        settingsPage("Geral", subtitle: "Como o baralho aparece e se comporta.") {
            Toggle(L10n.tr("Abrir automaticamente ao ligar o Mac"), isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            if launchAtLogin.requiresApproval {
                HStack {
                    settingHint("O macOS aguarda sua aprovação nos Itens de Início.")
                    Button(L10n.tr("Abrir Ajustes do Sistema")) { launchAtLogin.openSystemSettings() }
                }
            }
            if let error = launchAtLogin.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            Divider()
            Toggle(L10n.tr("Mostrar sobre aplicativos em tela cheia"), isOn: $settings.showOverFullScreen)
            settingHint("Mantém o SeguraMinhasNotas acessível em todos os Spaces.")
            Divider()
            Toggle(L10n.tr("Manter o baralho aberto"), isOn: $settings.keepDeckOpen)
            settingHint("As abas permanecem visíveis em vez de descansarem como pequenos traços.")
            Divider()
            Picker(L10n.tr("Lado da tela"), selection: $settings.deckSide) {
                ForEach(DeckSide.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker(L10n.tr("Abrir uma nota"), selection: $settings.fanMode) {
                ForEach(FanMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker(L10n.tr("Velocidade"), selection: $settings.motionSpeed) {
                ForEach(MotionSpeed.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var appearance: some View {
        settingsPage("Aparência", subtitle: "A voz visual das suas notas.") {
            Picker(L10n.tr("Fonte"), selection: $settings.font) {
                ForEach(NoteFont.allCases) { font in
                    Text(font.label).font(font.swiftUIFont(size: 14)).tag(font)
                }
            }
            Slider(value: $settings.fontSize, in: 13...28, step: 1) {
                Text(L10n.tr("Tamanho"))
            } minimumValueLabel: {
                Text("A").font(.system(size: 11))
            } maximumValueLabel: {
                Text("A").font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.tr("Prévia")).font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                Text(L10n.tr("Ideias ficam mais leves quando moram perto."))
                    .font(settings.font.swiftUIFont(size: settings.fontSize))
                    .foregroundStyle(SeguraNotasStyle.ink)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoteColor.mint.color, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var sync: some View {
        settingsPage("Sincronização", subtitle: "A mesma pilha em todos os seus Macs, usando uma pasta sua.") {
            Toggle(L10n.tr("Sincronizar por pasta"), isOn: $settings.syncEnabled)
                .disabled(settings.syncFolderBookmark == nil)

            VStack(alignment: .leading, spacing: 5) {
                Text(settings.syncFolderPath.isEmpty ? L10n.tr("Nenhuma pasta escolhida") : settings.syncFolderPath)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(2)
                Text(L10n.tr("Um arquivo `.seguranota` legível por nota. Use iCloud Drive, Dropbox ou qualquer pasta sincronizada."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(L10n.tr(settings.syncFolderPath.isEmpty ? "Escolher pasta…" : "Trocar pasta…")) {
                    syncService.chooseFolder(settings: settings) {
                        syncService.sync(store: store, settings: settings)
                    }
                }
                Button(L10n.tr("Sincronizar agora")) { syncService.sync(store: store, settings: settings) }
                    .disabled(!settings.syncEnabled || syncService.isSyncing)
                if syncService.isSyncing { ProgressView().controlSize(.small) }
            }

            if let date = syncService.lastSyncAt {
                Label(L10n.format("Última sincronização %@", date.seguraNotasRelative as NSString), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            if let error = syncService.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
    }

    private var privacy: some View {
        settingsPage("Privacidade", subtitle: "Local primeiro, sem conta e sem telemetria.") {
            Toggle(L10n.tr("Ocultar o conteúdo quando a tela estiver bloqueada"), isOn: $settings.hideOnLock)
            Toggle(L10n.tr("Exigir Touch ID, Apple Watch ou senha"), isOn: Binding(
                get: { settings.requireAuthentication },
                set: { enabled in
                    settings.requireAuthentication = enabled
                    authentication.configure(enabled: enabled)
                }
            ))
            if settings.requireAuthentication {
                HStack {
                    Label(L10n.tr(authentication.isUnlocked ? "Conteúdo desbloqueado" : "Conteúdo bloqueado"), systemImage: authentication.isUnlocked ? "lock.open.fill" : "lock.fill")
                        .foregroundStyle(authentication.isUnlocked ? .green : .secondary)
                    Spacer()
                    Button(L10n.tr(authentication.isUnlocked ? "Bloquear agora" : "Desbloquear")) {
                        authentication.isUnlocked ? authentication.lock() : authentication.unlock()
                    }
                    .disabled(authentication.isAuthenticating)
                }
            }
            Divider()
            privacyRow(L10n.tr("Criptografia local"), detail: L10n.tr("AES-GCM; a chave fica nas Chaves do macOS."), icon: "lock.fill")
            privacyRow(L10n.tr("Armazenamento"), detail: NSString(string: EncryptedPersistence.shared.fileURL.path).abbreviatingWithTildeInPath, icon: "internaldrive")
            privacyRow(L10n.tr("Rede"), detail: L10n.tr("Somente atualizações assinadas e a pasta de sincronização escolhida por você."), icon: "network")
            privacyRow(L10n.tr("Permissões"), detail: L10n.tr("Sem Acessibilidade, gravação de tela ou monitoramento de entrada."), icon: "hand.raised.fill")
        }
    }

    private var about: some View {
        settingsPage("SeguraMinhasNotas", subtitle: "Notas rápidas que moram na borda do Mac.") {
            Text(L10n.tr("Versão 0.2.0"))
                .font(.system(size: 13, weight: .semibold))
            Text(L10n.tr("Software livre sob a licença MIT."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Toggle(L10n.tr("Buscar atualizações automaticamente"), isOn: Binding(
                get: { updates.automaticallyChecksForUpdates },
                set: { updates.automaticallyChecksForUpdates = $0 }
            ))
            Toggle(L10n.tr("Baixar e instalar atualizações automaticamente"), isOn: Binding(
                get: { updates.automaticallyDownloadsUpdates },
                set: { updates.automaticallyDownloadsUpdates = $0 }
            ))
            .disabled(!updates.automaticallyChecksForUpdates)
            HStack {
                Button(L10n.tr("Buscar atualizações agora…")) { updates.checkForUpdates() }
                Link(L10n.tr("Código-fonte e documentação"), destination: URL(string: "https://github.com/lrqnet/SeguraMinhasNotas")!)
            }
        }
    }

    private func settingsPage<Content: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.tr(title)).font(.system(size: 24, weight: .bold, design: .rounded))
                Text(L10n.tr(subtitle)).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Divider()
            content()
        }
    }

    private func settingHint(_ text: String) -> some View {
        Text(L10n.tr(text)).font(.system(size: 11)).foregroundStyle(.secondary)
    }

    private func privacyRow(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
    }
}
