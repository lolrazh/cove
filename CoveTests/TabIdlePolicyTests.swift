import Foundation
import Testing
@testable import Cove

struct TabIdlePolicyTests {
    private let policy = TabIdlePolicy(sleepAfter: 30 * 60, archiveAfter: 24 * 3600)
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func tab(
        idle: TimeInterval,
        isActive: Bool = false,
        isAsleep: Bool = false,
        hasPage: Bool = true,
        isInUse: Bool = false
    ) -> TabIdlePolicy.Tab {
        TabIdlePolicy.Tab(
            isActive: isActive,
            isAsleep: isAsleep,
            hasPage: hasPage,
            isInUse: isInUse,
            lastUsedAt: now.addingTimeInterval(-idle)
        )
    }

    @Test func `a tab sleeps once idle past the delay, not before`() {
        #expect(policy.action(for: tab(idle: 29 * 60), at: now) == nil)
        #expect(policy.action(for: tab(idle: 30 * 60), at: now) == .sleep)
    }

    @Test func `the selected tab and a tab in use are left alone`() {
        #expect(policy.action(for: tab(idle: 48 * 3600, isActive: true), at: now) == nil)
        #expect(policy.action(for: tab(idle: 48 * 3600, isInUse: true), at: now) == nil)
    }

    @Test func `a sleeping tab and an empty tab have nothing to sleep`() {
        #expect(policy.action(for: tab(idle: 3600, isAsleep: true), at: now) == nil)
        #expect(policy.action(for: tab(idle: 3600, hasPage: false), at: now) == nil)
    }

    @Test func `archiving wins once due, for sleeping and empty tabs too`() {
        #expect(policy.action(for: tab(idle: 24 * 3600), at: now) == .archive)
        #expect(policy.action(for: tab(idle: 24 * 3600, isAsleep: true), at: now) == .archive)
        #expect(policy.action(for: tab(idle: 24 * 3600, hasPage: false), at: now) == .archive)
    }

    @Test func `never means never`() {
        let never = TabIdlePolicy(sleepAfter: nil, archiveAfter: nil)
        #expect(never.action(for: tab(idle: 365 * 24 * 3600), at: now) == nil)
    }

    @Test func `memory pressure sleeps every background tab that can, even when set to never`() {
        let pressed = TabIdlePolicy(sleepAfter: nil, archiveAfter: nil).underMemoryPressure
        #expect(pressed.action(for: tab(idle: 0), at: now) == .sleep)
        #expect(pressed.action(for: tab(idle: 0, isActive: true), at: now) == nil)
        #expect(pressed.action(for: tab(idle: 0, isInUse: true), at: now) == nil)
        #expect(pressed.action(for: tab(idle: 0, isAsleep: true), at: now) == nil)
        #expect(pressed.archiveAfter == nil)
    }
}
