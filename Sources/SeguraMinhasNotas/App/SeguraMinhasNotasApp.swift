import AppKit
import SwiftUI

@main
struct SeguraMinhasNotasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settings: .shared, store: .shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: DeckCoordinator?
    private var hotKeys: HotKeyCenter?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AuthenticationService.shared.configure(enabled: AppSettings.shared.requireAuthentication)
        _ = UpdateService.shared

        let coordinator = DeckCoordinator(store: .shared, settings: .shared)
        self.coordinator = coordinator
        coordinator.start()

        let hotKeys = HotKeyCenter()
        hotKeys.onAction = { [weak self] action in
            switch action {
            case .newNote: self?.coordinator?.createNote()
            case .allNotes: self?.coordinator?.showAllNotes(filter: .all)
            case .archive: self?.coordinator?.showAllNotes(filter: .archived)
            }
        }
        self.hotKeys = hotKeys

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenLocked),
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            coordinator.showOnboardingIfNeeded()
        }

        if let scenario = AppRuntime.screenshotScenario {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                coordinator.prepareScreenshot(scenario: scenario)
                ScreenshotCaptureService.captureWhenReady(scenario: scenario)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NoteStore.shared.flush()
    }

    @objc private func screensChanged() {
        coordinator?.refreshScreens()
    }

    @objc private func screenLocked() {
        NoteStore.shared.isScreenLocked = true
        AuthenticationService.shared.lock()
    }

    @objc private func screenUnlocked() {
        NoteStore.shared.isScreenLocked = false
    }
}
