import Foundation
import AppKit
import SwiftUI
import WebKit
import Testing
@testable import Cove

@MainActor
struct PageChromeContrastTests {
    @Test func `page controls remain readable on light dark and saturated backgrounds`() {
        #expect(PageChromeContrast.scheme(for: .white, fallback: .dark) == .light)
        #expect(PageChromeContrast.scheme(for: .black, fallback: .light) == .dark)
        #expect(PageChromeContrast.scheme(for: NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1), fallback: .dark) == .light)
        #expect(PageChromeContrast.scheme(for: NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1), fallback: .light) == .dark)
    }

    @Test func `a transparent background keeps the existing appearance`() {
        #expect(PageChromeContrast.scheme(for: .clear, fallback: .dark) == .dark)
        #expect(PageChromeContrast.scheme(for: .clear, fallback: .light) == .light)
    }
}

struct SpacesTests {
    @Test func `a first launch has one space in the default profile, in the old frame color`() {
        let theme = ChromeTheme(rawValue: "#5EA4E8")
        let spaces = Spaces(theme: theme)
        #expect(spaces.spaces.map(\.id) == [Space.defaultID])
        #expect(spaces.spaces[0].theme == theme)
        #expect(spaces.spaces[0].profileID == Profile.defaultID)
        #expect(spaces.profiles.map(\.id) == [Profile.defaultID])
    }

    @Test func `new spaces are numbered and wear a color no other space does`() {
        var spaces = Spaces(theme: ChromeTheme.presets[1])
        let second = spaces.addSpace()
        let third = spaces.addSpace()
        #expect(second.name == "Space 2")
        #expect(third.name == "Space 3")
        #expect(Set(spaces.spaces.map(\.theme)).count == 3)
        #expect(!spaces.spaces.contains { $0.theme == .system })
    }

    @Test func `a new space goes into the given profile, or the default for an unknown one`() {
        var spaces = Spaces()
        let work = spaces.addProfile()
        #expect(spaces.addSpace(in: work.id).profileID == work.id)
        #expect(spaces.addSpace(in: UUID()).profileID == Profile.defaultID)
    }

    @Test func `edits keep a name and a known profile`() {
        var spaces = Spaces()
        spaces.update(Space.defaultID) {
            $0.name = "  Work "
            $0.icon = .emoji("💼")
        }
        #expect(spaces.space(Space.defaultID)?.name == "Work")
        #expect(spaces.space(Space.defaultID)?.icon == .emoji("💼"))

        spaces.update(Space.defaultID) {
            $0.name = " "
            $0.profileID = UUID()
        }
        #expect(spaces.space(Space.defaultID)?.name == "Work")
        #expect(spaces.space(Space.defaultID)?.profileID == Profile.defaultID)
    }

    @Test func `the last space can't be removed`() {
        var spaces = Spaces()
        spaces.removeSpace(Space.defaultID)
        #expect(spaces.spaces.count == 1)

        let second = spaces.addSpace()
        spaces.removeSpace(Space.defaultID)
        #expect(spaces.spaces.map(\.id) == [second.id])
    }

    @Test func `spaces move within the list, and neighbors don't wrap`() {
        var spaces = Spaces()
        let second = spaces.addSpace()
        let third = spaces.addSpace()

        spaces.moveSpace(third.id, by: -5)
        #expect(spaces.spaces.map(\.id) == [third.id, Space.defaultID, second.id])

        #expect(spaces.space(1, from: third.id)?.id == Space.defaultID)
        #expect(spaces.space(-1, from: third.id) == nil)
        #expect(spaces.space(1, from: second.id) == nil)
    }

    @Test func `a removed profile's spaces move to the default profile, which stays`() {
        var spaces = Spaces()
        let work = spaces.addProfile()
        let space = spaces.addSpace(in: work.id)

        spaces.removeProfile(Profile.defaultID)
        #expect(spaces.profiles.count == 2)

        spaces.removeProfile(work.id)
        #expect(spaces.profiles.map(\.id) == [Profile.defaultID])
        #expect(spaces.space(space.id)?.profileID == Profile.defaultID)
    }

