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

    @Published var floatingWindowEnabled: Bool {
        didSet {
            defaults.set(floatingWindowEnabled, forKey: Keys.floatingWindowEnabled)
        }
    }

    @Published var selectedStatusBarMetrics: [StatusBarMetric] {
        didSet {
            defaults.set(selectedStatusBarMetrics.map(\.rawValue), forKey: Keys.selectedStatusBarMetrics)
        }
    }

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
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

        let missingLanguage = defaults.object(forKey: Keys.language) == nil
        let defaultLanguage: AppLanguage = missingLanguage && Self.hasExistingAppSettings(in: defaults)
            ? .simplifiedChinese
            : .english

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
        if defaults.object(forKey: Keys.floatingWindowEnabled) == nil {
            defaults.set(false, forKey: Keys.floatingWindowEnabled)
        }

        self.defaultProviderExecutablePath = defaults.string(forKey: Keys.defaultProviderExecutablePath)
            ?? Self.defaultCodexExecutablePath
        self.refreshIntervalSeconds = defaults.double(forKey: Keys.refreshIntervalSeconds)
        self.launchAtLoginEnabled = defaults.bool(forKey: Keys.launchAtLoginEnabled)
        self.floatingWindowEnabled = defaults.bool(forKey: Keys.floatingWindowEnabled)
        self.selectedStatusBarMetrics = Self.loadStatusBarMetrics(from: defaults)
        self.language = Self.loadLanguage(from: defaults, defaultLanguage: defaultLanguage)
        defaults.set(floatingWindowEnabled, forKey: Keys.floatingWindowEnabled)
        defaults.set(selectedStatusBarMetrics.map(\.rawValue), forKey: Keys.selectedStatusBarMetrics)
        defaults.set(language.rawValue, forKey: Keys.language)
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

    var floatingWindowOrigin: (x: Double, y: Double)? {
        guard
            defaults.object(forKey: Keys.floatingWindowOriginX) != nil,
            defaults.object(forKey: Keys.floatingWindowOriginY) != nil
        else {
            return nil
        }

        return (
            defaults.double(forKey: Keys.floatingWindowOriginX),
            defaults.double(forKey: Keys.floatingWindowOriginY)
        )
    }

    func setFloatingWindowOrigin(x: Double, y: Double) {
        defaults.set(x, forKey: Keys.floatingWindowOriginX)
        defaults.set(y, forKey: Keys.floatingWindowOriginY)
    }

    private enum Keys {
        static let defaultProviderExecutablePath = "defaultProviderExecutablePath"
        static let refreshIntervalSeconds = "refreshIntervalSeconds"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let floatingWindowEnabled = "floatingWindowEnabled"
        static let floatingWindowOriginX = "floatingWindowOriginX"
        static let floatingWindowOriginY = "floatingWindowOriginY"
        static let selectedStatusBarMetrics = "selectedStatusBarMetrics"
        static let language = "language"
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

    private static func loadLanguage(from defaults: UserDefaults, defaultLanguage: AppLanguage) -> AppLanguage {
        guard
            let rawValue = defaults.string(forKey: Keys.language),
            let language = AppLanguage(rawValue: rawValue)
        else {
            return defaultLanguage
        }

        return language
    }

    private static func hasExistingAppSettings(in defaults: UserDefaults) -> Bool {
        [
            Keys.defaultProviderExecutablePath,
            Keys.refreshIntervalSeconds,
            Keys.launchAtLoginEnabled,
            Keys.floatingWindowEnabled,
            Keys.selectedStatusBarMetrics
        ].contains { defaults.object(forKey: $0) != nil }
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
