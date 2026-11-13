import Foundation
import Testing
@testable import Cove

struct PinnedTileLayoutTests {
    @Test func `pins use balanced full-width rows`() {
        let expected = [[], [1], [2], [3], [2, 2], [3, 2], [3, 3], [3, 2, 2], [3, 3, 2]]
        for (count, rows) in expected.enumerated() {
            #expect(PinnedTileLayout.rowCounts(for: count) == rows)
        }
    }

    @Test(arguments: [204.0, 384.0])
    func `tiles fill each row without overlaps at supported sidebar widths`(width: Double) {
        for count in 1...30 {
            let frames = PinnedTileLayout.frames(count: count, width: width)
            #expect(frames.count == count)
            for row in Dictionary(grouping: frames, by: \.minY).values {
                #expect(row.first?.minX == 0)
                #expect(abs((row.last?.maxX ?? 0) - width) < 0.001)
                for (left, right) in zip(row, row.dropFirst()) {
                    #expect(abs(right.minX - left.maxX - 6) < 0.001)
                }
            }
            for (index, frame) in frames.enumerated() {
                #expect(frame.height == 40)
                #expect(frames.dropFirst(index + 1).allSatisfy { !frame.intersects($0) })
            }
            let mirrored = PinnedTileLayout.frames(count: count, width: width, rightToLeft: true)
            for (original, mirror) in zip(frames, mirrored) {
                #expect(abs(original.minX + mirror.maxX - width) < 0.001)
                #expect(original.minY == mirror.minY)
            }
        }
    }
}
