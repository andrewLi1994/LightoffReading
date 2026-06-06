import Foundation

enum ActivityStatus: String {
    case idle
    case running
    case needsApproval = "need_approval"

    init?(pathComponent: String) {
        let aliases: [String: ActivityStatus] = [
            "done": .idle,
            "idle": .idle,
            "running": .running,
            "thinking": .running,
            "need_approval": .needsApproval,
            "needs_approval": .needsApproval
        ]

        guard let status = aliases[pathComponent] else {
            return nil
        }

        self = status
    }

    var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .running:
            return "Running"
        case .needsApproval:
            return "Needs Approval"
        }
    }
}