    @Test func `profiles rename, but never to nothing`() {
        var spaces = Spaces()
        spaces.renameProfile(Profile.defaultID, to: "Personal")
        spaces.renameProfile(Profile.defaultID, to: "")
        #expect(spaces.profile(Profile.defaultID)?.name == "Personal")
    }
}

struct PinLayoutTests {
    private let pin = Pin(id: UUID(), url: "https://example.com/", title: "Example")

    @Test func `pinned tabs are per space, favorites per profile`() {
        var layout = PinLayout()
        let work = UUID()
        let personal = PinScope.default
        let workSpace = PinScope(space: work, profile: Profile.defaultID)
        let otherProfile = PinScope(space: work, profile: UUID())

        layout[personal].add(pin, to: .favorites)
        let pinned = Pin(id: UUID(), url: "https://apple.com/", title: "Apple")
        layout[personal].add(pinned, to: .pinned)

        #expect(layout[workSpace].favorites == [pin])
        #expect(layout[workSpace].pinned.isEmpty)
        #expect(layout[otherProfile].favorites.isEmpty)
        #expect(layout.pin(pinned.id) == pinned)
    }

    @Test func `emptied sections leave nothing behind`() {
        var layout = PinLayout()
        layout[.default].add(pin, to: .pinned)
        layout[.default].remove(pin.id)
        #expect(layout == PinLayout())
    }

    @Test func `a pin's title changes wherever it is`() {
        var layout = PinLayout()
        let scope = PinScope(space: UUID(), profile: UUID())
        layout[scope].add(pin, to: .pinned)
        layout.update(pin.id) { $0.title = "Renamed" }
        #expect(layout[scope].pinned.tabs.first?.title == "Renamed")
    }

    @Test func `pins follow deleted spaces and profiles`() {
        var spaces = Spaces()
        let work = spaces.addProfile()
        let space = spaces.addSpace(in: work.id)
        let scope = PinScope(space: space.id, profile: work.id)
        var layout = PinLayout()
        layout[scope].add(pin, to: .favorites)
        layout[scope].add(Pin(id: UUID(), url: "https://apple.com/", title: "Apple"), to: .pinned)
        layout[.default].add(Pin(id: UUID(), url: "https://swift.org/", title: "Swift"), to: .favorites)

        spaces.removeSpace(space.id)
        spaces.removeProfile(work.id)
        layout.prune(to: spaces)

        #expect(layout[scope].pinned.isEmpty)
        #expect(layout[.default].favorites.map(\.title) == ["Swift", "Example"])
    }
}

struct SavedWindowTests {
    private let tab = SavedTab(url: "https://example.com/", title: "Example", customTitle: nil, interactionState: nil, lastUsedAt: nil)

    @Test func `a window keeps every space's Today and the space shown`() throws {
        let other = UUID()
        let pin = UUID()
        var window = SavedWindow(spaces: [
            SavedSpace(spaceID: Space.defaultID, tabs: [tab, tab], activeTabIndex: 1, activePinID: nil),
            SavedSpace(spaceID: other, tabs: [], activeTabIndex: nil, activePinID: pin),
        ], activeSpaceID: other)
        window.placement = WindowPlacement(frame: CGRect(x: 1, y: 2, width: 900, height: 700), isFullScreen: false)

        let decoded = try PropertyListDecoder().decode(SavedWindow.self, from: PropertyListEncoder().encode(window))
        #expect(decoded.activeSpaceID == other)
        #expect(decoded.spaces.map(\.spaceID) == [Space.defaultID, other])
        #expect(decoded.spaces[0].activeTabIndex == 1)
        #expect(decoded.spaces[1].activePinID == pin)
        #expect(decoded.placement?.frame.width == 900)
    }

    @Test func `a window saved before Spaces is the first space's`() throws {
        struct UnscopedWindow: Encodable {
            let tabs: [SavedTab]
            let activeTabIndex: Int
        }
        let data = try PropertyListEncoder().encode(UnscopedWindow(tabs: [tab], activeTabIndex: 0))
        let decoded = try PropertyListDecoder().decode(SavedWindow.self, from: data)
        #expect(decoded.activeSpaceID == Space.defaultID)
        #expect(decoded.spaces.map(\.spaceID) == [Space.defaultID])
        #expect(decoded.spaces[0].tabs.map(\.url) == [tab.url])
        #expect(decoded.spaces[0].activeTabIndex == 0)
    }
}

