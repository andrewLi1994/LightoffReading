import Foundation

enum CodexHookManagerError: LocalizedError {
    case invalidHooksFile
    case unsupportedHooksShape
    case unsupportedEventShape(String)
    case couldNotCreateConfigDirectory

    var errorDescription: String? {
        switch self {
        case .invalidHooksFile:
            return "The existing Codex hooks.json is not valid JSON object data."
        case .unsupportedHooksShape:
            return "The existing Codex hooks.json has a hooks value that is not an object."
        case let .unsupportedEventShape(event):
            return "The existing Codex hooks.json has an unsupported value for \(event)."
        case .couldNotCreateConfigDirectory:
            return "Could not create ~/.codex."
        }
    }
}

final class CodexHookManager {
    private static let marker = "LightoffReading Codex Integration"

    private let fileManager = FileManager.default
    private let hooksURL: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.hooksURL = homeDirectory
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("hooks.json")
    }

    var configPath: String {
        hooksURL.path
    }

    var configURL: URL {
        hooksURL
    }

    func isInstalled() -> Bool {
        guard let root = try? loadRoot(),
              let hooks = root["hooks"] as? [String: Any] else {
            return false
        }

        return hooks.values.contains { value in
            guard let groups = value as? [[String: Any]] else {
                return false
            }

            return groups.contains { group in
                guard let handlers = group["hooks"] as? [[String: Any]] else {
                    return false
                }

                return handlers.contains(where: isManagedHook)
            }
        }
    }

    func install() throws {
        try ensureConfigDirectory()
        var root = try loadRoot()
        var hooks = try loadHooksObject(from: root)

        for spec in Self.hookSpecs {
            var groups = try loadGroups(for: spec.event, from: hooks)
            groups = groups.map { removeManagedHooks(from: $0) }.filter { group in
                if let handlers = group["hooks"] as? [[String: Any]] {
                    return !handlers.isEmpty
                }
                return true
            }
            groups.append([
                "hooks": [
                    [
                        "type": "command",
                        "command": spec.command,
                        "timeout": 5,
                        "statusMessage": "\(Self.marker): \(spec.status.displayName)"
                    ]
                ]
            ])
            hooks[spec.event] = groups
        }

        root["hooks"] = hooks
        try writeRoot(root)
    }

    func uninstall() throws {
        guard fileManager.fileExists(atPath: hooksURL.path) else {
            return
        }

        var root = try loadRoot()
        var hooks = try loadHooksObject(from: root)

        for (event, value) in hooks {
            guard let groups = value as? [[String: Any]] else {
                throw CodexHookManagerError.unsupportedEventShape(event)
            }

            let filteredGroups = groups.map { removeManagedHooks(from: $0) }.filter { group in
                if let handlers = group["hooks"] as? [[String: Any]] {
                    return !handlers.isEmpty
                }
                return true
            }

            if filteredGroups.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = filteredGroups
            }
        }

        root["hooks"] = hooks
        try writeRoot(root)
    }

    private func ensureConfigDirectory() throws {
        let directoryURL = hooksURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw CodexHookManagerError.couldNotCreateConfigDirectory
            }
            return
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func loadRoot() throws -> [String: Any] {
        guard fileManager.fileExists(atPath: hooksURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: hooksURL)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = object as? [String: Any] else {
            throw CodexHookManagerError.invalidHooksFile
        }
        return root
    }

    private func loadHooksObject(from root: [String: Any]) throws -> [String: Any] {
        guard let value = root["hooks"] else {
            return [:]
        }

        guard let hooks = value as? [String: Any] else {
            throw CodexHookManagerError.unsupportedHooksShape
        }

        return hooks
    }

    private func loadGroups(for event: String, from hooks: [String: Any]) throws -> [[String: Any]] {
        guard let value = hooks[event] else {
            return []
        }

        guard let groups = value as? [[String: Any]] else {
            throw CodexHookManagerError.unsupportedEventShape(event)
        }

        return groups
    }

    private func writeRoot(_ root: [String: Any]) throws {
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: hooksURL, options: .atomic)
    }

    private func removeManagedHooks(from group: [String: Any]) -> [String: Any] {
        guard let handlers = group["hooks"] as? [[String: Any]] else {
            return group
        }

        var updatedGroup = group
        updatedGroup["hooks"] = handlers.filter { !isManagedHook($0) }
        return updatedGroup
    }

    private func isManagedHook(_ hook: [String: Any]) -> Bool {
        if let statusMessage = hook["statusMessage"] as? String,
           statusMessage.contains(Self.marker) {
            return true
        }

        guard let command = hook["command"] as? String else {
            return false
        }

        return command.contains("127.0.0.1:\(ActivityStatusServer.port)/state/")
    }

    private static var hookSpecs: [(event: String, status: ActivityStatus, command: String)] {
        [
            ("UserPromptSubmit", .running, command(for: .running)),
            ("PreToolUse", .running, command(for: .running)),
            ("PermissionRequest", .needsApproval, command(for: .needsApproval)),
            ("Stop", .idle, command(for: .idle))
        ]
    }

    private static func command(for status: ActivityStatus) -> String {
        let path: String
        switch status {
        case .idle:
            path = "done"
        case .running:
            path = "running"
        case .needsApproval:
            path = "need_approval"
        }

        return "/usr/bin/curl -fsS --max-time 2 http://127.0.0.1:\(ActivityStatusServer.port)/state/\(path) >/dev/null 2>&1 || true"
    }
}
