import Combine
import Foundation

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

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
        }
    }

    @Published var selectedStatusBarMetrics: [StatusBarMetric] {
        didSet {
            defaults.set(selectedStatusBarMetrics.map(\.rawValue), forKey: Keys.selectedStatusBarMetrics)
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
        self.launchAtLoginEnabled = defaults.bool(forKey: Keys.launchAtLoginEnabled)
        self.selectedStatusBarMetrics = Self.loadStatusBarMetrics(from: defaults)
        defaults.set(selectedStatusBarMetrics.map(\.rawValue), forKey: Keys.selectedStatusBarMetrics)
    }

    func isStatusBarMetricEnabled(_ metric: StatusBarMetric) -> Bool {
        selectedStatusBarMetrics.contains(metric)
    }

    func setStatusBarMetric(_ metric: StatusBarMetric, enabled: Bool) {
        var nextMetrics = selectedStatusBarMetrics

        if enabled {
            if !nextMetrics.contains(metric) {
                nextMetrics.append(metric)
            }
        } else {
            nextMetrics.removeAll { $0 == metric }
        }

        selectedStatusBarMetrics = nextMetrics
    }

    private enum Keys {
        static let defaultProviderExecutablePath = "defaultProviderExecutablePath"
        static let refreshIntervalSeconds = "refreshIntervalSeconds"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let selectedStatusBarMetrics = "selectedStatusBarMetrics"
    }

    private enum LegacyKeys {
        static let codexCLIPath = "codexCLIPath"
        static let refreshIntervalSeconds = "refreshIntervalSeconds"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
    }

    private static func loadStatusBarMetrics(from defaults: UserDefaults) -> [StatusBarMetric] {
        guard let rawValues = defaults.stringArray(forKey: Keys.selectedStatusBarMetrics) else {
            return [.primaryRemaining]
        }

        let metrics = rawValues.compactMap(StatusBarMetric.init(rawValue:))
        return rawValues.isEmpty ? [] : (metrics.isEmpty ? [.primaryRemaining] : metrics)
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
            key: Keys.launchAtLoginEnabled,
            legacyKey: LegacyKeys.launchAtLoginEnabled,
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
