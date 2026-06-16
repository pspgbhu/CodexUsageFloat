import Foundation
import AppKit

@MainActor
final class AppSettings: ObservableObject {
    @Published var defaultProviderExecutablePath: String {
        didSet {
            defaults.set(defaultProviderExecutablePath, forKey: Keys.defaultProviderExecutablePath)
        }
    }

    @Published var refreshIntervalSeconds: TimeInterval {
        didSet {
            defaults.set(refreshIntervalSeconds, forKey: Keys.refreshIntervalSeconds)
        }
    }

    @Published var isPinned: Bool {
        didSet {
            defaults.set(isPinned, forKey: Keys.isPinned)
        }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
        }
    }

    private let defaults: UserDefaults
    private static let legacyDefaultsSuiteName = "com.local.codex-usage-float"
    private static let defaultCodexExecutablePath = "/Applications/Codex.app/Contents/Resources/codex"
    private static let defaultRefreshIntervalSeconds: TimeInterval = 30.0
    private static let previousDefaultRefreshIntervalSeconds: TimeInterval = 60.0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrateLegacyDefaultsIfNeeded(to: defaults)

        if defaults.object(forKey: Keys.defaultProviderExecutablePath) == nil {
            defaults.set(Self.defaultCodexExecutablePath, forKey: Keys.defaultProviderExecutablePath)
        }
        if defaults.object(forKey: Keys.refreshIntervalSeconds) == nil {
            defaults.set(Self.defaultRefreshIntervalSeconds, forKey: Keys.refreshIntervalSeconds)
        } else if defaults.double(forKey: Keys.refreshIntervalSeconds) == Self.previousDefaultRefreshIntervalSeconds {
            defaults.set(Self.defaultRefreshIntervalSeconds, forKey: Keys.refreshIntervalSeconds)
        }
        if defaults.object(forKey: Keys.launchAtLoginEnabled) == nil {
            defaults.set(true, forKey: Keys.launchAtLoginEnabled)
        }

        self.defaultProviderExecutablePath = defaults.string(forKey: Keys.defaultProviderExecutablePath)
            ?? Self.defaultCodexExecutablePath
        self.refreshIntervalSeconds = defaults.double(forKey: Keys.refreshIntervalSeconds)
        self.isPinned = defaults.bool(forKey: Keys.isPinned)
        self.launchAtLoginEnabled = defaults.bool(forKey: Keys.launchAtLoginEnabled)
    }

    func savedPanelFrame() -> CGRect? {
        guard let string = defaults.string(forKey: Keys.panelFrame) else {
            return nil
        }
        return NSRectFromString(string)
    }

    func savePanelFrame(_ frame: CGRect) {
        defaults.set(NSStringFromRect(frame), forKey: Keys.panelFrame)
    }

    private enum Keys {
        static let defaultProviderExecutablePath = "defaultProviderExecutablePath"
        static let refreshIntervalSeconds = "refreshIntervalSeconds"
        static let isPinned = "isPinned"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let panelFrame = "panelFrame"
    }

    private enum LegacyKeys {
        static let codexCLIPath = "codexCLIPath"
        static let refreshIntervalSeconds = "refreshIntervalSeconds"
        static let isPinned = "isPinned"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let panelFrame = "panelFrame"
    }

    private static func migrateLegacyDefaultsIfNeeded(to defaults: UserDefaults) {
        let legacyDefaults = UserDefaults(suiteName: legacyDefaultsSuiteName)

        if defaults.object(forKey: Keys.defaultProviderExecutablePath) == nil {
            if let currentDomainLegacyPath = defaults.string(forKey: LegacyKeys.codexCLIPath) {
                defaults.set(currentDomainLegacyPath, forKey: Keys.defaultProviderExecutablePath)
            } else if let legacySuitePath = legacyDefaults?.string(forKey: LegacyKeys.codexCLIPath) {
                defaults.set(legacySuitePath, forKey: Keys.defaultProviderExecutablePath)
            }
        }

        copyLegacyValueIfMissing(
            key: Keys.refreshIntervalSeconds,
            legacyKey: LegacyKeys.refreshIntervalSeconds,
            from: legacyDefaults,
            to: defaults
        )
        copyLegacyValueIfMissing(
            key: Keys.isPinned,
            legacyKey: LegacyKeys.isPinned,
            from: legacyDefaults,
            to: defaults
        )
        copyLegacyValueIfMissing(
            key: Keys.launchAtLoginEnabled,
            legacyKey: LegacyKeys.launchAtLoginEnabled,
            from: legacyDefaults,
            to: defaults
        )
        copyLegacyValueIfMissing(
            key: Keys.panelFrame,
            legacyKey: LegacyKeys.panelFrame,
            from: legacyDefaults,
            to: defaults
        )
    }

    private static func copyLegacyValueIfMissing(
        key: String,
        legacyKey: String,
        from legacyDefaults: UserDefaults?,
        to defaults: UserDefaults
    ) {
        guard defaults.object(forKey: key) == nil, let value = legacyDefaults?.object(forKey: legacyKey) else {
            return
        }
        defaults.set(value, forKey: key)
    }
}