@MainActor
struct SpaceStoreTests {
    private let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CoveTests-\(UUID().uuidString)/spaces.plist")

    private func makeStore() -> SpaceStore {
        SpaceStore(fileURL: fileURL) { _ in
            Issue.record("No context is needed")
            return .standard(faviconStore: FaviconStore(readingThrough: FaviconStore()), extensions: ExtensionLibrary(directory: nil))
        }
    }

    @Test func `spaces and profiles come back from the file`() {
        let before = makeStore()
        var added: Space?
        before.change {
            let profile = $0.addProfile()
            added = $0.addSpace(in: profile.id)
        }

        let after = makeStore()
        #expect(after.spaces == before.spaces)
        #expect(after.spaces.space(added!.id)?.name == "Space 2")
    }

    @Test func `an unchanged edit isn't published`() {
        let store = makeStore()
        var publishes = 0
        let subscription = store.$spaces.dropFirst().sink { _ in publishes += 1 }
        store.change { $0.removeSpace(Space.defaultID) }
        #expect(publishes == 0)
        subscription.cancel()
    }
}

@MainActor
struct SpaceSwipeTests {
    @Test func `drag follows fingers one to one while a neighbor is available`() {
        for distance in stride(from: CGFloat(-220), through: 220, by: 20) {
            #expect(SpaceSwipe.offset(distance, width: 240, hasPrevious: true, hasNext: true) == distance)
        }
    }

    @Test func `a short drag returns but a deliberate drag or flick changes space`() {
        #expect(SpaceSwipe.destination(translation: -40, velocity: 0, width: 240, hasPrevious: true, hasNext: true) == 0)
        #expect(SpaceSwipe.destination(translation: -90, velocity: 0, width: 240, hasPrevious: true, hasNext: true) == 1)
        #expect(SpaceSwipe.destination(translation: -40, velocity: -600, width: 240, hasPrevious: true, hasNext: true) == 1)
        #expect(SpaceSwipe.destination(translation: 40, velocity: 600, width: 240, hasPrevious: true, hasNext: true) == -1)
    }

    @Test func `reversing before release can cancel the move`() {
        #expect(SpaceSwipe.destination(translation: -100, velocity: 500, width: 240, hasPrevious: true, hasNext: true) == 0)
        #expect(SpaceSwipe.destination(translation: -8, velocity: -2000, width: 240, hasPrevious: true, hasNext: true) == 0)
    }

    @Test func `the first and last spaces resist without wrapping`() {
        #expect(SpaceSwipe.destination(translation: 200, velocity: 1000, width: 240, hasPrevious: false, hasNext: true) == 0)
        #expect(SpaceSwipe.destination(translation: -200, velocity: -1000, width: 240, hasPrevious: true, hasNext: false) == 0)
        let small = SpaceSwipe.offset(60, width: 240, hasPrevious: false, hasNext: true)
        let large = SpaceSwipe.offset(600, width: 240, hasPrevious: false, hasNext: true)
        #expect(small > 0 && small < 60)
        #expect(large > small && large < 48)
        #expect(SpaceSwipe.offset(-600, width: 240, hasPrevious: true, hasNext: false) == -large)
    }

    @Test func `the release distance scales with the sidebar width`() {
        #expect(SpaceSwipe.destination(translation: -90, velocity: 0, width: 200, hasPrevious: true, hasNext: true) == 1)
        #expect(SpaceSwipe.destination(translation: -90, velocity: 0, width: 400, hasPrevious: true, hasNext: true) == 0)
    }
}

@MainActor
struct SpaceTransitionStateTests {
    private let first = UUID()
    private let middle = UUID()
    private let last = UUID()

    @Test func `all visual selections share continuous weights in both directions`() {
        var state = SpaceTransitionState()
        state.begin(source: middle, previous: first, next: last, presentedPosition: 0)
        state.position = -0.4
        #expect(abs(state.weight(for: middle, selected: middle) - 0.6) < 0.0001)
        #expect(abs(state.weight(for: last, selected: middle) - 0.4) < 0.0001)
        #expect(state.weight(for: first, selected: middle) == 0)
        state.position = 0.7
        #expect(abs(state.weight(for: first, selected: middle) - 0.7) < 0.0001)
        #expect(state.weight(for: last, selected: middle) == 0)
        let total = [first, middle, last].reduce(0.0) { $0 + state.weight(for: $1, selected: middle) }
        #expect(abs(total - 1) < 0.0001)
    }

