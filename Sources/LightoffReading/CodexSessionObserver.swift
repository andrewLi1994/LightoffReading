import Foundation

struct CodexSessionObserverSnapshot {
    let status: String
    let activeFilePath: String?
    let activeAgentID: String?
    let fileOffset: UInt64
    let fileSize: UInt64?
    let pendingRequestUserInputCount: Int
    let lastEvent: String
    let lastReadDate: Date?
    let lastError: String?

    var dictionary: [String: Any] {
        [
            "status": status,
            "activeFilePath": activeFilePath ?? NSNull(),
            "activeAgentID": activeAgentID ?? NSNull(),
            "fileOffset": fileOffset,
            "fileSize": fileSize ?? NSNull(),
            "pendingRequestUserInputCount": pendingRequestUserInputCount,
            "lastEvent": lastEvent,
            "lastReadAt": lastReadDate?.iso8601String ?? NSNull(),
            "lastError": lastError ?? NSNull()
        ]
    }
}

final class CodexSessionObserver {
    private static let queueKey = DispatchSpecificKey<String>()
    private static let queueContext = "LightoffReading.CodexSessionObserver"

    var onPendingRequestUserInputChange: ((String, Set<String>) -> Void)?
    var onStatusChange: ((String) -> Void)?

    private let fileManager: FileManager
    private let sessionsURL: URL
    private let queue = DispatchQueue(label: "LightoffReading.CodexSessionObserver", qos: .utility)
    private let maxReadBytesPerTick = 512 * 1024
    private let fileRefreshTickInterval = 8

