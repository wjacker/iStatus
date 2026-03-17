import SwiftUI

private let barWidth: CGFloat = 3
private let barSpacing: CGFloat = 1

struct MiniChartView: View {
    let samples: [MetricSample]
    let accent: Color
    let range: TimeInterval
    let bucketInterval: TimeInterval

    @State private var hoverIndex: Int?

    var body: some View {
        GeometryReader { proxy in
            let bars = bucketedBars(in: proxy.size)
            let displayBars = bars

            ZStack(alignment: .bottomLeading) {
                chartGrid(in: proxy.size)

                HStack(alignment: .bottom, spacing: barSpacing) {
                    Spacer(minLength: 0)
                    ForEach(Array(displayBars.enumerated()), id: \.offset) { index, bar in
                        BarCell(bar: bar, accent: accent)
                            .onHover { hovering in
                                hoverIndex = hovering ? index : nil
                            }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)

                if let hoverIndex, hoverIndex < displayBars.count {
                    SingleTooltip(bar: displayBars[hoverIndex])
                        .position(x: tooltipX(for: hoverIndex, barCount: displayBars.count, width: proxy.size.width), y: 12)
                        .allowsHitTesting(false)
                        .zIndex(2)
                }
            }
        }
    }

    private func tooltipX(for index: Int, barCount: Int, width: CGFloat) -> CGFloat {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(max(barCount - 1, 0)) * barSpacing
        let leftOffset = max(width - totalWidth, 0)
        return leftOffset + CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
    }

    private func chartGrid(in size: CGSize) -> some View {
        let rows: Int = 4
        return Path { path in
            for row in 1..<rows {
                let y = size.height * CGFloat(row) / CGFloat(rows)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }

    private func bucketedBars(in size: CGSize) -> [Bar] {
        let end = alignedNow()
        let start = end.addingTimeInterval(-range)
        let duration = max(range, 1)

        let bucketCount = max(Int(duration / bucketInterval), 1)
        let bucketDuration = bucketInterval
        var buckets: [Bucket] = Array(repeating: Bucket(), count: bucketCount)

        for sample in samples {
            guard sample.timestamp >= start && sample.timestamp <= end else { continue }
            let offset = sample.timestamp.timeIntervalSince(start)
            let index = min(max(Int(offset / bucketDuration), 0), bucketCount - 1)
            buckets[index].add(sample)
        }

        let maxValue = max(buckets.compactMap { $0.average }.max() ?? 1, 1)

        let maxBars = max(Int(size.width / (barWidth + barSpacing)), 1)
        let groupSize = max(Int(ceil(Double(bucketCount) / Double(maxBars))), 1)
        let grouped = stride(from: 0, to: buckets.count, by: groupSize).map { startIndex -> (Bucket, Date) in
            var merged = Bucket()
            let endIndex = min(startIndex + groupSize, buckets.count)
            for idx in startIndex..<endIndex {
                merged.sum += buckets[idx].sum
                merged.count += buckets[idx].count
            }
            let timestamp = start.addingTimeInterval(bucketDuration * Double(endIndex))
            return (merged, timestamp)
        }

        return grouped.map { bucket, timestamp in
            guard let value = bucket.average else {
                return Bar(value: nil, height: 0, width: barWidth, timestamp: timestamp)
            }
            let height = size.height * CGFloat(value / maxValue)
            return Bar(value: value, height: max(height, 1), width: barWidth, timestamp: timestamp)
        }
    }

    private func alignedNow() -> Date {
        let interval = max(bucketInterval, 1)
        let now = Date().timeIntervalSince1970
        let aligned = floor(now / interval) * interval
        return Date(timeIntervalSince1970: aligned)
    }

    private struct Bucket {
        var sum: Double = 0
        var count: Int = 0

        mutating func add(_ sample: MetricSample) {
            sum += sample.value
            count += 1
        }

        var average: Double? {
            guard count > 0 else { return nil }
            return sum / Double(count)
        }
    }

    private struct Bar {
        let value: Double?
        let height: CGFloat
        let width: CGFloat
        let timestamp: Date
    }

    private struct BarCell: View {
        let bar: Bar
        let accent: Color

        var body: some View {
            RoundedRectangle(cornerRadius: 2)
                .fill(bar.value == nil ? Color.clear : accent.opacity(0.85))
                .frame(width: bar.width, height: bar.height)
        }
    }

    private struct SingleTooltip: View {
        let bar: Bar

        var body: some View {
            VStack(spacing: 2) {
                Text(Self.timeFormatter.string(from: bar.timestamp))
                Text(String(format: "%.1f", bar.value ?? 0))
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(6)
        }

        private static let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter
        }()
    }
}

struct DualBarChartView: View {
    let upSamples: [MetricSample]
    let downSamples: [MetricSample]
    let upColor: Color
    let downColor: Color
    let range: TimeInterval
    let bucketInterval: TimeInterval

    @State private var hoverIndex: Int?

    var body: some View {
        GeometryReader { proxy in
            let bars = bucketedBars(in: proxy.size)
            let displayBars = bars

            ZStack {
                chartGrid(in: proxy.size)

                HStack(alignment: .center, spacing: barSpacing) {
                    Spacer(minLength: 0)
                    ForEach(Array(displayBars.enumerated()), id: \.offset) { index, bar in
                        DualBarCell(bar: bar, upColor: upColor, downColor: downColor, isHovering: hoverIndex == index)
                            .frame(width: bar.width)
                            .onHover { hovering in
                                hoverIndex = hovering ? index : nil
                            }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            }
        }
    }

    private func chartGrid(in size: CGSize) -> some View {
        let rows: Int = 4
        return Path { path in
            for row in 0...rows {
                let y = size.height * CGFloat(row) / CGFloat(rows)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }

    private func bucketedBars(in size: CGSize) -> [DualBar] {
        let end = alignedNow()
        let start = end.addingTimeInterval(-range)
        let duration = max(range, 1)

        let bucketCount = max(Int(duration / bucketInterval), 1)
        let bucketDuration = bucketInterval
        var upBuckets: [Bucket] = Array(repeating: Bucket(), count: bucketCount)
        var downBuckets: [Bucket] = Array(repeating: Bucket(), count: bucketCount)

        for sample in upSamples {
            guard sample.timestamp >= start && sample.timestamp <= end else { continue }
            let offset = sample.timestamp.timeIntervalSince(start)
            let index = min(max(Int(offset / bucketDuration), 0), bucketCount - 1)
            upBuckets[index].add(sample)
        }

        for sample in downSamples {
            guard sample.timestamp >= start && sample.timestamp <= end else { continue }
            let offset = sample.timestamp.timeIntervalSince(start)
            let index = min(max(Int(offset / bucketDuration), 0), bucketCount - 1)
            downBuckets[index].add(sample)
        }

        let maxUp = upBuckets.compactMap { $0.average }.max() ?? 1
        let maxDown = downBuckets.compactMap { $0.average }.max() ?? 1
        let maxValue = max(maxUp, maxDown, 1)
        let halfHeight = (size.height - 1) / 2

        let maxBars = max(Int(size.width / (barWidth + barSpacing)), 1)
        let groupSize = max(Int(ceil(Double(bucketCount) / Double(maxBars))), 1)
        let grouped = stride(from: 0, to: bucketCount, by: groupSize).map { startIndex -> (Bucket, Bucket, Date) in
            var upMerged = Bucket()
            var downMerged = Bucket()
            let endIndex = min(startIndex + groupSize, bucketCount)
            for idx in startIndex..<endIndex {
                upMerged.sum += upBuckets[idx].sum
                upMerged.count += upBuckets[idx].count
                downMerged.sum += downBuckets[idx].sum
                downMerged.count += downBuckets[idx].count
            }
            let timestamp = start.addingTimeInterval(bucketDuration * Double(endIndex))
            return (upMerged, downMerged, timestamp)
        }

        return grouped.map { upBucket, downBucket, timestamp in
            let upValue = upBucket.average
            let downValue = downBucket.average
            let upHeight = upValue == nil ? 0 : CGFloat(upValue! / maxValue) * halfHeight
            let downHeight = downValue == nil ? 0 : CGFloat(downValue! / maxValue) * halfHeight
            return DualBar(
                upValue: upValue,
                downValue: downValue,
                upHeight: max(upHeight, 1),
                downHeight: max(downHeight, 1),
                width: barWidth,
                timestamp: timestamp
            )
        }
    }

    private func alignedNow() -> Date {
        let interval = max(bucketInterval, 1)
        let now = Date().timeIntervalSince1970
        let aligned = floor(now / interval) * interval
        return Date(timeIntervalSince1970: aligned)
    }

    private struct Bucket {
        var sum: Double = 0
        var count: Int = 0

        mutating func add(_ sample: MetricSample) {
            sum += sample.value
            count += 1
        }

        var average: Double? {
            guard count > 0 else { return nil }
            return sum / Double(count)
        }
    }

    private struct DualBar {
        let upValue: Double?
        let downValue: Double?
        let upHeight: CGFloat
        let downHeight: CGFloat
        let width: CGFloat
        let timestamp: Date
    }

    private struct DualBarCell: View {
        let bar: DualBar
        let upColor: Color
        let downColor: Color
        let isHovering: Bool

        var body: some View {
            ZStack {
                GeometryReader { geo in
                    let mid = geo.size.height / 2
                    let gap = midGap

                    if bar.upValue != nil {
                        Rectangle()
                            .fill(upColor)
                            .frame(width: bar.width, height: bar.upHeight)
                            .position(x: bar.width / 2, y: mid - gap / 2 - bar.upHeight / 2)
                    }

                    if bar.downValue != nil {
                        Rectangle()
                            .fill(downColor)
                            .frame(width: bar.width, height: bar.downHeight)
                            .position(x: bar.width / 2, y: mid + gap / 2 + bar.downHeight / 2)
                    }
                }
            }
            .frame(width: bar.width)
            .overlay(tooltip, alignment: .center)
        }

        private var tooltip: some View {
            Group {
                if isHovering, bar.upValue != nil || bar.downValue != nil {
                    VStack(spacing: 4) {
                        Text(Self.timeFormatter.string(from: bar.timestamp))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        HStack(spacing: 6) {
                            Circle().fill(upColor).frame(width: 6, height: 6)
                            Text("↑ \(formatRate(bar.upValue ?? 0))")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        HStack(spacing: 6) {
                            Circle().fill(downColor).frame(width: 6, height: 6)
                            Text("↓ \(formatRate(bar.downValue ?? 0))")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .fixedSize()
                    .offset(y: -18)
                    .allowsHitTesting(false)
                    .zIndex(2)
                }
            }
        }

        private static let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter
        }()

        private func formatRate(_ value: Double) -> String {
            if value >= 1024 {
                return String(format: "%.1f MB/s", value / 1024)
            }
            return String(format: "%.0f KB/s", value)
        }
    }
}

private let midGap: CGFloat = 3
