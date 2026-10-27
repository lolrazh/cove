import Foundation

/// What to do with a tab nobody has looked at for a while: sleep it to give
/// back its memory, or archive it out of Today. Pure, so it can be tested.
struct TabIdlePolicy {
    /// Idle time after which a background tab sleeps; nil never sleeps.
    var sleepAfter: TimeInterval?
    /// Idle time after which a Today tab is archived; nil never archives.
    var archiveAfter: TimeInterval?

    /// What the policy needs to know about a tab.
    struct Tab {
        var isActive: Bool
        var isAsleep: Bool
        /// False for a start page, which has nothing to sleep. It can still be
        /// archived, which only closes it.
        var hasPage: Bool
        /// Playing audio, using the camera or microphone, or holding typed
        /// input: nothing a reload should interrupt.
        var isInUse: Bool
        /// When the tab was last selected, or last left.
        var lastUsedAt: Date
    }

    enum Action {
        case sleep
        case archive
    }

    /// Memory is short: every background tab that can sleep should, now, even
    /// when sleeping is set to never.
    var underMemoryPressure: Self {
        var policy = self
        policy.sleepAfter = 0
        return policy
    }

    /// Archiving wins when both are due. The selected tab and a tab in use
    /// are left alone.
    func action(for tab: Tab, at now: Date) -> Action? {
        guard !tab.isActive, !tab.isInUse else { return nil }
        let idle = now.timeIntervalSince(tab.lastUsedAt)
        if let archiveAfter, idle >= archiveAfter { return .archive }
        if let sleepAfter, idle >= sleepAfter, tab.hasPage, !tab.isAsleep { return .sleep }
        return nil
    }
}
