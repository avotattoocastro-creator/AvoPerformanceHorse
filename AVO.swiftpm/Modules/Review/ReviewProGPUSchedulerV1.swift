import Foundation

// MARK: - REVIEW PRO PHASE 100
// GPU Scheduler V1

public enum ReviewProRenderPriority: Int, Codable {
    case low = 0
    case normal = 1
    case high = 2
    case realtime = 3
}

public struct ReviewProRenderTask: Codable, Hashable {
    public var id: UUID
    public var name: String
    public var priority: ReviewProRenderPriority

    public init(name: String,
                priority: ReviewProRenderPriority) {
        self.id = UUID()
        self.name = name
        self.priority = priority
    }
}

public final class ReviewProGPUSchedulerV1 {

    private(set) public var queue: [ReviewProRenderTask] = []

    public init() {}

    public func enqueue(_ task: ReviewProRenderTask) {
        queue.append(task)
        queue.sort {
            $0.priority.rawValue > $1.priority.rawValue
        }
    }

    public func nextTask() -> ReviewProRenderTask? {
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }

    public func clear() {
        queue.removeAll()
    }
}
