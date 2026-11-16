import AppKit

/// A quiet grid on either system appearance. Keep native cells and contents.
enum NoteTableAppearance {
    static func apply(to text: NSMutableAttributedString) {
        var cells: [ObjectIdentifier: NSTextTableBlock] = [:]
        text.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let paragraph = value as? NSParagraphStyle,
                  paragraph.textBlocks.contains(where: { $0 is NSTextTableBlock }),
                  let style = paragraph.mutableCopy() as? NSMutableParagraphStyle else { return }
            style.textBlocks = paragraph.textBlocks.map { block in
                guard let original = block as? NSTextTableBlock else { return block }
                let id = ObjectIdentifier(original)
                if let cell = cells[id] { return cell }
                let cell = original.copy() as! NSTextTableBlock
                cell.table.collapsesBorders = true
                cell.setWidth(0.5, type: .absolute, for: .border)
                cell.setBorderColor(.separatorColor)
                cell.setWidth(6, type: .absolute, for: .padding)
                cells[id] = cell
                return cell
            }
            text.addAttribute(.paragraphStyle, value: style, range: range)
        }
    }
}

extension NoteTextView {
    enum CellDirection { case next, previous, down, up }

    /// Table cells stay native RTF blocks. Only keyboard navigation differs
    /// from NSTextView's default, which inserts a literal tab inside a cell.
    func moveInTable(_ direction: CellDirection) -> Bool {
        guard let textStorage, textStorage.length > 0 else { return false }
        let index = min(selectedRange().location, textStorage.length - 1)
        guard let paragraph = textStorage.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle,
              let current = paragraph.textBlocks.last as? NSTextTableBlock else { return false }
        let tableRange = textStorage.range(of: current.table, at: index)
        var cells: [(block: NSTextTableBlock, range: NSRange)] = []
        textStorage.enumerateAttribute(.paragraphStyle, in: tableRange) { value, range, _ in
            guard let style = value as? NSParagraphStyle,
                  let block = style.textBlocks.last as? NSTextTableBlock,
                  block.table === current.table else { return }
            if cells.last?.block === block {
                cells[cells.count - 1].range = NSUnionRange(cells[cells.count - 1].range, range)
            } else { cells.append((block, range)) }
        }
        guard let position = cells.firstIndex(where: { $0.block === current }) else { return false }
        let target: Int?
        switch direction {
        case .next: target = position + 1 < cells.count ? position + 1 : nil
        case .previous: target = position > 0 ? position - 1 : nil
        case .down: target = cells.firstIndex { $0.block.startingRow == current.startingRow + current.rowSpan && $0.block.startingColumn == current.startingColumn }
        case .up: target = cells.lastIndex { $0.block.startingRow < current.startingRow && $0.block.startingColumn == current.startingColumn }
        }
        if let target {
            setSelectedRange(NSRange(location: cells[target].range.location, length: 0))
        } else if direction == .next || direction == .down {
            let lastRow = cells.map { $0.block.startingRow + $0.block.rowSpan }.max() ?? 1
            // Keep merged/imported tables intact. The native table panel owns
            // structural edits for those; simple tables can grow with Return.
            guard cells.allSatisfy({ $0.block.rowSpan == 1 && $0.block.columnSpan == 1 }) else { return true }
            let row = NSMutableAttributedString()
            for column in 0..<current.table.numberOfColumns {
                let cell = NSTextTableBlock(table: current.table, startingRow: lastRow, rowSpan: 1, startingColumn: column, columnSpan: 1)
                let template = cells.last { $0.block.startingColumn == column }?.block ?? current
                cell.setContentWidth(template.contentWidth, type: template.contentWidthValueType)
                cell.verticalAlignment = template.verticalAlignment
                cell.backgroundColor = template.backgroundColor
                for edge in [NSRectEdge.minX, .maxX, .minY, .maxY] {
                    cell.setBorderColor(template.borderColor(for: edge), for: edge)
                    for layer in [NSTextBlock.Layer.padding, .border, .margin] {
                        cell.setWidth(template.width(for: layer, edge: edge), type: template.widthValueType(for: layer, edge: edge), for: layer, edge: edge)
                    }
                }
                let style = NoteTextStyle.body.paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                style.textBlocks = [cell]
                var attributes = NoteTextStyle.body.attributes
                attributes[.paragraphStyle] = style
                row.append(NSAttributedString(string: "\n", attributes: attributes))
            }
            let end = NSMaxRange(tableRange)
            insertText(row, replacementRange: NSRange(location: end, length: 0))
            let column = direction == .down ? current.startingColumn : 0
            setSelectedRange(NSRange(location: end + column, length: 0))
        } else {
            setSelectedRange(NSRange(location: tableRange.location, length: 0))
        }
        scrollRangeToVisible(selectedRange())
        return true
    }
}