    @Test func `interrupting a settle resumes at the visible position and invalidates its completion`() {
        var state = SpaceTransitionState()
        state.begin(source: middle, previous: first, next: last, presentedPosition: 0)
        let stale = state.settle(to: 1)
        #expect(state.canComplete(stale))
        state.begin(source: middle, previous: first, next: last, presentedPosition: -0.65)
        #expect(state.phase == .tracking)
        #expect(state.position == -0.65)
        #expect(!state.canComplete(stale))
        let fresh = state.settle(to: 0)
        #expect(state.canComplete(fresh))
        #expect(!state.canComplete(stale))
        #expect(state.position == -0.65)
    }

    @Test func `resetting after a click cancels every pending handoff`() {
        var state = SpaceTransitionState()
        state.begin(source: middle, previous: first, next: last, presentedPosition: 0)
        let stale = state.settle(to: 1)
        state.reset()
        #expect(!state.canComplete(stale))
        #expect(state.phase == .idle)
        #expect(state.weight(for: first, selected: first) == 1)
        #expect(state.weight(for: last, selected: first) == 0)
    }

    @Test func `settle and commit keep the same final visual selection`() {
        var state = SpaceTransitionState()
        state.begin(source: middle, previous: first, next: last, presentedPosition: 0)
        _ = state.settle(to: 1)
        state.position = -1 // The display clock reaches the destination before commit.
        let before = [first, middle, last].map { state.weight(for: $0, selected: middle) }
        state.reset()
        let after = [first, middle, last].map { state.weight(for: $0, selected: last) }
        #expect(before == after)
    }

    @Test func `edge resistance cannot tint toward a missing neighbor`() {
        var state = SpaceTransitionState()
        state.begin(source: first, previous: nil, next: middle, presentedPosition: 0)
        state.position = 0.15
        #expect(state.weight(for: first, selected: first) == 1)
        #expect(state.weight(for: middle, selected: first) == 0)
    }
}

@MainActor
struct WebPageContainerTests {
    @Test func `an unlaid out host preserves the incoming page dimensions`() {
        let host = WebPageContainer()
        let page = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 700))
        host.show(page) { _ in }
        #expect(page.frame.size == CGSize(width: 900, height: 700))
        #expect(page.superview == nil)
        host.frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        host.installIfReady()
        #expect(page.superview === host)
        #expect(page.frame == host.bounds)
    }

    @Test func `a rapid pending replacement only installs the latest page`() {
        let host = WebPageContainer()
        let first = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 700))
        let latest = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 700))
        host.show(first) { _ in }
        host.show(latest) { _ in }
        host.frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        host.installIfReady()
        #expect(host.page === latest)
        #expect(host.subviews.count == 1)
        #expect(first.superview == nil)
        #expect(first.frame.size == CGSize(width: 900, height: 700))
    }

    @Test func `switching pages reuses the host and attaches at its full size`() {
        let host = WebPageContainer(frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        let first = WKWebView()
        let second = WKWebView()
        host.show(first) { _ in }
        host.show(second) { _ in }
        #expect(host.page === second)
        #expect(second.frame == host.bounds)
        #expect(first.superview == nil)
        #expect(host.subviews.count == 1)
        host.show(first) { _ in }
        #expect(host.page === first)
        #expect(first.frame == host.bounds)
        #expect(host.subviews.count == 1)
    }
}

@MainActor
struct SpaceMotionTests {
    @Test func `dragging follows the fingers without waiting for the motion clock`() {
        var motion = SpaceMotion()
        for position: CGFloat in [-0.1, -0.4, -0.2, 0.1] {
            motion.track(position)
            #expect(motion.position == position)
            let completed = motion.advance(1.0 / 60)
            #expect(!completed)
            #expect(motion.position == position)
        }
    }

    @Test func `release continues immediately from the visible position and measured velocity`() {
        var motion = SpaceMotion(position: -0.3)
        motion.settle(to: -1, initialVelocity: -3)
        #expect(motion.position == -0.3)
        #expect(motion.velocity == -3)
        let complete = motion.advance(1.0 / 60)
        #expect(!complete)
        #expect(motion.position < -0.35 && motion.position > -0.6)
    }