    private var timer: DispatchSourceTimer?
    private var activeFileURL: URL?
    private var activeAgentID: String?
    private var fileOffset: UInt64 = 0
    private var lineBuffer = ""
    private var pendingCallIDs: Set<String> = []
    private var tickCount = 0
    private var statusDescription = "Observer: Offline"
    private var lastEvent = "none"
    private var lastReadDate: Date?
    private var lastError: String?

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.sessionsURL = homeDirectory
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
        queue.setSpecific(key: Self.queueKey, value: Self.queueContext)
    }

    var currentStatusDescription: String {
        statusDescription
    }

    func snapshot() -> CodexSessionObserverSnapshot {
        if DispatchQueue.getSpecific(key: Self.queueKey) == Self.queueContext {
            return makeSnapshot()
        }

        return queue.sync {
            makeSnapshot()
        }
    }

    private func makeSnapshot() -> CodexSessionObserverSnapshot {
        CodexSessionObserverSnapshot(
                status: statusDescription,
                activeFilePath: activeFileURL?.path,
                activeAgentID: activeAgentID,
                fileOffset: fileOffset,
                fileSize: activeFileURL.flatMap(fileSize),
                pendingRequestUserInputCount: pendingCallIDs.count,
                lastEvent: lastEvent,
                lastReadDate: lastReadDate,
                lastError: lastError
        )
    }

    func start() {
        guard timer == nil else {
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(750), leeway: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        timer.resume()
        self.timer = timer
        setStatusDescription("Observer: Starting")
    }

    func stop() {
        timer?.cancel()
        timer = nil

        queue.async { [weak self] in
            self?.clearActiveFile(notify: true)
            self?.setStatusDescription("Observer: Offline")
        }
    }

    private func poll() {
        tickCount += 1

        if activeFileURL == nil || tickCount % fileRefreshTickInterval == 0 {
            switchToLatestFileIfNeeded()
        }

        guard let activeFileURL else {
            return
        }

        readNewLines(from: activeFileURL)
    }

    private func switchToLatestFileIfNeeded() {
        let latestFileURL = latestRolloutFileURL()

        guard latestFileURL != activeFileURL else {
            return
        }

        clearActiveFile(notify: true)

        guard let latestFileURL else {
            setStatusDescription("Observer: No active session")
            return
        }

        activeFileURL = latestFileURL
        activeAgentID = Self.agentID(for: latestFileURL)
        fileOffset = fileSize(for: latestFileURL) ?? 0
        lineBuffer = ""
        lastError = nil
        lastEvent = "attached"
        setStatusDescription("Observer: \(latestFileURL.lastPathComponent)")
    }

    private func readNewLines(from fileURL: URL) {
        guard let fileSize = fileSize(for: fileURL) else {
            lastError = "Could not read session file size."
            clearActiveFile(notify: true)
            return
        }

        if fileSize < fileOffset {
            fileOffset = fileSize
            lineBuffer = ""
            clearPendingCallIDs(notify: true)
        }

        guard fileSize > fileOffset else {
            return
        }

        let bytesToRead = min(Int(fileSize - fileOffset), maxReadBytesPerTick)
        lastReadDate = Date()

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            lastError = "Could not open session file."
            clearActiveFile(notify: true)
            setStatusDescription("Observer: Cannot read session")
            return
        }

        handle.seek(toFileOffset: fileOffset)
        let data = handle.readData(ofLength: bytesToRead)
        handle.closeFile()
        fileOffset += UInt64(data.count)

        guard !data.isEmpty,
              let chunk = String(data: data, encoding: .utf8) else {
            lastError = data.isEmpty ? nil : "Could not decode session bytes as UTF-8."
            return
        }

        lineBuffer += chunk
        let lines = lineBuffer.components(separatedBy: "\n")
        lineBuffer = lines.last ?? ""

        var didChange = false
        for line in lines.dropLast() {
            didChange = process(line: line) || didChange
        }

        if didChange {
            notifyPendingCallIDs()
        }
    }

    private func process(line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty,
              let data = trimmedLine.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["payload"] as? [String: Any],
              let payloadType = payload["type"] as? String,
              let callID = payload["call_id"] as? String else {
            return false
        }

        if payloadType == "function_call",
           payload["name"] as? String == "request_user_input" {
            let previous = pendingCallIDs
            pendingCallIDs.insert(callID)
            lastEvent = "function_call request_user_input"
            lastError = nil
            return pendingCallIDs != previous
        }

        if payloadType == "function_call_output" {
            let didRemove = pendingCallIDs.remove(callID) != nil
            if didRemove {
                lastEvent = "function_call_output"
                lastError = nil
            }
            return didRemove
        }

        return false
    }

    private func clearActiveFile(notify: Bool) {
        clearPendingCallIDs(notify: notify)
        activeFileURL = nil
        activeAgentID = nil
        fileOffset = 0
        lineBuffer = ""
        lastEvent = "detached"
    }

    private func clearPendingCallIDs(notify: Bool) {
        guard !pendingCallIDs.isEmpty else {
            return
        }

        pendingCallIDs.removeAll()

        if notify {
            notifyPendingCallIDs()
        }
    }

    private func notifyPendingCallIDs() {
        guard let activeAgentID else {
            return
        }

        let callIDs = pendingCallIDs
        DispatchQueue.main.async { [weak self] in
            self?.onPendingRequestUserInputChange?(activeAgentID, callIDs)
        }
    }

    private func setStatusDescription(_ description: String) {
        guard statusDescription != description else {
            return
        }

        statusDescription = description
        DispatchQueue.main.async { [weak self] in
            self?.onStatusChange?(description)
        }
    }

    private func latestRolloutFileURL() -> URL? {
        candidateDayDirectories(limit: 7)
            .flatMap(rolloutFiles(in:))
            .max { lhs, rhs in
                (modificationDate(for: lhs) ?? .distantPast) < (modificationDate(for: rhs) ?? .distantPast)
            }
    }

    private func candidateDayDirectories(limit: Int) -> [URL] {
        directories(in: sessionsURL)
            .sorted(by: descendingPathComponent)
            .flatMap { yearURL in
                directories(in: yearURL)
                    .sorted(by: descendingPathComponent)
                    .flatMap { monthURL in
                        directories(in: monthURL)
                            .sorted(by: descendingPathComponent)
                    }
            }
            .prefix(limit)
            .map { $0 }
    }

    private func rolloutFiles(in directoryURL: URL) -> [URL] {
        (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ))?
            .filter { url in
                url.lastPathComponent.hasPrefix("rollout-") && url.pathExtension == "jsonl"
            } ?? []
    }

    private func directories(in directoryURL: URL) -> [URL] {
        (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ))?
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            } ?? []
    }

    private func fileSize(for fileURL: URL) -> UInt64? {
        guard let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return nil
        }

        return UInt64(size)
    }

    private func modificationDate(for fileURL: URL) -> Date? {
        try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func descendingPathComponent(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.lastPathComponent > rhs.lastPathComponent
    }

    private static func agentID(for fileURL: URL) -> String {
        "session:\(fileURL.deletingPathExtension().lastPathComponent)"
    }
}

private extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}
