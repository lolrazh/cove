import AppKit
import Combine

/// A color to draw or write with on an easel. The label color follows light
/// and dark mode; the others are the system's.
enum EaselInk: String, Codable, CaseIterable {
    case label
    case red
    case orange
    case green
    case blue
    case purple

    var color: NSColor {
        switch self {
        case .label: .labelColor
        case .red: .systemRed
        case .orange: .systemOrange
        case .green: .systemGreen
        case .blue: .systemBlue
        case .purple: .systemPurple
        }
    }
}

/// One thing on an easel, in its frame on the canvas.
struct EaselItem: Identifiable, Codable, Equatable {
    enum Content: Codable, Equatable {
        case text(String, size: Double, ink: EaselInk)
        /// An image, by its file's name in the easel's package.
        case image(String)
        /// Freehand strokes, their points from 0 to 1 across the frame, so
        /// the drawing stretches with it.
        case drawing([[CGPoint]], ink: EaselInk, width: Double)
        /// A region of a page shown live, with a snapshot (a file in the
        /// package) to show while it loads.
        case clip(CaptureSource, snapshot: String)
    }

    var id = UUID()
    var frame: CGRect
    var content: Content

    /// Strokes drawn on the canvas, as an item framed around them.
    static func drawing(_ strokes: [[CGPoint]], ink: EaselInk, width: Double) -> EaselItem? {
        let points = strokes.flatMap { $0 }
        guard let first = points.first else { return nil }
        var bounds = points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
        bounds = bounds.insetBy(dx: -width, dy: -width)
        let normalized = strokes.map { stroke in
            stroke.map { CGPoint(x: ($0.x - bounds.minX) / bounds.width, y: ($0.y - bounds.minY) / bounds.height) }
        }
        return EaselItem(frame: bounds, content: .drawing(normalized, ink: ink, width: width))
    }
}

/// What's on an easel, front to back last. Pure, so the edits can be tested;
/// `Easel` keeps it live, undoable and saved.
struct EaselBoard: Codable, Equatable {
    var items: [EaselItem] = []

    /// Everything's extent on the canvas.
    var bounds: CGRect? {
        items.dropFirst().reduce(items.first?.frame) { $0?.union($1.frame) }
    }

    /// The words on the easel, for finding it from the Command Bar.
    var text: String {
        items.compactMap { item in
            switch item.content {
            case .text(let text, _, _): text
            case .clip(let source, _): source.title
            default: nil
            }
        }
        .joined(separator: "\n")
    }

    /// The image files the items use.
    var files: Set<String> {
        Set(items.compactMap { item in
            switch item.content {
            case .image(let name), .clip(_, let name): name
            default: nil
            }
        })
    }

    /// Where something new of this size goes: below everything, at the left
    /// margin, or at the top left of an empty easel.
    func placement(for size: CGSize) -> CGRect {
        let margin = 40.0
        let origin = bounds.map { CGPoint(x: max($0.minX, margin), y: $0.maxY + 24) } ?? CGPoint(x: margin, y: margin)
        return CGRect(origin: origin, size: size)
    }

    func item(_ id: UUID) -> EaselItem? {
        items.first { $0.id == id }
    }