    @Test func `a fast flick cannot overshoot and pull back`() {
        var motion = SpaceMotion(position: -0.8)
        motion.settle(to: -1, initialVelocity: -100)
        var last = motion.position
        var complete = false
        for _ in 0..<40 {
            complete = motion.advance(1.0 / 120)
            #expect(motion.position >= -1 && motion.position <= last)
            last = motion.position
            if complete { break }
        }
        #expect(complete)
        #expect(motion.position == -1)
    }

    @Test func `release is stable across refresh rates`() {
        var sixty = SpaceMotion(position: -0.2), oneTwenty = SpaceMotion(position: -0.2)
        sixty.settle(to: -1, initialVelocity: -2)
        oneTwenty.settle(to: -1, initialVelocity: -2)
        for _ in 0..<6 { _ = sixty.advance(1.0 / 60) }
        for _ in 0..<12 { _ = oneTwenty.advance(1.0 / 120) }
        #expect(abs(sixty.position - oneTwenty.position) < 0.00001)
    }

    @Test func `interrupting a settle gives direct control back without a jump`() {
        var motion = SpaceMotion(position: -0.3)
        motion.settle(to: -1, initialVelocity: -2)
        _ = motion.advance(0.08)
        let visible = motion.position
        motion.track(visible)
        #expect(motion.position == visible)
        motion.track(visible + 0.1)
        _ = motion.advance(1.0 / 120)
        #expect(abs(motion.position - (visible + 0.1)) < 0.00001)
    }

    @Test func `a nearly complete swipe does not wait for a full length animation`() {
        func duration(from position: CGFloat) -> Double {
            var motion = SpaceMotion(position: position)
            motion.settle(to: -1)
            var elapsed = 0.0
            while elapsed < 0.4 {
                elapsed += 1.0 / 120
                if motion.advance(1.0 / 120) { return elapsed }
            }
            return elapsed
        }
        #expect(duration(from: -0.95) < duration(from: -0.2))
        #expect(duration(from: -0.95) < 0.2)
        #expect(duration(from: -0.2) < 0.3)
    }
}

@Suite(.serialized)
@MainActor
struct PagePresentationRegressionTests {
    private func hostWindow() -> (NSWindow, WebPageContainer) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = WebPageContainer(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        window.contentView = host
        return (window, host)
    }

    @Test func `rapid selections change ownership immediately without blocking input`() {
        let (window, host) = hostWindow()
        defer { host.reset(); window.close() }
        let pages = (0..<4).map { _ in WKWebView() }
        for i in 0..<200 {
            let selected = pages[i % pages.count]
            host.show(selected) { _ in }
            #expect(host.page === selected)
            #expect(host.subviews.count == 1)
            #expect(selected.superview === host)
            #expect(host.hitTest(NSPoint(x: 100, y: 100)) !== host)
        }
    }

    @Test func `resetting a previous host cannot detach a page moved into a split`() {
        let (window, oldHost) = hostWindow()
        let newHost = WebPageContainer(frame: oldHost.bounds)
        defer { oldHost.reset(); newHost.reset(); window.close() }
        let page = WKWebView()
        oldHost.show(page) { _ in }
        newHost.show(page) { _ in }
        oldHost.reset()
        #expect(page.superview === newHost)
        #expect(newHost.subviews.count == 1)
        #expect(oldHost.subviews.isEmpty)
    }

    @Test func `queued appearance callbacks only notify the selected page`() async throws {
        let (window, host) = hostWindow()
        defer { host.reset(); window.close() }
        let pages = (0..<3).map { _ in WKWebView() }
        var appeared: [Int] = []
        for i in pages.indices { host.show(pages[i]) { _ in appeared.append(i) } }
        try await Task.sleep(for: .milliseconds(20))
        #expect(appeared == [2])
        for _ in 0..<20 { host.show(pages[2]) { _ in appeared.append(2) } }
        try await Task.sleep(for: .milliseconds(20))
        #expect(appeared == [2])
        for i in [0, 1, 0] { host.show(pages[i]) { _ in appeared.append(i) } }
        try await Task.sleep(for: .milliseconds(20))
        #expect(appeared == [2, 0])
        host.show(pages[1]) { _ in appeared.append(1) }
        host.reset()
        try await Task.sleep(for: .milliseconds(20))
        #expect(appeared == [2, 0])
    }

