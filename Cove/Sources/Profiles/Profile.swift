import SwiftUI

/// A profile owns its theme, tabs, and browsing data. Its ID also identifies
/// its WebKit login store and stays unchanged when its name changes.
struct Profile: Identifiable, Codable, Hashable {
    static let defaultID = UUID(uuidString: "C0FE0000-0000-4000-8000-000000000001")!
    let id: UUID
    var name: String
    var theme: ChromeTheme
    var isDefault: Bool { id == Self.defaultID }
}

struct Profiles: Codable, Equatable {
    private(set) var profiles: [Profile]

    init(theme: ChromeTheme = .system) {
        profiles = [Profile(id: Profile.defaultID, name: "Personal", theme: theme)]
    }

    func profile(_ id: UUID) -> Profile? { profiles.first { $0.id == id } }

    func profile(_ offset: Int, from id: UUID) -> Profile? {
        guard let index = profiles.firstIndex(where: { $0.id == id }), profiles.indices.contains(index + offset) else { return nil }
        return profiles[index + offset]
    }

    @discardableResult
    mutating func addProfile() -> Profile {
        let names = Set(profiles.map(\.name))
        let name = ((profiles.count + 1)...).lazy.map { "Profile \($0)" }.first { !names.contains($0) }!
        let themes = ChromeTheme.presets.dropFirst()
        let theme = themes.first { theme in !profiles.contains { $0.theme == theme } }
            ?? themes[themes.startIndex + profiles.count % themes.count]
        let profile = Profile(id: UUID(), name: name, theme: theme)
        profiles.append(profile)
        return profile
    }

    mutating func update(_ id: UUID, _ change: (inout Profile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        var profile = profiles[index]
        change(&profile)
        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if profile.name.isEmpty { profile.name = profiles[index].name }
        profiles[index] = profile
    }

    /// Deletion never moves private data into another profile.
    mutating func removeProfile(_ id: UUID) {
        guard id != Profile.defaultID else { return }
        profiles.removeAll { $0.id == id }
    }

    mutating func moveProfile(_ id: UUID, by offset: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(index + offset, 0), profiles.count - 1)
        profiles.insert(profiles.remove(at: index), at: target)
    }

    mutating func moveProfiles(fromOffsets source: IndexSet, toOffset destination: Int) {
        profiles.move(fromOffsets: source, toOffset: destination)
    }
}
