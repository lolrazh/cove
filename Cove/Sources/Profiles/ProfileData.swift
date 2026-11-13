import Foundation

/// Browser records owned by one profile. No store is shared between profiles.
@MainActor
final class ProfileData {
    private let directory: URL
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
        self.directory = directory
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
    /// Called after windows have released this profile's pages. Downloaded
    /// files in the user's Downloads folder are not browser records.
    func deleteRecords() {
        downloads.items.forEach { downloads.cancelDownload($0) }
        downloads.clearCompleted()
        history.clearAll()
        archive.entries.forEach { archive.remove($0.id) }
        Array(documents.documents.keys).forEach { documents.delete($0) }
        documents.save()
        boosts.store.boosts.forEach { boosts.store.remove($0.id) }
        try? FileManager.default.removeItem(at: directory)
    }

}
