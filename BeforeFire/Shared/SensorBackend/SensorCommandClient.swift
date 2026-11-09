import CryptoKit
import Foundation

/// A signed command that the app sends to the sensor through the backend
/// (`POST /v1/devices/{deviceId}/commands`). The backend adds `origin:"app"` and
/// forwards it to the sensor over MQTT; the sensor checks the signature with the
/// setup code (PoP) from its label.
///
/// Must agree with `command.Request` / `SigningString` in the backend
/// (`internal/command/request.go`) and `tanganiCmd()` in the firmware
/// (`Sensor/KirimBackend.cpp`).
nonisolated struct SensorCommand: Encodable {
    enum Action: String, Encodable {
        case registerPushToken = "register_push_token"
        case unregisterPushToken = "unregister_push_token"
    }

    let action: Action
    let requestId: String
    let issuedAt: Int64
    let pushToken: String
    let signature: String

    /// Builds and signs a command. `requestId` is a fresh UUID (matches the backend's
    /// `^[A-Za-z0-9-]{8,64}$`), `issuedAt` is the phone clock in Unix seconds.
    init(action: Action, pushToken: String, link: SensorBackendLink, now: Date = Date()) {
        self.action = action
        requestId = UUID().uuidString
        issuedAt = Int64(now.timeIntervalSince1970)
        self.pushToken = pushToken.lowercased()
        signature = Self.sign(
            setupCode: link.setupCode, deviceID: link.deviceID, action: action,
            requestId: requestId, issuedAt: issuedAt, pushToken: self.pushToken
        )
    }

    /// `hex(HMAC-SHA256(key: setup code, message: signing string))`, where the signing string is
    /// `beforefire-cmd-v1\n<deviceId>\n<action>\n<requestId>\n<issuedAt>\n<pushToken>` with no trailing newline.
    static func sign(setupCode: String, deviceID: String, action: Action,
                     requestId: String, issuedAt: Int64, pushToken: String) -> String {
        let text = [
            SensorBackendConfiguration.commandSigningVersion,
            deviceID, action.rawValue, requestId, String(issuedAt), pushToken,
        ].joined(separator: "\n")
        let code = HMAC<SHA256>.authenticationCode(for: Data(text.utf8), using: SymmetricKey(data: Data(setupCode.utf8)))
        return code.map { String(format: "%02x", $0) }.joined()
    }
}

/// The sensor's answer, from `beforefire/<id>/ack`. `result` is `done` or `rejected`.
nonisolated struct SensorCommandAck: Decodable, Equatable {
    let requestId: String
    let result: String
    let reason: String?
}

nonisolated enum SensorCommandError: Error, Equatable {
    /// No response, for example because the phone is not on the home Wi-Fi or the server is off.
    case backendUnreachable
    /// The sensor rejected the command (for example `bad_signature` or `token_storage_full`).
    case rejected(reason: String)
    /// The sensor is offline, so the backend could not reach it.
    case deviceOffline
    /// The sensor did not answer in time.
    case deviceNoAnswer
    /// The backend refused the request format (for example a wrong signature length or stale clock).
    case invalidRequest
    case unexpectedResponse
}

protocol SensorCommandSending {
    /// Throws `SensorCommandError`, or `CancellationError` when the task is cancelled.
    func send(_ command: SensorCommand, for link: SensorBackendLink) async throws -> SensorCommandAck
}

/// Sends a command with `POST /v1/devices/{deviceId}/commands` and waits for the sensor's ack.
struct URLSessionSensorCommandClient: SensorCommandSending {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ command: SensorCommand, for link: SensorBackendLink) async throws -> SensorCommandAck {
        var request = URLRequest(
            url: link.commandsURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: SensorBackendConfiguration.commandTimeout
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(command)

        let body: Data
        let response: URLResponse
        do {
            (body, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw SensorCommandError.backendUnreachable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SensorCommandError.unexpectedResponse
        }
        switch httpResponse.statusCode {
        case 200:
            guard let ack = try? JSONDecoder().decode(SensorCommandAck.self, from: body) else {
                throw SensorCommandError.unexpectedResponse
            }
            return ack
        case 400:
            throw SensorCommandError.invalidRequest
        case 422:
            let detail = try? JSONDecoder().decode(BackendErrorResponse.self, from: body)
            throw SensorCommandError.rejected(reason: detail?.detail ?? "")
        case 503:
            throw SensorCommandError.deviceOffline
        case 504:
            throw SensorCommandError.deviceNoAnswer
        default:
            throw SensorCommandError.unexpectedResponse
        }
    }
}

/// The error body of the backend, for example `{"error":"command_rejected","detail":"bad_signature"}`.
private nonisolated struct BackendErrorResponse: Decodable {
    let error: String
    let detail: String?
}
