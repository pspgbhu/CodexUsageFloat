import Foundation

public enum CodexExecutableLocator {
    public static let chatGPTAppExecutablePath = "/Applications/ChatGPT.app/Contents/Resources/codex"
    public static let legacyCodexAppExecutablePath = "/Applications/Codex.app/Contents/Resources/codex"

    public static var defaultExecutablePath: String {
        chatGPTAppExecutablePath
    }

    public static func resolve(
        configuredPath: String? = nil,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> String {
        let knownAppPaths = [
            chatGPTAppExecutablePath,
            legacyCodexAppExecutablePath
        ]

        if let configuredPath, !configuredPath.isEmpty {
            guard knownAppPaths.contains(configuredPath) else {
                return configuredPath
            }

            if isExecutable(configuredPath) {
                return configuredPath
            }
        }

        return knownAppPaths.first(where: isExecutable) ?? defaultExecutablePath
    }
}
