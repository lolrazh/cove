import AppKit
import Combine
import UniformTypeIdentifiers
import WebKit

/// What a click on the canvas does.
enum EaselTool: CaseIterable {
    case select
    case text
    case draw
}

/// The easel's canvas: its items as views, in board order, under a layer
/// that draws the selection and the stroke being drawn. It takes every click
/// itself: select, move, resize from the corner handle, draw, or place text;
/// double-click a text box to edit it. Delete removes the selection, ⌘Z
/// undoes (the easel keeps its own history), and images can be pasted or
/// dropped. It sits in a magnifying scroll view, which pans and zooms.
final class EaselCanvasView: NSView, NSUserInterfaceValidations {
    let easel: Easel
    var tool: EaselTool = .select {
        didSet { window?.invalidateCursorRects(for: self) }
    }
    var ink: EaselInk = .label
    /// Asked to go back to selecting, as after placing a text box.
    var onToolChange: ((EaselTool) -> Void)?
    var onOpenURL: ((URL) -> Void)?

    private let dataStore: WKWebsiteDataStore
    private var itemViews: [UUID: NSView] = [:]
    private let overlay = EaselOverlay()
    private var selection: Set<UUID> = [] {
        didSet { refreshSelection() }
    }
    private var drag: Drag?
    private var boardChanges: AnyCancellable?

    private enum Drag {
        case move(from: CGPoint, frames: [UUID: CGRect])
        case resize(UUID, from: CGPoint, frame: CGRect)
        case draw([CGPoint])
    }

    private static let minimumSize = CGSize(width: 2400, height: 1600)
    private static let strokeWidth = 3.0

    init(easel: Easel, dataStore: WKWebsiteDataStore) {
        self.easel = easel
        self.dataStore = dataStore
        super.init(frame: CGRect(origin: .zero, size: Self.minimumSize))
        addSubview(overlay)
        registerForDraggedTypes([.fileURL, .png, .tiff])
        boardChanges = easel.$board.sink { [weak self] board in self?.show(board) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var undoManager: UndoManager? { easel.undoManager }

    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: tool == .select ? .arrow : tool == .text ? .iBeam : .crosshair)
    }

    // MARK: - Showing the board

    private func show(_ board: EaselBoard) {
        let ids = Set(board.items.map(\.id))
        for (id, view) in itemViews where !ids.contains(id) {
            view.removeFromSuperview()
            itemViews[id] = nil
        }
        for item in board.items {
            let view = itemViews[item.id].flatMap { reuse($0, for: item) } ?? makeView(for: item)
            view.frame = item.frame
            itemViews[item.id] = view
            addSubview(view, positioned: .below, relativeTo: overlay)
        }
        selection = selection.intersection(ids)
        let extent = board.bounds.map { CGSize(width: $0.maxX + 600, height: $0.maxY + 600) } ?? .zero
        setFrameSize(CGSize(width: max(extent.width, Self.minimumSize.width), height: max(extent.height, Self.minimumSize.height)))
        overlay.frame = bounds
    }

    /// The item's view as it is, or nil if its content changed.
    private func reuse(_ view: NSView, for item: EaselItem) -> NSView? {
        switch (view, item.content) {
        case (let text as EaselTextView, .text(let string, _, _)):
            if !text.isEditing, text.string != string { text.string = string }
            return text
        case (let drawing as EaselDrawingView, .drawing):
            drawing.content = item.content
            return drawing
        case (is NSImageView, .image), (is EaselClipView, .clip):
            return view
        default:
            view.removeFromSuperview()
            return nil
        }
    }

    private func makeView(for item: EaselItem) -> NSView {
        switch item.content {
        case .text(let string, let size, let ink):
            let view = EaselTextView(string: string, size: size, ink: ink)
            view.onCommit = { [weak self] text, height in self?.commitText(item.id, text: text, height: height) }
            return view
        case .image(let name):
            let view = NSImageView()
            view.image = easel.image(named: name)
            view.imageScaling = .scaleAxesIndependently
            return view
        case .drawing:
            return EaselDrawingView(content: item.content)
        case .clip(let source, let snapshot):
            return EaselClipView(source: source, snapshot: easel.image(named: snapshot), dataStore: dataStore)
        }
    }

    // MARK: - Mouse

