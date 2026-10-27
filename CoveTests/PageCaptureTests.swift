import Foundation
import Testing
@testable import Cove

struct PageCaptureTests {
    /// A page scrolled 300px down, 800 CSS pixels wide in a 1000pt view: zoomed to 125%.
    private let geometry = PageGeometry(scroll: CGPoint(x: 0, y: 300), viewportWidth: 800, viewWidth: 1000)

    @Test func `a region of the view is placed on the document`() {
        #expect(geometry.scale == 1.25)
        let rect = geometry.pageRect(forViewRect: CGRect(x: 100, y: 50, width: 250, height: 125))
        #expect(rect == CGRect(x: 80, y: 340, width: 200, height: 100))
    }

    @Test func `an element's client rect becomes points in the view`() {
        let rect = geometry.viewRect(forClientRect: CGRect(x: 80, y: 40, width: 200, height: 100))
        #expect(rect == CGRect(x: 100, y: 50, width: 250, height: 125))
        #expect(geometry.pageRect(forViewRect: rect) == CGRect(x: 80, y: 340, width: 200, height: 100))
    }

    @Test func `a capture is named for its page`() {
        let url = URL(string: "https://www.example.com/docs")!
        let titled = CaptureSource(url: url, title: "Docs", rect: .zero, viewportWidth: 800)
        let untitled = CaptureSource(url: url, title: "", rect: .zero, viewportWidth: 800)
        #expect(titled.name == "Capture of Docs")
        #expect(untitled.name == "Capture of example.com")
    }
}
