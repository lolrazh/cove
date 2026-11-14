import SwiftUI

/// Keep both the unit and the number column fixed for the whole transfer.
/// Use a fixed decimal place and replace glyphs without fading or rolling them.
struct DownloadProgressText: View {
    let completed: Int64
    let total: Int64
    var remainingSeconds: Int? = nil

    var body: some View {
        let size = DownloadProgressSize(total: total)
        HStack(spacing: 0) {
            Text(size.columnTemplate)
                .hidden()
                .overlay(alignment: .trailing) {
                    Text(size.downloadedNumber(completed)).monospacedDigit()
                }
                .fixedSize()
            Text(size.suffix)
                .lineLimit(1)
            if let remainingSeconds {
                Text(" · " + DownloadProgressSize.time(remainingSeconds))
                    .lineLimit(1)
            }
        }
        .monospacedDigit()
        .contentTransition(.identity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(size.description(completed: completed, remainingSeconds: remainingSeconds))
        .transaction { $0.animation = nil; $0.disablesAnimations = true }
    }
}

struct DownloadProgressSize {
    let total: Int64
    private let divisor: Double
    let unit: String
    private let locale: Locale

    init(total: Int64, locale: Locale = .current) {
        self.total = total
        self.locale = locale
        let units: [(Double, String)] = [(1e12, "TB"), (1e9, "GB"), (1e6, "MB"), (1e3, "kB")]
        let selected = units.first { Double(total) >= $0.0 } ?? (total < 0 ? (1e3, "kB") : (1, "bytes"))
        divisor = selected.0
        unit = selected.1
    }

    func number(_ bytes: Int64) -> String {
        let value = Double(max(0, bytes)) / divisor
        return value.formatted(.number.locale(locale).grouping(.never)
            .precision(.fractionLength(0...(divisor == 1 ? 0 : 1))))
    }

    func downloadedNumber(_ bytes: Int64) -> String {
        let value = Double(max(0, total > 0 ? min(bytes, total) : bytes)) / divisor
        return value.formatted(.number.locale(locale).grouping(.never)
            .precision(.fractionLength(divisor == 1 ? 0 : 1)))
    }

    var columnTemplate: String {
        // Unknown sizes keep one kB column rather than changing units mid-flight.
        let widthSample = total > 0 ? Double(total) / divisor : 9_999_999
        return widthSample.formatted(.number.locale(locale).grouping(.never)
            .precision(.fractionLength(divisor == 1 ? 0 : 1)))
            .map { $0.isNumber ? "0" : String($0) }.joined()
    }

    func description(completed: Int64, remainingSeconds: Int? = nil) -> String {
        downloadedNumber(completed) + suffix + (remainingSeconds.map { " · " + Self.time($0) } ?? "")
    }

    static func time(_ seconds: Int) -> String {
        let seconds = max(0, seconds)
        if seconds >= 86_400 { return "\(seconds / 86_400)d \((seconds % 86_400) / 3_600)h" }
        if seconds >= 3_600 { return "\(seconds / 3_600)h \((seconds % 3_600) / 60)m" }
        if seconds >= 60 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds)s"
    }

    var formattedTotal: String { "\(number(total)) \(unit)" }

    var suffix: String { total > 0 ? "/\(number(total)) \(unit)" : " \(unit)" }
}
