import Foundation

/// Pure layout / update-placement rules, split out so they can be tested
/// without compiling the macOS app (AppKit / SwiftUI).
///
/// Invariants (see Tests/SkillSwitchTests/InvariantTests.swift):
/// 1. Updating an OFF/parked skill must keep it OFF — park + OffBook, no live
///    manifest entry, no fire-now prefix. Updating an armed skill stays armed.
/// 2. `sessionsRoot` must resolve the session audit tree for the *same*
///    account `locate()` picked, for org *and* personal nestings.
public enum CoworkLayout {
    public static let pluginRootName = "skills-plugin"

    /// Where a re-download should land, given the skill's pre-update arm state.
    ///
    /// Green means armed (live entry + fire-now prefix). An OFF/parked skill
    /// is not armed; a leftover unarmed live entry is also not armed — both
    /// belong in the park so scan() cannot paint them green.
    public enum UpdatePlacement: Equatable {
        case liveAndArm
        case parkAndRemember
    }

    public static func updatePlacement(isArmed: Bool) -> UpdatePlacement {
        isArmed ? .liveAndArm : .parkAndRemember
    }

    /// Expected post-update shape. Production `install(..., keepOff:)` must
    /// match this; the test target asserts it without touching Cowork.
    public struct OffUpdateExpectation: Equatable {
        public var liveManifestEntry: Bool
        public var filesInPark: Bool
        public var armedPrefix: Bool

        public init(liveManifestEntry: Bool, filesInPark: Bool, armedPrefix: Bool) {
            self.liveManifestEntry = liveManifestEntry
            self.filesInPark = filesInPark
            self.armedPrefix = armedPrefix
        }
    }

    public static func expectedStateAfterUpdate(wasArmed: Bool) -> OffUpdateExpectation {
        switch updatePlacement(isArmed: wasArmed) {
        case .liveAndArm:
            return OffUpdateExpectation(liveManifestEntry: true, filesInPark: false, armedPrefix: true)
        case .parkAndRemember:
            return OffUpdateExpectation(liveManifestEntry: false, filesInPark: true, armedPrefix: false)
        }
    }

    /// Session audit tree for the account whose plugin dir `locate()` picked.
    ///
    /// Cowork stores chats as a *mirror* of the path under `skills-plugin/`:
    ///   …/skills-plugin/<org>/<account>  →  …/local-agent-mode-sessions/<account>/<org>
    ///   …/skills-plugin/<account>        →  …/local-agent-mode-sessions/<account>
    ///   …/skills-plugin                  →  …/local-agent-mode-sessions
    /// Deeper nesting reverses the same way (components under skills-plugin,
    /// leaf-first, appended to the sessions parent).
    ///
    /// The previous last-two-components + walk-up-3 only matched the org
    /// shape (exactly two folders under skills-plugin). Personal 1-deep and
    /// 0-deep layouts pointed TripScanner at a directory that does not
    /// contain `local_*/audit.jsonl`.
    ///
    /// `SKILLSWITCH_SESSIONS_DIR` is applied by the caller before this.
    public static func sessionsRoot(forPluginDir pluginDir: URL) -> URL {
        var cursor = pluginDir.standardizedFileURL
        var below: [String] = []
        for _ in 0..<16 {
            if cursor.lastPathComponent == pluginRootName {
                var root = cursor.deletingLastPathComponent()
                for name in below {
                    root = root.appendingPathComponent(name, isDirectory: true)
                }
                return root
            }
            let parent = cursor.deletingLastPathComponent()
            if parent.path == cursor.path { break }
            below.append(cursor.lastPathComponent)
            cursor = parent
        }
        // Sandbox / SKILLSWITCH_PLUGIN_DIR with no skills-plugin ancestor:
        // keep the historical 2-deep org mirror so existing temp fixtures
        // still resolve. Prefer SKILLSWITCH_SESSIONS_DIR for other layouts.
        let account = pluginDir.lastPathComponent
        let org = pluginDir.deletingLastPathComponent().lastPathComponent
        return pluginDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(account, isDirectory: true)
            .appendingPathComponent(org, isDirectory: true)
    }
}
