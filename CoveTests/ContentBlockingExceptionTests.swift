import Foundation
import Testing
@testable import Cove

@MainActor
struct ContentBlockingExceptionTests {
    private func makeManager() throws -> (ContentBlockerManager, UserDefaults) {
        let defaults = try #require(UserDefaults(suiteName: "ContentBlockingExceptionTests"))
        defaults.removePersistentDomain(forName: "ContentBlockingExceptionTests")
        defaults.set(false, forKey: BrowserSettingKeys.contentBlockingEnabled)
        let settings = BrowserSettingsStore(defaults: defaults)
        return (ContentBlockerManager(settings: settings, defaults: defaults), defaults)
    }

    @Test func `turning blocking off covers the site and survives a relaunch`() throws {
        let (manager, defaults) = try makeManager()
        manager.setBlocks(false, on: URL(string: "https://www.example.com/a"))

        let reopened = ContentBlockerManager(settings: BrowserSettingsStore(defaults: defaults), defaults: defaults)
        #expect(!reopened.blocks(on: URL(string: "https://example.com/b")))
        #expect(!reopened.blocks(on: URL(string: "https://news.example.com")))
        #expect(reopened.blocks(on: URL(string: "https://example.org")))
    }

    @Test func `turning blocking on lifts a parent site's exception`() throws {
        let (manager, _) = try makeManager()
        manager.setBlocks(false, on: URL(string: "https://example.com"))
        manager.setBlocks(true, on: URL(string: "https://news.example.com"))
        #expect(manager.blocks(on: URL(string: "https://example.com")))
    }
}