    override func hitTest(_ point: NSPoint) -> NSView? {
        // A text box being edited takes its own clicks.
        let hit = super.hitTest(point)
        return (hit as? EaselTextView)?.isEditing == true ? hit : (frame.contains(point) ? self : nil)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        switch tool {
        case .draw:
            drag = .draw([point])
        case .text:
            let item = EaselItem(frame: CGRect(x: point.x, y: point.y - 12, width: 240, height: 28), content: .text("", size: 18, ink: ink))
            easel.change("Add Text") { $0.items.append(item) }
            selection = [item.id]
            onToolChange?(.select)
            (itemViews[item.id] as? EaselTextView)?.beginEditing()
        case .select:
            if selection.count == 1, let id = selection.first, let frame = itemViews[id]?.frame, EaselOverlay.handle(of: frame).contains(point) {
                drag = .resize(id, from: point, frame: frame)
            } else if let id = item(at: point) {
                if event.clickCount == 2, let text = itemViews[id] as? EaselTextView {
                    text.beginEditing()
                    return
                }
                if event.modifierFlags.contains(.shift) {
                    selection.formSymmetricDifference([id])
                } else if !selection.contains(id) {
                    selection = [id]
                }
                drag = .move(from: point, frames: selection.reduce(into: [:]) { $0[$1] = itemViews[$1]?.frame })
            } else {
                selection = []
                drag = nil
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch drag {
        case .move(let start, let frames):
            for (id, frame) in frames {
                itemViews[id]?.frame = frame.offsetBy(dx: point.x - start.x, dy: point.y - start.y)
            }
        case .resize(let id, let start, let frame):
            var size = CGSize(width: max(frame.width + point.x - start.x, 24), height: max(frame.height + point.y - start.y, 16))
            // Images and clippings keep their shape unless Shift is held.
            if !(itemViews[id] is EaselTextView || itemViews[id] is EaselDrawingView), !event.modifierFlags.contains(.shift) {
                size.height = size.width * frame.height / max(frame.width, 1)
            }
            itemViews[id]?.frame.size = size
        case .draw(let points):
            drag = .draw(points + [point])
            overlay.stroke = (points + [point], ink.color, Self.strokeWidth)
        case nil:
            return
        }
        refreshSelection()
        autoscroll(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer { drag = nil }
        switch drag {
        case .move(_, let frames) where frames.contains(where: { itemViews[$0.key]?.frame != $0.value }):
            commitFrames(of: Set(frames.keys), named: "Move")
        case .resize(let id, _, _):
            commitFrames(of: [id], named: "Resize")
        case .draw(let points):
            overlay.stroke = nil
            guard points.count > 1, let item = EaselItem.drawing([points], ink: ink, width: Self.strokeWidth) else { return }
            easel.change("Draw") { $0.items.append(item) }
        default:
            break
        }
    }

    /// The overlay follows the selected views as they move.
    private func refreshSelection() {
        overlay.selection = selection.compactMap { itemViews[$0]?.frame }
    }

    private func item(at point: CGPoint) -> UUID? {
        easel.board.items.last { itemViews[$0.id]?.frame.contains(point) == true }?.id
    }

    private func commitFrames(of ids: Set<UUID>, named name: String) {
        easel.change(name) { board in
            for id in ids {
                guard var frame = itemViews[id]?.frame else { continue }
                frame.origin = CGPoint(x: max(frame.minX, 0), y: max(frame.minY, 0))
                board.update(id) { $0.frame = frame }
            }
        }
    }

    private func commitText(_ id: UUID, text: String, height: CGFloat) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            easel.change("Delete Text") { $0.remove([id]) }
            return
        }
        easel.change("Edit Text") { board in
            board.update(id) { item in
                guard case .text(_, let size, let ink) = item.content else { return }
                item.content = .text(text, size: size, ink: ink)
                item.frame.size.height = height
            }
        }
    }

    // MARK: - Keys and menus

    override func keyDown(with event: NSEvent) {
        switch event.specialKey {
        case .delete?, .deleteForward?:
            delete(nil)
        default:
            if event.keyCode == 53 { selection = [] } else { super.keyDown(with: event) }
        }
    }

    @objc func delete(_ sender: Any?) {
        guard !selection.isEmpty else { return }
        let removed = selection
        easel.change("Delete") { $0.remove(removed) }
    }

    /// The Edit menu's Undo and Redo, on the easel's own history.
    @objc func undo(_ sender: Any?) {
        easel.undoManager.undo()
    }

    @objc func redo(_ sender: Any?) {
        easel.undoManager.redo()
    }

    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(undo(_:)): easel.undoManager.canUndo
        case #selector(redo(_:)): easel.undoManager.canRedo
        case #selector(delete(_:)): !selection.isEmpty
        default: responds(to: item.action)
        }
    }

    override func selectAll(_ sender: Any?) {
        selection = Set(easel.board.items.map(\.id))
    }

    /// Images go in as images; text and addresses as text boxes.
    @objc func paste(_ sender: Any?) {
        let point = CGPoint(x: visibleRect.midX - 120, y: visibleRect.midY - 60)
        let pasteboard = NSPasteboard.general
        if let image = (pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage])?.first {
            easel.add(image, at: point)
        } else if let string = pasteboard.string(forType: .string), !string.isEmpty {
            let item = EaselItem(frame: CGRect(origin: point, size: CGSize(width: 320, height: 28)), content: .text(string, size: 18, ink: ink))
            easel.change("Paste") { $0.items.append(item) }
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let id = item(at: convert(event.locationInWindow, from: nil)), let item = easel.board.item(id) else { return nil }
        selection = [id]
        let menu = NSMenu()
        if case .clip(let source, let snapshot) = item.content {
            menu.addItem(EaselMenuItem("Refresh Clipping") { [weak self] in (self?.itemViews[id] as? EaselClipView)?.refresh() })
            menu.addItem(EaselMenuItem("Open Page") { [weak self] in self?.onOpenURL?(source.url) })
            menu.addItem(EaselMenuItem("Stop Live Updates") { [weak self] in
                self?.easel.change("Stop Live Updates") { $0.update(id) { $0.content = .image(snapshot) } }
            })
            menu.addItem(.separator())
        }
        menu.addItem(EaselMenuItem("Bring to Front") { [weak self] in self?.easel.change("Bring to Front") { $0.bringToFront(id) } })
        menu.addItem(EaselMenuItem("Delete") { [weak self] in self?.delete(nil) })
        return menu
    }

    // MARK: - Dropping

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        NSImage.canInit(with: sender.draggingPasteboard) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let images = sender.draggingPasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage], !images.isEmpty else { return false }
        var point = convert(sender.draggingLocation, from: nil)
        for image in images {
            easel.add(image, at: point)
            point = point.applying(CGAffineTransform(translationX: 24, y: 24))
        }
        return true
    }
}

