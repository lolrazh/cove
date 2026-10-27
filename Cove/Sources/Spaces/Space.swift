import SwiftUI

/// What a space is drawn as in the footer and its menus: an SF Symbol, or an
/// emoji the user typed.
enum SpaceIcon: Codable, Hashable {
    case symbol(String)
    case emoji(String)

    /// A small dot, like Arc's spaces before they're given an icon.
    static let dot = SpaceIcon.symbol("circle.fill")

    /// The symbols the space editor offers.
    static let symbols: [SpaceIcon] = [
        "circle.fill", "house", "briefcase", "book", "graduationcap", "star",
        "heart", "bolt", "leaf", "flame", "moon", "hammer",
        "paintbrush", "music.note", "gamecontroller", "airplane",
    ].map(SpaceIcon.symbol)
}

/// Who is browsing: a profile keeps its own cookies, logins and site data,
/// and each space browses as one of them. The default profile uses WebKit's
/// default data store, so everything from before profiles stays signed in.
struct Profile: Identifiable, Codable, Hashable {
    static let defaultID = UUID(uuidString: "C0FE0000-0000-4000-8000-000000000001")!

    let id: UUID
    var name: String

    var isDefault: Bool { id == Self.defaultID }
}

/// Arc's space: a sidebar of its own, with a name, an icon, a theme for the
/// frame, its own Pinned and its own Today. Favorites belong to the profile.
struct Space: Identifiable, Codable, Hashable {
    /// The first space, which holds whatever was open before Spaces.
    static let defaultID = UUID(uuidString: "C0FE0000-0000-4000-8000-000000000002")!

    let id: UUID
    var name: String
    var icon: SpaceIcon
    var theme: ChromeTheme
    var profileID: UUID
}

/// The spaces in their order, and the profiles they browse as. Pure, so the
/// edits can be tested; `SpaceStore` keeps it. There is always at least one
/// space and always the default profile.
struct Spaces: Codable, Equatable {
    private(set) var spaces: [Space]
    private(set) var profiles: [Profile]

    /// A first launch: one space in the default profile, in the theme the
    /// frame had before themes moved to spaces.
    init(theme: ChromeTheme = .system) {
        spaces = [Space(id: Space.defaultID, name: "Personal", icon: .dot, theme: theme, profileID: Profile.defaultID)]
        profiles = [Profile(id: Profile.defaultID, name: "Default")]
    }

    func space(_ id: UUID) -> Space? {
        spaces.first { $0.id == id }
    }

    func profile(_ id: UUID) -> Profile? {
        profiles.first { $0.id == id }
    }

    /// The space `offset` places from this one, without wrapping: swiping
    /// past the last space goes nowhere, as in Arc.
    func space(_ offset: Int, from id: UUID) -> Space? {
        guard let index = spaces.firstIndex(where: { $0.id == id }) else { return nil }
        return spaces.indices.contains(index + offset) ? spaces[index + offset] : nil
    }

    // MARK: - Spaces

    /// A new space at the end, named after its place and colored with the
    /// first theme no other space wears.
    @discardableResult
    mutating func addSpace(in profileID: UUID = Profile.defaultID) -> Space {
        let names = Set(spaces.map(\.name))
        let name = ((spaces.count + 1)...).lazy.map { "Space \($0)" }.first { !names.contains($0) }!
        let themes = ChromeTheme.presets.dropFirst()
        let theme = themes.first { theme in !spaces.contains { $0.theme == theme } }
            ?? themes[themes.startIndex + spaces.count % themes.count]
        let space = Space(id: UUID(), name: name, icon: .dot, theme: theme, profileID: profile(profileID)?.id ?? Profile.defaultID)
        spaces.append(space)
        return space
    }

    /// An empty name keeps the old one; an unknown profile changes nothing.
    mutating func update(_ id: UUID, _ change: (inout Space) -> Void) {
        guard let index = spaces.firstIndex(where: { $0.id == id }) else { return }
        var space = spaces[index]
        change(&space)
        space.name = space.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if space.name.isEmpty { space.name = spaces[index].name }
        if profile(space.profileID) == nil { space.profileID = spaces[index].profileID }
        spaces[index] = space
    }

    /// Removes a space, never the last one.
    mutating func removeSpace(_ id: UUID) {
        guard spaces.count > 1 else { return }
        spaces.removeAll { $0.id == id }
    }

    /// Moves a space one place or more along, staying within the list.
    mutating func moveSpace(_ id: UUID, by offset: Int) {
        guard let index = spaces.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(index + offset, 0), spaces.count - 1)
        spaces.insert(spaces.remove(at: index), at: target)
    }

    /// Settings' list reordering.
    mutating func moveSpaces(fromOffsets source: IndexSet, toOffset destination: Int) {
        spaces.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Profiles

    @discardableResult
    mutating func addProfile() -> Profile {
        let profile = Profile(id: UUID(), name: "Profile \(profiles.count + 1)")
        profiles.append(profile)
        return profile
    }

    mutating func renameProfile(_ id: UUID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].name = name
    }

    /// Removes a profile other than the default; its spaces move to the
    /// default profile.
    mutating func removeProfile(_ id: UUID) {
        guard id != Profile.defaultID, profile(id) != nil else { return }
        profiles.removeAll { $0.id == id }
        for index in spaces.indices where spaces[index].profileID == id {
            spaces[index].profileID = Profile.defaultID
        }
    }
}
