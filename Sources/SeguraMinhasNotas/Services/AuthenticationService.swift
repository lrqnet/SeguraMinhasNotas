import Foundation
import LocalAuthentication

@MainActor
final class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()

    @Published private(set) var isUnlocked = true
    @Published private(set) var isAuthenticating = false
    @Published var lastError: String?

    private init() {}

    func configure(enabled: Bool) {
        enabled ? lock() : unlockWithoutPrompt()
    }

    func lock() {
        isUnlocked = false
        isAuthenticating = false
    }

    func unlock(completion: ((Bool) -> Void)? = nil) {
        guard !isUnlocked, !isAuthenticating else {
            completion?(isUnlocked)
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = L10n.tr("Manter bloqueado")
        var availabilityError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &availabilityError) else {
            lastError = availabilityError?.localizedDescription ?? L10n.tr("A autenticação deste Mac não está disponível.")
            completion?(false)
            return
        }

        isAuthenticating = true
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: L10n.tr("Desbloqueie o conteúdo das suas notas.")
        ) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isAuthenticating = false
                self.isUnlocked = success
                self.lastError = success ? nil : error?.localizedDescription
                completion?(success)
            }
        }
    }

    private func unlockWithoutPrompt() {
        isUnlocked = true
        isAuthenticating = false
        lastError = nil
    }
}