    mutating func update(_ id: UUID, _ change: (inout EaselItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    mutating func move(_ ids: Set<UUID>, by offset: CGSize) {
        for index in items.indices where ids.contains(items[index].id) {
            items[index].frame = items[index].frame.offsetBy(dx: offset.width, dy: offset.height)
        }
    }

    mutating func remove(_ ids: Set<UUID>) {
        items.removeAll { ids.contains($0.id) }
    }

    mutating func bringToFront(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.append(items.remove(at: index))
    }
}

/// An easel, live: its board, the images it uses, and its own undo history.
/// Kept as a package, `<id>.easel`, holding `board.plist` and the images,
/// saved a second after the last change.
@MainActor
final class Easel: ObservableObject {
    let id: UUID
    @Published private(set) var board: EaselBoard
    let undoManager = UndoManager()
    private let packageURL: URL?
    /// Images by file name; in memory only for an easel without a package.
    private var images: [String: NSImage] = [:]
    private var unsavedImages: [String: Data] = [:]
    private let onSave: (String) -> Void
    private var pendingSave: Task<Void, Never>?

    init(id: UUID, packageURL: URL?, onSave: @escaping (String) -> Void) {
        self.id = id
        self.packageURL = packageURL
        self.onSave = onSave
        board = packageURL
            .flatMap { try? Data(contentsOf: $0.appendingPathComponent("board.plist")) }
            .flatMap { try? PropertyListDecoder().decode(EaselBoard.self, from: $0) } ?? EaselBoard()
        packageURL.map { Self.removeUnusedImages(in: $0, keeping: board.files) }
    }

    /// Changes the board as one undoable step.
    func change(_ name: String, _ change: (inout EaselBoard) -> Void) {
        var board = board
        change(&board)
        guard board != self.board else { return }
        setBoard(board, named: name)
    }

    private func setBoard(_ board: EaselBoard, named name: String) {
        let previous = self.board
        self.board = board
        undoManager.registerUndo(withTarget: self) { easel in
            MainActor.assumeIsolated { easel.setBoard(previous, named: name) }
        }
        undoManager.setActionName(name)
        scheduleSave()
    }

    // MARK: - Images

    /// Keeps an image's PNG data in the package and returns its file name.
    func addImage(_ png: Data) -> String {
        let name = "\(UUID().uuidString).png"
        unsavedImages[name] = png
        images[name] = NSImage(data: png)
        return name
    }

    func image(named name: String) -> NSImage? {
        if let image = images[name] { return image }
        let image = packageURL.flatMap { NSImage(contentsOf: $0.appendingPathComponent(name)) }
        images[name] = image
        return image
    }

    /// An image from the pasteboard or a drop, placed at a point, at most
    /// 480 points wide.
    func add(_ image: NSImage, at point: CGPoint) {
        guard let png = image.pngData else { return }
        let name = addImage(png)
        let scale = min(1, 480 / max(image.size.width, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        change("Add Image") { $0.items.append(EaselItem(frame: CGRect(origin: point, size: size), content: .image(name))) }
    }

    /// A capture, as a live clipping of its page below everything else.
    func add(_ capture: Capture) {
        guard let png = capture.pngData else { return }
        let snapshot = addImage(png)
        let scale = min(1, 640 / max(capture.image.size.width, 1))
        let size = CGSize(width: capture.image.size.width * scale, height: capture.image.size.height * scale)
        change("Add Clipping") { board in
            board.items.append(EaselItem(frame: board.placement(for: size), content: .clip(capture.source, snapshot: snapshot)))
        }
    }

    // MARK: - Saving

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    /// Saves now, if anything changed since the last save.
    func save() {
        guard let pendingSave else { return }
        pendingSave.cancel()
        self.pendingSave = nil
        onSave(board.text)
        guard let packageURL else { return }
        try? FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        for (name, data) in unsavedImages {
            try? data.write(to: packageURL.appendingPathComponent(name), options: .atomic)
        }
        unsavedImages = [:]
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try? encoder.encode(board).write(to: packageURL.appendingPathComponent("board.plist"), options: .atomic)
    }

    /// Images no item uses go when the easel is next opened, so undo can
    /// still bring back what was deleted this session.
    private static func removeUnusedImages(in packageURL: URL, keeping used: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: packageURL.path)) ?? []
        for file in files where file.hasSuffix(".png") && !used.contains(file) {
            try? FileManager.default.removeItem(at: packageURL.appendingPathComponent(file))
        }
    }
}

extension NSImage {
    /// The image as PNG, marked with its size in points.
    var pngData: Data? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = size
        return bitmap.representation(using: .png, properties: [:])
    }
}
