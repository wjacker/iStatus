import SwiftUI

private let barWidth: CGFloat = 3
private let barSpacing: CGFloat = 1

struct MiniChartView: View {
    let samples: [MetricSample]
    let accent: Color
    let range: TimeInterval
    let bucketInterval: TimeInterval
    var valueFormatter: ((Double?) -> String)? = nil

    @State private var hoverIndex: Int?
    @State private var hoverLocationX: CGFloat?
    var body: some View {
        GeometryReader { proxy in
            let bars = bucketedBars(in: proxy.size)
            let displayBars = bars

            ZStack(alignment: .bottomLeading) {
                chartGrid(in: proxy.size)

                if let hoverIndex, hoverIndex < displayBars.count, let hoverLocationX {
                    chartSelectionColumn(
                        x: hoverLocationX,
                        height: proxy.size.height
                    )
                    .zIndex(1)
                }

                HStack(alignment: .bottom, spacing: barSpacing) {
                    Spacer(minLength: 0)
                    ForEach(Array(displayBars.enumerated()), id: \.offset) { index, bar in
                        BarCell(bar: bar, accent: accent, isHovering: hoverIndex == index)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)

                if let hoverIndex, hoverIndex < displayBars.count {
                    SingleTooltip(bar: displayBars[hoverIndex], valueFormatter: valueFormatter)
                        .position(x: tooltipX(for: hoverIndex, barCount: displayBars.count, width: proxy.size.width), y: 12)
                        .allowsHitTesting(false)
                        .zIndex(2)
                }

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover(coordinateSpace: .local) { phase in
                        switch phase {
                        case .active(let location):
                            updateHoverState(
                                locationX: location.x,
                                barCount: displayBars.count,
                                width: proxy.size.width
                            )
                        case .ended:
                            hoverIndex = nil
                            hoverLocationX = nil
                        }
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

    private func chartSelectionColumn(x: CGFloat, height: CGFloat) -> some View {
        return Rectangle()
            .fill(Color.white.opacity(0.95))
            .frame(width: 1, height: height)
            .offset(x: x - 0.5)
    }

    private func updateHoverState(locationX: CGFloat, barCount: Int, width: CGFloat) {
        guard barCount > 0 else {
            hoverIndex = nil
            return
        }

        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(max(barCount - 1, 0)) * barSpacing
        let leftOffset = max(width - totalWidth, 0)
        let clampedX = min(max(locationX, leftOffset), leftOffset + totalWidth)
        let relativeX = max(clampedX - leftOffset, 0)
        let index = min(max(Int(relativeX / (barWidth + barSpacing)), 0), barCount - 1)

        hoverIndex = index
        hoverLocationX = clampedX
    }

    private func barCenterX(for index: Int, barCount: Int, width: CGFloat) -> CGFloat {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(max(barCount - 1, 0)) * barSpacing
        let leftOffset = max(width - totalWidth, 0)
        return leftOffset + CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
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
        let isHovering: Bool

        var body: some View {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    bar.value == nil
                    ? AnyShapeStyle(Color.clear)
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                accent.opacity(isHovering ? 1 : 0.98),
                                accent.opacity(isHovering ? 0.72 : 0.46)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .frame(width: bar.width, height: bar.height)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(isHovering ? 0.24 : 0.1), lineWidth: isHovering ? 0.8 : 0.4)
                )
                .shadow(color: accent.opacity(isHovering ? 0.34 : 0.18), radius: isHovering ? 8 : 4, y: 0)
        }
    }

    private struct SingleTooltip: View {
        let bar: Bar
        let valueFormatter: ((Double?) -> String)?

        var body: some View {
            VStack(spacing: 2) {
                Text(Self.timeFormatter.string(from: bar.timestamp))
                Text(formattedValue)
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
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

        private var formattedValue: String {
            if let valueFormatter {
                return valueFormatter(bar.value)
            }
            return String(format: "%.1f", bar.value ?? 0)
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
    @State private var hoverLocationX: CGFloat?
    var body: some View {
        GeometryReader { proxy in
            let bars = bucketedBars(in: proxy.size)
            let displayBars = bars

            ZStack {
                chartGrid(in: proxy.size)

                if let hoverIndex, hoverIndex < displayBars.count, let hoverLocationX {
                    chartSelectionColumn(
                        x: hoverLocationX,
                        height: proxy.size.height
                    )
                }

                HStack(alignment: .center, spacing: barSpacing) {
                    Spacer(minLength: 0)
                    ForEach(Array(displayBars.enumerated()), id: \.offset) { index, bar in
                        DualBarCell(bar: bar, upColor: upColor, downColor: downColor, isHovering: hoverIndex == index)
                            .frame(width: bar.width)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)

                if let hoverIndex, hoverIndex < displayBars.count {
                    DualTooltip(
                        timestamp: displayBars[hoverIndex].timestamp,
                        upValue: displayBars[hoverIndex].upValue,
                        downValue: displayBars[hoverIndex].downValue,
                        upColor: upColor,
                        downColor: downColor
                    )
                        .position(
                            x: tooltipX(for: hoverIndex, barCount: displayBars.count, width: proxy.size.width),
                            y: 16
                        )
                        .allowsHitTesting(false)
                        .zIndex(3)
                }

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover(coordinateSpace: .local) { phase in
                        switch phase {
                        case .active(let location):
                            updateHoverState(
                                locationX: location.x,
                                barCount: displayBars.count,
                                width: proxy.size.width
                            )
                        case .ended:
                            hoverIndex = nil
                            hoverLocationX = nil
                        }
                    }
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
        .stroke(Color.white.opacity(0.09), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
    }

    private func chartSelectionColumn(x: CGFloat, height: CGFloat) -> some View {
        return Rectangle()
            .fill(Color.white.opacity(0.95))
            .frame(width: 1, height: height)
            .offset(x: x - 0.5)
    }

    private func tooltipX(for index: Int, barCount: Int, width: CGFloat) -> CGFloat {
        barCenterX(for: index, barCount: barCount, width: width)
    }

    private func updateHoverState(locationX: CGFloat, barCount: Int, width: CGFloat) {
        guard barCount > 0 else {
            hoverIndex = nil
            return
        }

        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(max(barCount - 1, 0)) * barSpacing
        let leftOffset = max(width - totalWidth, 0)
        let clampedX = min(max(locationX, leftOffset), leftOffset + totalWidth)
        let relativeX = max(clampedX - leftOffset, 0)
        let index = min(max(Int(relativeX / (barWidth + barSpacing)), 0), barCount - 1)

        hoverIndex = index
        hoverLocationX = clampedX
    }

    private func barCenterX(for index: Int, barCount: Int, width: CGFloat) -> CGFloat {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(max(barCount - 1, 0)) * barSpacing
        let leftOffset = max(width - totalWidth, 0)
        return leftOffset + CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
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

        let maxUp = max(upBuckets.compactMap { $0.average }.max() ?? 1, 1)
        let maxDown = max(downBuckets.compactMap { $0.average }.max() ?? 1, 1)
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
            let upHeight = upValue == nil ? 0 : CGFloat(upValue! / maxUp) * halfHeight
            let downHeight = downValue == nil ? 0 : CGFloat(downValue! / maxDown) * halfHeight
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
                        RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [upColor.opacity(0.98), upColor.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: bar.width, height: bar.upHeight)
                            .position(x: bar.width / 2, y: mid - gap / 2 - bar.upHeight / 2)
                    }

                    if bar.downValue != nil {
                        RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [downColor.opacity(0.98), downColor.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: bar.width, height: bar.downHeight)
                            .position(x: bar.width / 2, y: mid + gap / 2 + bar.downHeight / 2)
                    }
                }
            }
            .frame(width: bar.width)
            .shadow(color: isHovering ? Color.white.opacity(0.08) : .clear, radius: 6)
            .zIndex(isHovering ? 20 : 0)
        }
    }
}

private struct DualTooltip: View {
    let timestamp: Date
    let upValue: Double?
    let downValue: Double?
    let upColor: Color
    let downColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(Self.timeFormatter.string(from: timestamp))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 6) {
                Circle().fill(upColor).frame(width: 6, height: 6)
                Text("↑ \(formatRate(upValue ?? 0))")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            HStack(spacing: 6) {
                Circle().fill(downColor).frame(width: 6, height: 6)
                Text("↓ \(formatRate(downValue ?? 0))")
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
        .fixedSize()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private func formatRate(_ value: Double) -> String {
        formatNetworkRate(kilobytesPerSecond: value)
    }
}

private let midGap: CGFloat = 3

private func formatNetworkRate(kilobytesPerSecond value: Double?, fallback: String = "--") -> String {
    guard let value else { return fallback }
    return formatNetworkRate(bytesPerSecond: value * 1024, fallback: fallback)
}

private func formatNetworkRate(bytesPerSecond value: Double?, fallback: String = "--") -> String {
    guard let value else { return fallback }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
    formatter.countStyle = .binary
    formatter.includesUnit = true
    formatter.isAdaptive = true
    formatter.zeroPadsFractionDigits = false
    return formatter.string(fromByteCount: Int64(value)) + "/s"
}
