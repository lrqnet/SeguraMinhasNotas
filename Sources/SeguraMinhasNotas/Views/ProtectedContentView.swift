import SwiftUI

struct ProtectedContentView: View {
    @ObservedObject private var authentication = AuthenticationService.shared
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 7 : 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: compact ? 16 : 30, weight: .semibold))
            Text(L10n.tr("Notas protegidas"))
                .font(.system(size: compact ? 12 : 17, weight: .bold, design: .rounded))
            if !compact {
                Text(L10n.tr("Use Touch ID, Apple Watch ou a senha deste Mac para continuar."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(L10n.tr(authentication.isAuthenticating ? "Autenticando…" : "Desbloquear")) {
                    authentication.unlock()
                }
                .buttonStyle(SeguraNotasButtonStyle(emphasized: true))
                .disabled(authentication.isAuthenticating)
            }
        }
        .padding(compact ? 10 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
