import Foundation
import Darwin

enum LaunchAgentManager {
    static let label = "com.local.codex-usage-float"
    private static let legacyLabel = "com.local.agent-usage-float"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    private static var legacyPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(legacyLabel).plist")
    }

    static func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func setEnabled(_ enabled: Bool, loadIntoCurrentSession: Bool = false) throws {
        if enabled {
            try install(loadIntoCurrentSession: loadIntoCurrentSession)
        } else {
            try uninstall()
        }
    }

    private static func install(loadIntoCurrentSession: Bool) throws {
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let executable = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/CodexUsageFloat")
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": ["Crashed": true],
            "StandardOutPath": logDir.appendingPathComponent("stdout.log").path,
            "StandardErrorPath": logDir.appendingPathComponent("stderr.log").path
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)

        // Remove the pre-rename agent so only CodexUsageFloat runs at login.
        _ = try? runLaunchctl(["bootout", "gui/\(getuid())", legacyPlistURL.path])
        if FileManager.default.fileExists(atPath: legacyPlistURL.path) {
            try? FileManager.default.removeItem(at: legacyPlistURL)
        }

        // In-app login toggles should register the next login only; bootstrapping now
        // would launch a second menu bar instance beside the currently running app.
        guard loadIntoCurrentSession else {
            return
        }

        _ = try? runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        try runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
        _ = try? runLaunchctl(["enable", "gui/\(getuid())/\(label)"])
    }

    private static func uninstall() throws {
        _ = try? runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        _ = try? runLaunchctl(["bootout", "gui/\(getuid())", legacyPlistURL.path])
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
        if FileManager.default.fileExists(atPath: legacyPlistURL.path) {
            try? FileManager.default.removeItem(at: legacyPlistURL)
        }
    }

    @discardableResult
    private static func runLaunchctl(_ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
