import Foundation

enum ActivityStatus: String {
    case idle
    case running
    case done
    case needsApproval = "need_approval"

    init?(pathComponent: String) {
        let aliases: [String: ActivityStatus] = [
            "done": .done,
            "idle": .idle,
            "running": .running,
            "thinking": .running,
            "need_attention": .needsApproval,
            "needs_attention": .needsApproval,
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
        case .done:
            return "Done"
        case .needsApproval:
            return "Needs Attention"
        }
    }
}
