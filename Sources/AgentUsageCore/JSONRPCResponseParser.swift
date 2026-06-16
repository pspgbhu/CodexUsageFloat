import Foundation

public struct JSONRPCResponsePayload: Equatable {
    public var id: Int
    public var payload: Data

    public init(id: Int, payload: Data) {
        self.id = id
        self.payload = payload
    }
}

public enum JSONRPCResponseParser {
    public static func parseResultLine(_ line: Data) throws -> JSONRPCResponsePayload? {
        let object = try JSONSerialization.jsonObject(with: line, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw UsageProviderError.invalidResponse("JSON-RPC message was not an object.")
        }

        guard let id = parseID(dictionary["id"]) else {
            return nil
        }

        if let error = dictionary["error"] as? [String: Any] {
            let code = (error["code"] as? NSNumber)?.intValue
            let message = error["message"] as? String ?? "Agent usage provider returned an error."
            throw UsageProviderError.rpc(code: code, message: message)
        }

        guard let result = dictionary["result"] else {
            throw UsageProviderError.invalidResponse("JSON-RPC response did not include result.")
        }

        let payload: Data
        if result is NSNull {
            payload = Data("null".utf8)
        } else {
            payload = try JSONSerialization.data(withJSONObject: result, options: [])
        }

        return JSONRPCResponsePayload(id: id, payload: payload)
    }

    private static func parseID(_ rawID: Any?) -> Int? {
        if let number = rawID as? NSNumber {
            return number.intValue
        }

        if let string = rawID as? String {
            return Int(string)
        }

        return nil
    }
}
