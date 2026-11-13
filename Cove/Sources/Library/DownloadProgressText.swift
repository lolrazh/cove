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
        .accessibilityLabel("\(size.number(completed)) \(size.suffix)")
        .transaction { $0.animation = nil }
    }
}

struct DownloadProgressSize {
    let total: Int64
    private let divisor: Double
    let unit: String

    init(total: Int64) {
        self.total = total
        let units: [(Double, String)] = [(1e12, "TB"), (1e9, "GB"), (1e6, "MB"), (1e3, "kB")]
        let selected = units.first { Double(total) >= $0.0 } ?? (total < 0 ? (1e3, "kB") : (1, "bytes"))
        divisor = selected.0
        unit = selected.1
    }

    func number(_ bytes: Int64) -> String {
        let value = Double(max(0, bytes)) / divisor
        return value.formatted(.number.grouping(.never).precision(.fractionLength(divisor == 1 ? 0 : 2)))
    }

    var columnTemplate: String {
        // Unknown sizes keep one kB column rather than changing units mid-flight.
        total > 0 ? number(total).map { $0.isNumber ? "0" : String($0) }.joined() : "0000000.00"
    }

    var suffix: String { total > 0 ? "of \(number(total)) \(unit)" : "\(unit) downloaded" }
}
