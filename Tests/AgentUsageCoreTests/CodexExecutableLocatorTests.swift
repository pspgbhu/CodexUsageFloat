import XCTest
@testable import AgentUsageCore

final class CodexExecutableLocatorTests: XCTestCase {
    func testPrefersChatGPTAppForNewConfiguration() {
        let resolved = resolve(
            configuredPath: nil,
            executablePaths: [
                CodexExecutableLocator.chatGPTAppExecutablePath,
                CodexExecutableLocator.legacyCodexAppExecutablePath
            ]
        )

        XCTAssertEqual(resolved, CodexExecutableLocator.chatGPTAppExecutablePath)
    }

    func testFallsBackToLegacyCodexAppWhenItIsTheOnlyInstalledApp() {
        let resolved = resolve(
            configuredPath: nil,
            executablePaths: [CodexExecutableLocator.legacyCodexAppExecutablePath]
        )

        XCTAssertEqual(resolved, CodexExecutableLocator.legacyCodexAppExecutablePath)
    }

    func testMigratesMissingLegacyDefaultToChatGPTApp() {
        let resolved = resolve(
            configuredPath: CodexExecutableLocator.legacyCodexAppExecutablePath,
            executablePaths: [CodexExecutableLocator.chatGPTAppExecutablePath]
        )

        XCTAssertEqual(resolved, CodexExecutableLocator.chatGPTAppExecutablePath)
    }

    func testKeepsWorkingLegacyDefault() {
        let resolved = resolve(
            configuredPath: CodexExecutableLocator.legacyCodexAppExecutablePath,
            executablePaths: [
                CodexExecutableLocator.chatGPTAppExecutablePath,
                CodexExecutableLocator.legacyCodexAppExecutablePath
            ]
        )

        XCTAssertEqual(resolved, CodexExecutableLocator.legacyCodexAppExecutablePath)
    }

    func testPreservesCustomPathEvenWhenItIsUnavailable() {
        let customPath = "/opt/local/bin/codex"
        let resolved = resolve(
            configuredPath: customPath,
            executablePaths: [CodexExecutableLocator.chatGPTAppExecutablePath]
        )

        XCTAssertEqual(resolved, customPath)
    }

    func testUsesChatGPTDefaultWhenNoKnownAppIsInstalled() {
        let resolved = resolve(
            configuredPath: CodexExecutableLocator.legacyCodexAppExecutablePath,
            executablePaths: []
        )

        XCTAssertEqual(resolved, CodexExecutableLocator.chatGPTAppExecutablePath)
    }

    private func resolve(configuredPath: String?, executablePaths: Set<String>) -> String {
        CodexExecutableLocator.resolve(
            configuredPath: configuredPath,
            isExecutable: executablePaths.contains
        )
    }
}
