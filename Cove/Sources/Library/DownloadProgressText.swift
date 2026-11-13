import SwiftUI

/// Keep both the unit and the number column fixed for the whole transfer.
/// Tabular digits alone do not stop “99 kB” becoming “100 kB” from moving “of”.
struct DownloadProgressText: View {
    let completed: Int64
    let total: Int64

    var body: some View {
        let size = DownloadProgressSize(total: total)
        HStack(spacing: 3) {
            Text(size.columnTemplate)
                .hidden()
                .overlay(alignment: .trailing) {
                    Text(size.number(completed)).monospacedDigit()
                }
                .fixedSize()
            Text(size.suffix)
                .lineLimit(1)
        }
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(size.description(completed: completed))
        .transaction { $0.animation = nil }
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

    var columnTemplate: String {
        // Unknown sizes keep one kB column rather than changing units mid-flight.
        let widthSample = total > 0 ? Double(total) / divisor : 9_999_999
        return widthSample.formatted(.number.locale(locale).grouping(.never)
            .precision(.fractionLength(divisor == 1 ? 0 : 1)))
            .map { $0.isNumber ? "0" : String($0) }.joined()
    }

    func description(completed: Int64) -> String { "\(number(completed)) \(suffix)" }

    var formattedTotal: String { "\(number(total)) \(unit)" }

    var suffix: String { total > 0 ? "of \(number(total)) \(unit)" : "\(unit) downloaded" }
}