    @Test func `moving a host between windows does not leave an unfinished presentation`() {
        let (first, host) = hostWindow()
        let (second, unusedHost) = hostWindow()
        defer { host.reset(); unusedHost.reset(); first.close(); second.close() }
        let page = WKWebView()
        host.show(page) { _ in }
        first.contentView = nil
        second.contentView = host
        #expect(host.page === page)
        #expect(page.window === second)
        #expect(host.subviews.count == 1)
    }

    @Test func `nested app surfaces supply the toolbar color without republishing on content edits`() async throws {
        let configuration = WKWebViewConfiguration()
        var colors: [NSColor] = []
        PageBackground.install(in: configuration.userContentController) { _, color in colors.append(color) }
        let page = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        let (window, host) = hostWindow()
        defer { host.reset(); window.close() }
        host.show(page) { _ in }
        page.loadHTMLString("""
            <html><head><style>body { margin: 0; background: white; }</style></head>
            <body><div id="app"></div></body></html>
            """, baseURL: URL(string: "https://nested-color.test/"))
        func expectColor(_ expected: [CGFloat]) async throws {
            for _ in 0..<300 {
                if let color = colors.last?.usingColorSpace(.sRGB),
                   zip([color.redComponent, color.greenComponent, color.blueComponent], expected)
                    .allSatisfy({ abs($0 - $1 / 255) < 0.005 }) { return }
                try await Task.sleep(for: .milliseconds(10))
            }
            Issue.record("Expected toolbar RGB \(expected), got \(String(describing: colors.last))")
        }
        try await expectColor([255, 255, 255])
        // React-style mounting after documentEnd, with a colored shell and header.
        _ = try await page.evaluateJavaScript("""
            document.querySelector('#app').innerHTML =
                `<div id="shell" style="min-height:100vh;background:#fef7cd">
                    <header style="height:62px;background:#9ae66e">
                        <button style="display:block;margin:auto;background:red;width:60px;height:30px">Help</button>
                    </header>
                    <main><p id="content">Content</p></main>
                </div>`;
            """)
        // The small red button must not become the page's color.
        try await expectColor([154, 230, 110])
        let count = colors.count
        _ = try await page.evaluateJavaScript("document.querySelector('#content').textContent = 'Updated text'")
        for _ in 0..<10 { page.removeFromSuperview(); host.addSubview(page) }
        try await Task.sleep(for: .milliseconds(150))
        #expect(colors.count == count)
        _ = try await page.evaluateJavaScript("document.querySelector('header').style.background = '#1f2937'")
        try await expectColor([31, 41, 55])
        _ = try await page.evaluateJavaScript("document.querySelector('header').remove()")
        try await expectColor([254, 247, 205])
        // Transparent surfaces blend with the shell instead of falling back to white.
        _ = try await page.evaluateJavaScript("document.querySelector('#shell').insertAdjacentHTML('afterbegin', '<header style=\"height:62px;background:rgba(0,0,0,0.5)\"></header>')")
        try await expectColor([127, 123, 102])
    }