/// The selection's outlines and resize handle, and the stroke being drawn,
/// over the items.
private final class EaselOverlay: NSView {
    var selection: [CGRect] = [] {
        didSet { needsDisplay = true }
    }
    var stroke: (points: [CGPoint], color: NSColor, width: Double)? {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    /// The corner a single selected item is resized by.
    static func handle(of frame: CGRect) -> CGRect {
        CGRect(x: frame.maxX - 6, y: frame.maxY - 6, width: 12, height: 12)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.setStroke()
        for frame in selection {
            let outline = NSBezierPath(rect: frame.insetBy(dx: -2, dy: -2))
            outline.lineWidth = 1.5
            outline.stroke()
        }
        if selection.count == 1, let frame = selection.first {
            let handle = NSBezierPath(ovalIn: Self.handle(of: frame).insetBy(dx: 1, dy: 1))
            NSColor.white.setFill()
            handle.fill()
            handle.stroke()
        }
        if let stroke {
            stroke.color.setStroke()
            EaselDrawingView.path(through: stroke.points, width: stroke.width).stroke()
        }
    }
}

/// A drawing item: its strokes, stretched to the frame.
final class EaselDrawingView: NSView {
    var content: EaselItem.Content {
        didSet { needsDisplay = true }
    }

    init(content: EaselItem.Content) {
        self.content = content
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard case .drawing(let strokes, let ink, let width) = content else { return }
        ink.color.setStroke()
        for stroke in strokes {
            let points = stroke.map { CGPoint(x: $0.x * bounds.width, y: $0.y * bounds.height) }
            Self.path(through: points, width: width).stroke()
        }
    }

    /// A smooth line through points: rounded joins and ends.
    static func path(through points: [CGPoint], width: Double) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach(path.line)
        return path
    }
}

/// A text box: plain text, edited in place, growing as it's typed into.
final class EaselTextView: NSTextView {
    /// The text and the height it needs, once editing ends.
    var onCommit: ((String, CGFloat) -> Void)?
    private(set) var isEditing = false

    init(string: String, size: Double, ink: EaselInk) {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)
        self.string = string
        font = .systemFont(ofSize: size, weight: .medium)
        textColor = ink.color
        drawsBackground = false
        isRichText = false
        isEditable = false
        isSelectable = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
    }

    func beginEditing() {
        isEditing = true
        isEditable = true
        isSelectable = true
        window?.makeFirstResponder(self)
        selectAll(nil)
    }

    override func didChangeText() {
        super.didChangeText()
        frame.size.height = fittingHeight
    }

    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }
        if isEditing {
            isEditing = false
            isEditable = false
            isSelectable = false
            onCommit?(string, fittingHeight)
        }
        return true
    }

    /// Escape ends editing, keeping what was typed.
    override func cancelOperation(_ sender: Any?) {
        window?.makeFirstResponder(superview)
    }

    private var fittingHeight: CGFloat {
        guard let layoutManager, let textContainer else { return frame.height }
        layoutManager.ensureLayout(for: textContainer)
        return max(layoutManager.usedRect(for: textContainer).height + textContainerInset.height * 2, 24)
    }
}

/// A menu item that runs a closure.
private final class EaselMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}
