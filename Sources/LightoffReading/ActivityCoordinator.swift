import Foundation

struct ActivityStatusEvent {
    static let defaultAgentID = "default"

    let status: ActivityStatus
    let agentID: String

    init(status: ActivityStatus, agentID: String = Self.defaultAgentID) {
        let normalizedAgentID = agentID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.status = status
        self.agentID = normalizedAgentID.isEmpty ? Self.defaultAgentID : normalizedAgentID
    }
}

final class ActivityCoordinator {
    var onStatus: ((ActivityStatus) -> Void)?

    private struct AgentActivity {
        var status: ActivityStatus = .idle
        var requestUserInputCallIDs: Set<String> = []

        var needsAttention: Bool {
            status == .needsApproval || !requestUserInputCallIDs.isEmpty
        }
    }

    private var agents: [String: AgentActivity] = [:]

    var currentStatus: ActivityStatus {
        aggregateStatus()
    }

    func apply(_ event: ActivityStatusEvent) {
        var activity = agents[event.agentID] ?? AgentActivity()

        switch event.status {
        case .idle:
            activity.status = .idle
        case .running:
            activity.status = .running
        case .done:
            activity.status = .idle
        case .needsApproval:
            activity.status = .needsApproval
        }

        store(activity, for: event.agentID)

        if event.status == .done {
            emitDoneIfVisible()
        } else {
            emit(aggregateStatus())
        }
    }

    func setRequestUserInputCallIDs(_ callIDs: Set<String>, for agentID: String) {
        var activity = agents[agentID] ?? AgentActivity()
        guard activity.requestUserInputCallIDs != callIDs else {
            return
        }

        activity.requestUserInputCallIDs = callIDs
        store(activity, for: agentID)
        emit(aggregateStatus())
    }

    func reset() {
        agents.removeAll()
        emit(.idle)
    }

    private func store(_ activity: AgentActivity, for agentID: String) {
        if activity.status == .idle && activity.requestUserInputCallIDs.isEmpty {
            agents.removeValue(forKey: agentID)
        } else {
            agents[agentID] = activity
        }
    }

    private func emitDoneIfVisible() {
        let postDoneStatus = aggregateStatus()

        guard postDoneStatus != .needsApproval else {
            emit(.needsApproval)
            return
        }

        emit(.done)

        if postDoneStatus != .idle {
            emit(postDoneStatus)
        }
    }

    private func aggregateStatus() -> ActivityStatus {
        if agents.values.contains(where: \.needsAttention) {
            return .needsApproval
        }

        if agents.values.contains(where: { $0.status == .running }) {
            return .running
        }

        return .idle
    }

    private func emit(_ status: ActivityStatus) {
        onStatus?(status)
    }
}
