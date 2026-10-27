/// Moving through and rearranging tabs in the order they're shown, which is
/// what keyboard switching, drag and drop and Close Tabs Below all follow.
extension Array where Element: Identifiable {
    /// The element `offset` places on from the one with `id`, wrapping around
    /// either end, as ⌃Tab and ⌃⇧Tab move.
    func element(_ offset: Int, from id: Element.ID) -> Element? {
        guard let index = firstIndex(where: { $0.id == id }) else { return nil }
        let target = (index + offset) % count
        return self[target < 0 ? target + count : target]
    }

    /// The element ⌘1 to ⌘9 select: the first eight by position, and ⌘9 the
    /// last however many there are.
    func element(forShortcut number: Int) -> Element? {
        switch number {
        case 9: last
        case 1...8 where number <= count: self[number - 1]
        default: nil
        }
    }

    /// Every element shown after the one with `id`.
    func elements(after id: Element.ID) -> ArraySlice<Element> {
        drop { $0.id != id }.dropFirst()
    }

    /// Moves the element with `id` into the place of the one with `target`,
    /// shifting the elements between them one place back toward where it was.
    mutating func move(_ id: Element.ID, onto target: Element.ID) {
        guard let from = firstIndex(where: { $0.id == id }),
              let to = firstIndex(where: { $0.id == target }),
              from != to else { return }
        insert(remove(at: from), at: to)
    }
}
