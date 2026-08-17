import AgentUsageCore
import Foundation

@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot? {
        didSet {
            onSnapshotChanged?(snapshot)
        }
    }
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastErrorMessage: String?

    var onSnapshotChanged: ((UsageSnapshot?) -> Void)?
    var providerDescriptor: UsageProviderDescriptor {
        provider.descriptor
    }

    private let provider: UsageProvider
    private let settings: AppSettings
    private var timer: Timer?

    init(provider: UsageProvider, settings: AppSettings) {
        self.provider = provider
        self.settings = settings
    }

    func start() {
        scheduleTimer()
        Task {
            await refresh()
        }
    }

    func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        defer {
            isRefreshing = false
        }

        do {
            let snapshot = try await provider.refresh()
            self.snapshot = snapshot
            lastErrorMessage = nil
        } catch {
            let message = (error as? UsageProviderError)?.userMessage ?? error.localizedDescription
            lastErrorMessage = message

            if let snapshot {
                self.snapshot = snapshot.markingStale(message)
            } else {
                self.snapshot = UsageSnapshot(
                    provider: provider.descriptor,
                    refreshedAt: Date(),
                    account: nil,
                    credits: nil,
                    limits: nil,
                    tokenUsage: nil,
                    status: mapInitialError(error, message: message)
                )
            }
        }
    }

    private func mapInitialError(_ error: Error, message: String) -> UsageStatus {
        if case UsageProviderError.authRequired = error {
            return .authRequired
        }

        if case UsageProviderError.agentUnavailable = error {
            return .agentUnavailable(message)
        }

        if case UsageProviderError.rateLimited(let reason) = error {
            return .rateLimited(reason)
        }

        return .error(message)
    }
}