    @Test func `document color is cached across attachment and updated after a real style change`() async throws {
        let configuration = WKWebViewConfiguration()
        var colors: [NSColor] = []
        PageBackground.install(in: configuration.userContentController) { _, color in colors.append(color) }
        let page = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        let (window, host) = hostWindow()
        defer { host.reset(); window.close() }
        host.show(page) { _ in }
        page.loadHTMLString("<html><head></head><body style='background:white'>Light</body></html>", baseURL: URL(string: "https://color.test/"))
        for _ in 0..<300 {
            if !colors.isEmpty { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(colors.count == 1)
        #expect(colors[0].usingColorSpace(.sRGB)?.redComponent == 1)
        for _ in 0..<10 {
            page.removeFromSuperview()
            host.addSubview(page)
        }
        try await Task.sleep(for: .milliseconds(150))
        #expect(colors.count == 1)
        _ = try await page.evaluateJavaScript("document.body.style.backgroundColor = '#14283c'")
        for _ in 0..<300 {
            if colors.count > 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(colors.count == 2)
        #expect(abs(colors[1].usingColorSpace(.sRGB)!.redComponent - 20.0 / 255) < 0.001)
        // A non-color mutation must not publish another toolbar update.
        _ = try await page.evaluateJavaScript("document.body.style.margin = '3px'")
        try await Task.sleep(for: .milliseconds(150))
        #expect(colors.count == 2)
        // A site's theme attribute is a real invalidation too.
        _ = try await page.evaluateJavaScript("const style = document.createElement('style'); style.textContent = 'html[data-theme=light] body { background: white !important; }'; document.head.append(style); document.documentElement.dataset.theme = 'light';")
        for _ in 0..<300 {
            if colors.count > 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(colors.count == 3)
        #expect(colors[2].usingColorSpace(.sRGB)?.redComponent == 1)
    }
}

@MainActor
struct PageBackgroundCacheTests {
    @Test func `reopened documents reuse their color and real changes replace it`() {
        let cache = PageBackgroundCache()
        cache.store(.white, for: "https://example.test/page")
        #expect(cache.color(for: "https://example.test/page") == .white)
        cache.store(.black, for: "https://example.test/page")
        #expect(cache.color(for: "https://example.test/page") == .black)
        #expect(cache.color(for: "https://example.test/other") == nil)
        // A different profile or private context has its own cache.
        #expect(PageBackgroundCache().color(for: "https://example.test/page") == nil)
    }

    @Test func `old document colors cannot grow without a bound`() {
        let cache = PageBackgroundCache(capacity: 2)
        cache.store(.white, for: "a")
        cache.store(.black, for: "b")
        cache.store(.red, for: "a")
        cache.store(.blue, for: "c")
        #expect(cache.color(for: "a") == .red)
        #expect(cache.color(for: "b") == nil)
        #expect(cache.color(for: "c") == .blue)
    }
}

struct ChromeThemePersistenceTests {
    @Test func `legacy theme strings still decode without changing their color`() throws {
        let theme = try JSONDecoder().decode(ChromeTheme.self, from: Data("\"#5EA4E8\"".utf8))
        #expect(theme.rawValue == "#5EA4E8")
        #expect(theme.glow == 1)
    }

    @Test func `gradient and glow settings survive a saved space round trip`() throws {
        var spaces = Spaces(theme: ChromeTheme.presets[5])
        spaces.update(Space.defaultID) { $0.theme.glow = 0.35 }
        let decoded = try JSONDecoder().decode(Spaces.self, from: JSONEncoder().encode(spaces))
        #expect(decoded == spaces)
    }

    @Test func `stored glow values stay within the supported range`() throws {
        for (stored, expected) in [(-2.0, 0.0), (3.0, 1.0)] {
            let data = Data("{\"tint\":\"\",\"glow\":\(stored)}".utf8)
            #expect(try JSONDecoder().decode(ChromeTheme.self, from: data).glow == expected)
        }
    }
}

struct ThemePaletteTests {
    @Test func `custom colors generate a saturated nearby companion hue`() {
        let palette = ThemePalette(red: 0.3, green: 0.6, blue: 0.8)
        #expect(palette.saturation >= 0.72)
        #expect(abs(palette.companionHue - palette.hue) < 0.1)
    }

    @Test func `neutral colors stay neutral and hue wraps safely`() {
        #expect(ThemePalette(red: 0.5, green: 0.5, blue: 0.5).saturation == 0)
        for color in [(1.0, 0.0, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0)] {
            let palette = ThemePalette(red: color.0, green: color.1, blue: color.2)
            #expect((0..<1).contains(palette.hue))
            #expect((0..<1).contains(palette.companionHue))
        }
    }

    @Test func `old two-color themes migrate to the primary without losing intensity`() throws {
        let data = Data(##"{"tint":"#74B486","secondaryTint":"#66B9BC","glow":0.6}"##.utf8)
        let theme = try JSONDecoder().decode(ChromeTheme.self, from: data)
        #expect(theme.rawValue == "#74B486")
        #expect(theme.glow == 0.6)
        #expect(try JSONDecoder().decode(ChromeTheme.self, from: JSONEncoder().encode(theme)) == theme)
    }
}
