import Foundation

final class RollingSeries {
    private(set) var samples: [MetricSample] = []
    private let retention: TimeInterval

    init(retention: TimeInterval) {
        self.retention = retention
    }

    func append(_ sample: MetricSample) {
        samples.append(sample)
        prune(olderThan: sample.timestamp.addingTimeInterval(-retention))
    }

    private func prune(olderThan cutoff: Date) {
        if let index = samples.firstIndex(where: { $0.timestamp >= cutoff }) {
            if index > 0 {
                samples.removeFirst(index)
            }
        } else {
            samples.removeAll()
        }
    }
}
