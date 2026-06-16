import Foundation

public enum UsageProviderError: Error, Equatable {
    case agentUnavailable(String)
    case timeout(String)
    case rpc(code: Int?, message: String)
    case invalidResponse(String)
    case authRequired
    case rateLimited(String?)

    public var userMessage: String {
        switch self {
        case .agentUnavailable(let message):
            return message
        case .timeout(let method):
            return "Timed out while reading \(method)."
        case .rpc(_, let message):
            return message
        case .invalidResponse(let message):
            return message
        case .authRequired:
            return "Open the configured agent and sign in again."
        case .rateLimited(let message):
            return message ?? "Usage limit reached."
        }
    }
}
