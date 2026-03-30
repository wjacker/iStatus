import SwiftUI

struct MemoryStackChartView: View {
    let appSamples: [MetricSample]
    let wiredSamples: [MetricSample]
    let compressedSamples: [MetricSample]
    let range: TimeInterval
    let bucketInterval: TimeInterval

    @State private var hoverIndex: Int?

    var body: some View {
        GeometryReader { proxy in
            let bars = bucketedBars(in: proxy.size)

            ZStack(alignment: .bottomLeading) {
                chartGrid(in: proxy.size)

                if let hoverIndex, hoverIndex < bars.count {
                    chartSelectionColumn(
                        index: hoverIndex,
                        barCount: bars.count,
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
                    .zIndex(1)
                }

                HStack(alignment: .bottom, spacing: barSpacing) {
                    Spacer(minLength: 0)
                    ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                        VStack(spacing: 0) {
                            if bar.appHeight > 0 {
                                RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [appColor.opacity(0.96), appColor.opacity(0.58)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: bar.appHeight)
                            }
                            if bar.wiredHeight > 0 {
                                RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [wiredColor.opacity(0.96), wiredColor.opacity(0.56)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: bar.wiredHeight)
                            }
                            if bar.compressedHeight > 0 {
                                RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [compressedColor.opacity(0.96), compressedColor.opacity(0.56)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: bar.compressedHeight)
                            }
                        }
                        .frame(width: barWidth)
                        .shadow(color: hoverIndex == index ? Color.white.opacity(0.08) : .clear, radius: 6)
                        .onHover { hovering in
                            hoverIndex = hovering ? index : nil
                        }
                    }
                }

                if let hoverIndex, hoverIndex < bars.count, bars[hoverIndex].hasData {
                    MemoryTooltip(bar: bars[hoverIndex])
                        .position(x: tooltipX(for: hoverIndex, barCount: bars.count, width: proxy.size.width), y: 12)
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
            for row in 1...rows {
                let y = size.height * CGFloat(row) / CGFloat(rows)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(Color.white.opacity(0.09), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
    }

    private func chartSelectionColumn(index: Int, barCount: Int, width: CGFloat, height: CGFloat) -> some View {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(max(barCount - 1, 0)) * barSpacing
        let leftOffset = max(width - totalWidth, 0)
        let x = leftOffset + CGFloat(index) * (barWidth + barSpacing)

        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white.opacity(0.055))
            .frame(width: max(barWidth + 2, 5), height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .offset(x: x - 1)
    }

    private func bucketedBars(in size: CGSize) -> [StackBar] {
        let end = alignedNow()
        let start = end.addingTimeInterval(-range)
        let duration = max(range, 1)

        let bucketCount = max(Int(duration / bucketInterval), 1)
        let bucketDuration = bucketInterval

        var appBuckets: [Bucket] = Array(repeating: Bucket(), count: bucketCount)
        var wiredBuckets: [Bucket] = Array(repeating: Bucket(), count: bucketCount)
        var compressedBuckets: [Bucket] = Array(repeating: Bucket(), count: bucketCount)

        for sample in appSamples where sample.timestamp >= start && sample.timestamp <= end {
            let index = min(max(Int(sample.timestamp.timeIntervalSince(start) / bucketDuration), 0), bucketCount - 1)
            appBuckets[index].add(sample)
        }

        for sample in wiredSamples where sample.timestamp >= start && sample.timestamp <= end {
            let index = min(max(Int(sample.timestamp.timeIntervalSince(start) / bucketDuration), 0), bucketCount - 1)
            wiredBuckets[index].add(sample)
        }

        for sample in compressedSamples where sample.timestamp >= start && sample.timestamp <= end {
            let index = min(max(Int(sample.timestamp.timeIntervalSince(start) / bucketDuration), 0), bucketCount - 1)
            compressedBuckets[index].add(sample)
        }

        let totals = (0..<bucketCount).map { idx -> Double in
            (appBuckets[idx].average ?? 0) + (wiredBuckets[idx].average ?? 0) + (compressedBuckets[idx].average ?? 0)
        }
        let maxTotal = max(totals.max() ?? 1, 1)

        let maxBars = max(Int(size.width / (barWidth + barSpacing)), 1)
        let groupSize = max(Int(ceil(Double(bucketCount) / Double(maxBars))), 1)
        let grouped = stride(from: 0, to: bucketCount, by: groupSize).map { startIndex -> (Bucket, Bucket, Bucket, Date) in
            var appMerged = Bucket()
            var wiredMerged = Bucket()
            var compressedMerged = Bucket()
            let endIndex = min(startIndex + groupSize, bucketCount)
            for idx in startIndex..<endIndex {
                appMerged.sum += appBuckets[idx].sum
                appMerged.count += appBuckets[idx].count
                wiredMerged.sum += wiredBuckets[idx].sum
                wiredMerged.count += wiredBuckets[idx].count
                compressedMerged.sum += compressedBuckets[idx].sum
                compressedMerged.count += compressedBuckets[idx].count
            }
            let timestamp = start.addingTimeInterval(bucketDuration * Double(endIndex))
            return (appMerged, wiredMerged, compressedMerged, timestamp)
        }

        return grouped.map { appBucket, wiredBucket, compressedBucket, timestamp in
            let appValue = appBucket.average
            let wiredValue = wiredBucket.average
            let compressedValue = compressedBucket.average

            let appHeight = appValue == nil ? 0 : CGFloat(appValue! / maxTotal) * size.height
            let wiredHeight = wiredValue == nil ? 0 : CGFloat(wiredValue! / maxTotal) * size.height
            let compressedHeight = compressedValue == nil ? 0 : CGFloat(compressedValue! / maxTotal) * size.height

            return StackBar(
                timestamp: timestamp,
                appValue: appValue,
                wiredValue: wiredValue,
                compressedValue: compressedValue,
                appHeight: appHeight,
                wiredHeight: wiredHeight,
                compressedHeight: compressedHeight
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

    private struct StackBar {
        let timestamp: Date
        let appValue: Double?
        let wiredValue: Double?
        let compressedValue: Double?
        let appHeight: CGFloat
        let wiredHeight: CGFloat
        let compressedHeight: CGFloat

        var hasData: Bool {
            (appValue ?? 0) > 0 || (wiredValue ?? 0) > 0 || (compressedValue ?? 0) > 0
        }
    }

    private struct MemoryTooltip: View {
        let bar: StackBar

        var body: some View {
            VStack(spacing: 4) {
                Text(Self.timeFormatter.string(from: bar.timestamp))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Circle().fill(appColor).frame(width: 6, height: 6)
                    Text("App \(formatBytes(bar.appValue ?? 0))")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                HStack(spacing: 6) {
                    Circle().fill(wiredColor).frame(width: 6, height: 6)
                    Text("Wired \(formatBytes(bar.wiredValue ?? 0))")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                HStack(spacing: 6) {
                    Circle().fill(compressedColor).frame(width: 6, height: 6)
                    Text("Compressed \(formatBytes(bar.compressedValue ?? 0))")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }

        private func formatBytes(_ value: Double) -> String {
            let gb = value / 1_073_741_824
            if gb >= 1 {
                return String(format: "%.1f GB", gb)
            }
            let mb = value / 1_048_576
            return String(format: "%.0f MB", mb)
        }

        private static let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter
        }()
    }
}

private let barWidth: CGFloat = 3
private let barSpacing: CGFloat = 1
private let appColor = Color.blue
private let wiredColor = Color.orange
private let compressedColor = Color.yellow
