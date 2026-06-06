import Darwin
import Foundation

enum ActivityStatusServerError: LocalizedError {
    case socketFailed
    case bindFailed
    case listenFailed

    var errorDescription: String? {
        switch self {
        case .socketFailed:
            return "Could not create the local activity status socket."
        case .bindFailed:
            return "Could not bind the local activity status socket. Another process may already be using the port."
        case .listenFailed:
            return "Could not listen on the local activity status socket."
        }
    }
}

final class ActivityStatusServer {
    static let host = "127.0.0.1"
    static let port: UInt16 = 38561

    var onStatus: ((ActivityStatus) -> Void)?
    var onEvent: ((ActivityStatusEvent) -> Void)?
    var onObserverDebug: (() -> [String: Any])?

    private var socketFD: Int32 = -1
    private var source: DispatchSourceRead?

    var isRunning: Bool {
        source != nil
    }

    func start() throws {
        guard source == nil else {
            return
        }

        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw ActivityStatusServerError.socketFailed
        }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK)

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = Self.port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr(Self.host))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.bind(fd, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            close(fd)
            throw ActivityStatusServerError.bindFailed
        }

        guard listen(fd, SOMAXCONN) == 0 else {
            close(fd)
            throw ActivityStatusServerError.listenFailed
        }

        socketFD = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in
            self?.acceptPendingConnections()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
        socketFD = -1
    }

    private func acceptPendingConnections() {
        while true {
            var address = sockaddr()
            var addressLength = socklen_t(MemoryLayout<sockaddr>.size)
            let clientFD = accept(socketFD, &address, &addressLength)

            guard clientFD >= 0 else {
                return
            }

            _ = fcntl(clientFD, F_SETFL, fcntl(clientFD, F_GETFL, 0) & ~O_NONBLOCK)
            handle(clientFD: clientFD)
        }
    }

    private func handle(clientFD: Int32) {
        let request = readRequest(from: clientFD)
        if request.map(isObserverDebugRequest) == true {
            if let onObserverDebug {
                writeResponse(to: clientFD, code: 200, body: Self.jsonBody(for: onObserverDebug()))
                close(clientFD)
            } else {
                writeResponse(to: clientFD, code: 404, body: "{\"error\":\"observer debug unavailable\"}\n")
                close(clientFD)
            }
            return
        }

        let event = request.flatMap(parseEvent)

        if let event {
            onEvent?(event)
            onStatus?(event.status)
            writeResponse(to: clientFD, code: 200, body: responseBody(for: event))
        } else {
            writeResponse(to: clientFD, code: 404, body: "{\"error\":\"unknown status\"}\n")
        }

        close(clientFD)
    }

    private func readRequest(from clientFD: Int32) -> String? {
        var bytes: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 1024)

        while bytes.count < 8192 {
            let count = recv(clientFD, &buffer, buffer.count, 0)

            if count > 0 {
                bytes.append(contentsOf: buffer.prefix(count))
                if bytes.containsHeaderTerminator {
                    break
                }
            } else {
                break
            }
        }

        guard !bytes.isEmpty else {
            return nil
        }

        return String(bytes: bytes, encoding: .utf8)
    }

    private func parseEvent(from request: String) -> ActivityStatusEvent? {
        guard let requestLine = request.split(whereSeparator: \.isNewline).first else {
            return nil
        }

        let parts = requestLine.split(whereSeparator: \.isWhitespace)
        guard parts.count >= 2 else {
            return nil
        }

        let path = String(parts[1])
        let prefix = "/state/"
        guard path.hasPrefix(prefix) else {
            return nil
        }

        let stateAndQuery = String(path.dropFirst(prefix.count))
        let splitPath = stateAndQuery.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let component = splitPath.first.map(String.init) ?? ""
        let normalizedComponent = component
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .removingPercentEncoding?
            .lowercased() ?? component.lowercased()

        guard let status = ActivityStatus(pathComponent: normalizedComponent) else {
            return nil
        }

        let query = splitPath.count > 1 ? String(splitPath[1]) : ""
        let agentID = Self.agentID(from: query)

        return ActivityStatusEvent(status: status, agentID: agentID)
    }

    private func isObserverDebugRequest(_ request: String) -> Bool {
        guard let requestLine = request.split(whereSeparator: \.isNewline).first else {
            return false
        }

        let parts = requestLine.split(whereSeparator: \.isWhitespace)
        guard parts.count >= 2 else {
            return false
        }

        let path = String(parts[1])
        return path == "/debug/observer" || path.hasPrefix("/debug/observer?")
    }

    private static func agentID(from query: String) -> String {
        guard !query.isEmpty else {
            return ActivityStatusEvent.defaultAgentID
        }

        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.first == "agent" else {
                continue
            }

            let rawValue = parts.count > 1 ? String(parts[1]) : ""
            let decodedValue = rawValue
                .replacingOccurrences(of: "+", with: " ")
                .removingPercentEncoding ?? rawValue
            let normalizedValue = decodedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalizedValue.isEmpty ? ActivityStatusEvent.defaultAgentID : normalizedValue
        }

        return ActivityStatusEvent.defaultAgentID
    }

    private func responseBody(for event: ActivityStatusEvent) -> String {
        let object = [
            "status": event.status.rawValue,
            "agent": event.agentID
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []),
              let body = String(data: data, encoding: .utf8) else {
            return "{\"status\":\"\(event.status.rawValue)\"}\n"
        }

        return "\(body)\n"
    }

    private static func jsonBody(for object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let body = String(data: data, encoding: .utf8) else {
            return "{\"error\":\"invalid debug object\"}\n"
        }

        return "\(body)\n"
    }

    private func writeResponse(to clientFD: Int32, code: Int, body: String) {
        let reason = code == 200 ? "OK" : "Not Found"
        let response = """
        HTTP/1.1 \(code) \(reason)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        _ = response.withCString { pointer in
            send(clientFD, pointer, strlen(pointer), 0)
        }
    }
}

private extension Array where Element == UInt8 {
    var containsHeaderTerminator: Bool {
        count >= 4 && indices.dropLast(3).contains { index in
            self[index] == 13
                && self[index + 1] == 10
                && self[index + 2] == 13
                && self[index + 3] == 10
        }
    }
}
