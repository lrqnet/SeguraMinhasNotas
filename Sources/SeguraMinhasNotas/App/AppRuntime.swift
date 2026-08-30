import Foundation

enum AppRuntime {
    static let screenshotScenario = ProcessInfo.processInfo.environment["SMN_SCREENSHOT_SCENARIO"]
    static let isScreenshotMode = screenshotScenario != nil
    static let keepsDeckOpenForScreenshot = ProcessInfo.processInfo.environment["SMN_DECK_OPEN"] == "1"
}
