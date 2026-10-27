import AppKit
import Testing
@testable import Cove

struct EaselBoardTests {
    private func text(_ string: String, at frame: CGRect) -> EaselItem {
        EaselItem(frame: frame, content: .text(string, size: 18, ink: .label))
    }

    @Test func `strokes become a drawing framed around them, stretching with it`() throws {
        let item = try #require(EaselItem.drawing([[CGPoint(x: 10, y: 20), CGPoint(x: 110, y: 70)]], ink: .blue, width: 4))
        #expect(item.frame == CGRect(x: 6, y: 16, width: 108, height: 58))
        guard case .drawing(let strokes, let ink, _) = item.content else { Issue.record("not a drawing"); return }
        #expect(ink == .blue)
        #expect(strokes[0].allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        #expect(EaselItem.drawing([], ink: .label, width: 3) == nil)
    }

    @Test func `items move, come to the front and go`() {
        let a = text("A", at: CGRect(x: 0, y: 0, width: 10, height: 10))
        let b = text("B", at: CGRect(x: 50, y: 50, width: 10, height: 10))
        var board = EaselBoard(items: [a, b])
        board.move([a.id], by: CGSize(width: 5, height: 7))
        #expect(board.item(a.id)?.frame.origin == CGPoint(x: 5, y: 7))
        board.bringToFront(a.id)
        #expect(board.items.map(\.id) == [b.id, a.id])
        board.remove([b.id])
        #expect(board.items.map(\.id) == [a.id])
    }

    @Test func `new things go below everything, and the words are found`() {
        let empty = EaselBoard()
        #expect(empty.placement(for: CGSize(width: 100, height: 50)).origin == CGPoint(x: 40, y: 40))
        let source = CaptureSource(url: URL(string: "https://example.com")!, title: "Example", rect: .zero, viewportWidth: 800)
        let board = EaselBoard(items: [
            text("Hello", at: CGRect(x: 100, y: 100, width: 200, height: 30)),
            EaselItem(frame: CGRect(x: 60, y: 200, width: 300, height: 100), content: .clip(source, snapshot: "s.png")),
        ])
        #expect(board.placement(for: CGSize(width: 100, height: 50)).origin == CGPoint(x: 60, y: 324))
        #expect(board.text == "Hello\nExample")
        #expect(board.files == ["s.png"])
    }
}

@MainActor
struct EaselStoreTests {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CoveTests-\(UUID().uuidString)/Documents")

    private var image: NSImage {
        NSImage(size: NSSize(width: 40, height: 20), flipped: false) { rect in
            NSColor.systemRed.setFill()
            rect.fill()
            return true
        }
    }

    @Test func `an easel and its images come back from its package`() throws {
        let before = DocumentStore(directory: directory)
        let document = before.create(.easel)
        let easel = try #require(before.easel(document.id))
        easel.add(image, at: CGPoint(x: 10, y: 10))
        easel.change("Add Text") { $0.items.append(EaselItem(frame: CGRect(x: 0, y: 100, width: 200, height: 30), content: .text("Plan", size: 18, ink: .label))) }
        before.save()

        let after = DocumentStore(directory: directory)
        #expect(after.documents[document.id]?.text == "Plan")
        let reopened = try #require(after.easel(document.id))
        #expect(reopened.board == easel.board)
        guard case .image(let name) = reopened.board.items[0].content else { Issue.record("not an image"); return }
        #expect(reopened.image(named: name)?.size == NSSize(width: 40, height: 20))
    }

    @Test func `changes undo and redo, and unused images go on the next open`() throws {
        let store = DocumentStore(directory: directory)
        let document = store.create(.easel)
        let easel = try #require(store.easel(document.id))
        // Each change its own step, as each click is in the app.
        easel.undoManager.groupsByEvent = false
        let step = { (change: () -> Void) in
            easel.undoManager.beginUndoGrouping()
            change()
            easel.undoManager.endUndoGrouping()
        }
        step { easel.add(image, at: .zero) }
        let added = easel.board
        step { easel.change("Delete") { $0.items.removeAll() } }
        easel.undoManager.undo()
        #expect(easel.board == added)
        easel.undoManager.redo()
        #expect(easel.board.items.isEmpty)
        store.save()

        let package = directory.appendingPathComponent("\(document.id.uuidString).easel")
        #expect(try FileManager.default.contentsOfDirectory(atPath: package.path).contains { $0.hasSuffix(".png") })
        _ = DocumentStore(directory: directory).easel(document.id)
        #expect(try !FileManager.default.contentsOfDirectory(atPath: package.path).contains { $0.hasSuffix(".png") })
    }
}
