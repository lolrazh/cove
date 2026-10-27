import AppKit
import Testing
@testable import Cove

@MainActor
struct PrivateFaviconStoreTests {
    @Test func `a private store keeps its favicons out of the shared one`() throws {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            NSColor.systemRed.setFill()
            rect.fill()
            return true
        }
        let data = try #require(image.tiffRepresentation)
        let shared = FaviconStore()
        let privateStore = FaviconStore(readingThrough: shared)
        let domain = "private-favicon-test.invalid"

        privateStore.store(domain: domain, imageData: data)

        #expect(privateStore.get(domain: domain) != nil)
        #expect(shared.get(domain: domain) == nil)
    }
}
