import Foundation
import XCTest
@testable import SkillSwitchCore

/// Fixture-oriented checks for the two invariants this PR fixes.
/// These run against the pure helpers (no Cowork, no Mac UI). They were
/// not executed in the environment that opened the PR.
final class InvariantTests: XCTestCase {

    // MARK: - Bug 1: OFF-update must stay OFF

    func testArmedUpdateStaysLiveAndArmed() {
        XCTAssertEqual(CoworkLayout.updatePlacement(isArmed: true), .liveAndArm)
        XCTAssertEqual(
            CoworkLayout.expectedStateAfterUpdate(wasArmed: true),
            CoworkLayout.OffUpdateExpectation(
                liveManifestEntry: true, filesInPark: false, armedPrefix: true)
        )
    }

    func testOffUpdateParksWithNoLiveEntry() {
        XCTAssertEqual(CoworkLayout.updatePlacement(isArmed: false), .parkAndRemember)
        XCTAssertEqual(
            CoworkLayout.expectedStateAfterUpdate(wasArmed: false),
            CoworkLayout.OffUpdateExpectation(
                liveManifestEntry: false, filesInPark: true, armedPrefix: false)
        )
    }

    // MARK: - Bug 2: sessionsRoot matches locate() for org AND personal

    func testOrgTwoDeepMirrorsAccountThenOrg() {
        let plugin = URL(fileURLWithPath:
            "/Users/x/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/acme-org/acct-99",
            isDirectory: true)
        let root = CoworkLayout.sessionsRoot(forPluginDir: plugin)
        XCTAssertEqual(
            root.path,
            "/Users/x/Library/Application Support/Claude/local-agent-mode-sessions/acct-99/acme-org"
        )
    }

    func testPersonalOneDeepUsesAccountOnly() {
        let plugin = URL(fileURLWithPath:
            "/Users/x/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/acct-99",
            isDirectory: true)
        let root = CoworkLayout.sessionsRoot(forPluginDir: plugin)
        XCTAssertEqual(
            root.path,
            "/Users/x/Library/Application Support/Claude/local-agent-mode-sessions/acct-99"
        )
    }

    func testZeroDeepUsesSessionsParent() {
        let plugin = URL(fileURLWithPath:
            "/Users/x/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin",
            isDirectory: true)
        let root = CoworkLayout.sessionsRoot(forPluginDir: plugin)
        XCTAssertEqual(
            root.path,
            "/Users/x/Library/Application Support/Claude/local-agent-mode-sessions"
        )
    }

    func testThreeDeepReversesAllComponents() {
        let plugin = URL(fileURLWithPath:
            "/Users/x/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/a/b/c",
            isDirectory: true)
        let root = CoworkLayout.sessionsRoot(forPluginDir: plugin)
        XCTAssertEqual(
            root.path,
            "/Users/x/Library/Application Support/Claude/local-agent-mode-sessions/c/b/a"
        )
    }

    /// The old last-two + walk-up-3 formula, applied to a 1-deep personal
    /// layout, lands *outside* local-agent-mode-sessions. That's the bug.
    func testLegacyWalkUpThreeMissesPersonalOneDeep() {
        let plugin = URL(fileURLWithPath:
            "/Users/x/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/acct-99",
            isDirectory: true)
        let account = plugin.lastPathComponent
        let org = plugin.deletingLastPathComponent().lastPathComponent
        let legacy = plugin
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(account, isDirectory: true)
            .appendingPathComponent(org, isDirectory: true)
        XCTAssertNotEqual(legacy.path, CoworkLayout.sessionsRoot(forPluginDir: plugin).path)
        XCTAssertFalse(legacy.path.contains("local-agent-mode-sessions/acct-99"))
    }
}
