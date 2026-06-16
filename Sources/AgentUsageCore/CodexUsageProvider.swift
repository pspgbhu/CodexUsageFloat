import Foundation

private struct PendingResponse {
    var method: String
    var continuation: CheckedContinuation<Data, Error>
}

private final class PendingResponseStore {
    private let lock = NSLock()
    private var responses: [Int: PendingResponse] = [:]

    func insert(id: Int, method: String, continuation: CheckedContinuation<Data, Error>) {
        lock.lock()
        responses[id] = PendingResponse(method: method, continuation: continuation)
        lock.unlock()
    }

    func resume(id: Int, returning data: Data) {
        let pending = remove(id: id)
        pending?.continuation.resume(returning: data)
    }

    func resume(id: Int, throwing error: Error) {
        let pending = remove(id: id)
        pending?.continuation.resume(throwing: error)
    }

    func remove(id: Int) -> PendingResponse? {
        lock.lock()
        let pending = responses.removeValue(forKey: id)
        lock.unlock()
        return pending
    }

    func cancelAll(error: Error) {
        lock.lock()
        let all = responses
        responses.removeAll()
        lock.unlock()

        for (_, pending) in all {
            pending.continuation.resume(throwing: error)
        }
    }
}

public actor CodexUsageProvider: UsageProvider {
    private struct InitializeResponse: Decodable {
        var userAgent: String
        var codexHome: String
        var platformFamily: String
        var platformOs: String
    }

    private let executablePath: String
    private let requestTimeoutSeconds: TimeInterval
    private let decoder = JSONDecoder()
    private let pendingResponses = PendingResponseStore()

    public nonisolated let descriptor = UsageProviderDescriptor(id: "codex", displayName: "Codex")

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stdoutBuffer = Data()
    private var nextRequestID = 1
    private var initialized = false
    private var reconnectDelaySeconds: TimeInterval = 0.25
    private var nextAllowedStart = Date.distantPast

    public init(
        executablePath: String = "/Applications/Codex.app/Contents/Resources/codex",
        requestTimeoutSeconds: TimeInterval = 12
    ) {
        self.executablePath = executablePath
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }

    deinit {
        process?.terminate()
    }

    public func refresh() async throws -> UsageSnapshot {
        do {
            try await ensureInitialized()

            async let rateLimits: GetAccountRateLimitsResponse = request(
                method: "account/rateLimits/read",
                as: GetAccountRateLimitsResponse.self
            )
            async let tokenUsage: GetAccountTokenUsageResponse = request(
                method: "account/usage/read",
                as: GetAccountTokenUsageResponse.self
            )
            async let account: GetAccountResponse = request(
                method: "account/read",
                params: [:],
                as: GetAccountResponse.self
            )

            let snapshot = try await CodexUsageMapper.makeSnapshot(
                rateLimits: rateLimits,
                tokenUsage: tokenUsage,
                account: account,
                provider: descriptor
            )
            reconnectDelaySeconds = 0.25
            return snapshot
        } catch {
            noteStartFailure()
            stopProcess(error: error)
            throw error
        }
    }

    private func ensureInitialized() async throws {
        if initialized, process?.isRunning == true {
            return
        }

        try await startProcess()

        let params: [String: Any] = [
            "clientInfo": [
                "name": "agent-usage-float",
                "title": "Agent Usage Float",
                "version": "0.1.0"
            ],
            "capabilities": [
                "experimentalApi": true,
                "requestAttestation": false,
                "optOutNotificationMethods": []
            ]
        ]

        let _: InitializeResponse = try await request(
            method: "initialize",
            params: params,
            as: InitializeResponse.self
        )
        initialized = true
    }

    private func startProcess() async throws {
        if process?.isRunning == true {
            return
        }

        let now = Date()
        if nextAllowedStart > now {
            let delay = nextAllowedStart.timeIntervalSince(now)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw UsageProviderError.agentUnavailable("Codex CLI is not executable at \(executablePath).")
        }

        stopProcess(error: nil)

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let client = self
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            Task {
                await client.ingestStdout(data)
            }
        }

        process.terminationHandler = { process in
            Task {
                await client.handleProcessExit(process.terminationStatus)
            }
        }

        do {
            try process.run()
        } catch {
            throw UsageProviderError.agentUnavailable("Failed to start Codex app-server.")
        }

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stdoutBuffer.removeAll()
        self.initialized = false
    }

    private func request<T: Decodable>(
        method: String,
        params: Any? = nil,
        as type: T.Type
    ) async throws -> T {
        let data = try await requestData(method: method, params: params)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw UsageProviderError.invalidResponse("Could not decode \(method) response.")
        }
    }

    private func requestData(method: String, params: Any?) async throws -> Data {
        let id = nextRequestID
        nextRequestID += 1

        let requestData = try makeRequestData(id: id, method: method, params: params)
        guard let writeHandle = stdinPipe?.fileHandleForWriting else {
            throw UsageProviderError.agentUnavailable("Codex app-server is not running.")
        }

        let pendingResponses = self.pendingResponses
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(requestTimeoutSeconds * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }
            pendingResponses.resume(id: id, throwing: UsageProviderError.timeout(method))
        }
        defer {
            timeoutTask.cancel()
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingResponses.insert(id: id, method: method, continuation: continuation)
            do {
                try writeHandle.write(contentsOf: requestData)
            } catch {
                pendingResponses.resume(id: id, throwing: UsageProviderError.agentUnavailable("Failed to write to Codex app-server."))
            }
        }
    }

    private func makeRequestData(id: Int, method: String, params: Any?) throws -> Data {
        var request: [String: Any] = [
            "id": id,
            "method": method
        ]
        if let params {
            request["params"] = params
        }

        var data = try JSONSerialization.data(withJSONObject: request, options: [])
        data.append(0x0A)
        return data
    }

    private func ingestStdout(_ data: Data) {
        stdoutBuffer.append(data)

        while let newline = stdoutBuffer.firstIndex(of: 0x0A) {
            let line = stdoutBuffer[..<newline]
            stdoutBuffer.removeSubrange(...newline)

            guard !line.isEmpty else {
                continue
            }

            handleLine(Data(line))
        }
    }

    private func handleLine(_ line: Data) {
        do {
            guard let response = try JSONRPCResponseParser.parseResultLine(line) else {
                return
            }

            pendingResponses.resume(id: response.id, returning: response.payload)
        } catch {
            if let id = parseResponseID(from: line) {
                pendingResponses.resume(id: id, throwing: error)
            }
        }
    }

    private func parseResponseID(from line: Data) -> Int? {
        guard
            let object = try? JSONSerialization.jsonObject(with: line, options: []),
            let dictionary = object as? [String: Any]
        else {
            return nil
        }

        if let number = dictionary["id"] as? NSNumber {
            return number.intValue
        }

        if let string = dictionary["id"] as? String {
            return Int(string)
        }

        return nil
    }

    private func handleProcessExit(_ status: Int32) {
        let error = UsageProviderError.agentUnavailable("Codex app-server exited with status \(status).")
        noteStartFailure()
        stopProcess(error: error)
    }

    private func stopProcess(error: Error?) {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil

        if let error {
            pendingResponses.cancelAll(error: error)
        }

        if process?.isRunning == true {
            process?.terminate()
        }

        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stdoutBuffer.removeAll()
        initialized = false
    }

    private func noteStartFailure() {
        let delay = min(reconnectDelaySeconds, 8)
        nextAllowedStart = Date().addingTimeInterval(delay)
        reconnectDelaySeconds = min(reconnectDelaySeconds * 2, 8)
    }
}
