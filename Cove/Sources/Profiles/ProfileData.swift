import Foundation

/// Browser records owned by one profile. No store is shared between profiles.
@MainActor
final class ProfileData {
    let id: UUID
    let history: HistoryStore
    let favicons: FaviconStore
    let downloads: DownloadManager
    let archive: TabArchive
    let documents: DocumentStore
    let zoom: SiteZoomStore
    let blocker: ContentBlockerManager
    let environment: WebKitEnvironment
    let boosts: BoostInjector

    init(id: UUID, settings: BrowserSettingsStore, root: URL = ProfileMigration.root) {
        self.id = id
        let directory = root.appendingPathComponent(id.uuidString)
        history = HistoryStore(settings: settings, databasePath: directory.appendingPathComponent("history.db").path)
        favicons = FaviconStore(databasePath: directory.appendingPathComponent("favicons.db").path)
        downloads = DownloadManager(settings: settings)
        archive = TabArchive(directory: directory)
        documents = DocumentStore(directory: directory.appendingPathComponent("Documents"))
        zoom = SiteZoomStore(fileURL: directory.appendingPathComponent("zoom.plist"))
        blocker = ContentBlockerManager(settings: settings, exceptionsURL: directory.appendingPathComponent("content-blocking.plist"))
        environment = WebKitEnvironment(contentBlockerManager: blocker)
        boosts = BoostInjector(store: BoostStore(fileURL: directory.appendingPathComponent("boosts.json")))
    }
}
