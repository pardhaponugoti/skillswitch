import Foundation

enum CoworkError: LocalizedError {
    case notFound
    case badManifest
    case skillMissing(String)
    case builtinCollision(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Couldn't find Claude's Cowork skills. Install the Claude desktop app and open a Cowork chat once."
        case .badManifest:
            return "Claude's skills list looks unreadable — try restarting the Claude app."
        case .skillMissing(let name):
            return "“\(name)” is no longer in Claude's skills list — hit rescan."
        case .builtinCollision(let name):
            return "“\(name)” is already built into Claude."
        }
    }
}

/// One Cowork account's skills-plugin folder: `manifest.json` plus a
/// `skills/<skillId>/` tree. Cowork's background sync preserves entries marked
/// `creatorType: "user", syncManaged: false` — the supported extension point
/// SkillSwitch writes through. Flipping a breaker is just rewriting `enabled`.
struct CoworkEnvironment {
    let dir: URL

    var manifestURL: URL { dir.appendingPathComponent("manifest.json") }
    var skillsDir: URL { dir.appendingPathComponent("skills", isDirectory: true) }

    /// Stable namespace for SkillSwitch's own bookkeeping (the park, OffBook).
    /// Two Cowork accounts on one Mac — say a work org and a personal account —
    /// must never share OFF state: a skill switched off on one must not surface,
    /// or get rewired, on the other. The last two path components (org/account
    /// for team accounts; still unique per account dir for personal layouts)
    /// identify the account.
    var accountKey: String {
        let account = dir.lastPathComponent
        let org = dir.deletingLastPathComponent().lastPathComponent
        return "\(org)_\(account)"
    }

    /// Cowork keeps chat sessions under `local-agent-mode-sessions/<accountId>/<orgId>/`
    /// — the mirror image of the skills-plugin path, which is `<orgId>/<accountId>`.
    /// `SKILLSWITCH_SESSIONS_DIR` overrides for tests.
    var sessionsRoot: URL {
        if let override = ProcessInfo.processInfo.environment["SKILLSWITCH_SESSIONS_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let account = dir.lastPathComponent
        let org = dir.deletingLastPathComponent().lastPathComponent
        return dir.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(account, isDirectory: true)
            .appendingPathComponent(org, isDirectory: true)
    }

    /// The account folder under Claude's skills-plugin root whose manifest was
    /// touched most recently — that's the signed-in account. `SKILLSWITCH_PLUGIN_DIR`
    /// overrides the search so tests can run against a sandbox.
    static func locate() -> CoworkEnvironment? {
        let fm = FileManager.default
        if let override = ProcessInfo.processInfo.environment["SKILLSWITCH_PLUGIN_DIR"], !override.isEmpty {
            let dir = URL(fileURLWithPath: override, isDirectory: true)
            return fm.fileExists(atPath: dir.appendingPathComponent("manifest.json").path)
                ? CoworkEnvironment(dir: dir) : nil
        }

        let root = fm.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin", isDirectory: true)
        // Account folders sit at different depths for personal vs. org/team
        // accounts, so don't assume a fixed nesting — walk the tree (bounded)
        // and take the newest manifest.json, which is the signed-in account.
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        var best: (dir: URL, modified: Date)?
        for case let url as URL in enumerator {
            if enumerator.level > 6 { enumerator.skipDescendants(); continue }
            guard url.lastPathComponent == "manifest.json",
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate else { continue }
            let account = url.deletingLastPathComponent()
            if best == nil || modified > best!.modified {
                best = (account, modified)
            }
        }
        return best.map { CoworkEnvironment(dir: $0.dir) }
    }

    // MARK: - Manifest I/O

    /// Parsed with JSONSerialization (not Codable) so fields SkillSwitch doesn't
    /// know about survive the round trip untouched.
    func readManifest() throws -> [String: Any] {
        guard let data = try? Data(contentsOf: manifestURL) else { throw CoworkError.notFound }
        guard let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CoworkError.badManifest
        }
        return manifest
    }

    func readSkillEntries() throws -> [[String: Any]] {
        guard let entries = try readManifest()["skills"] as? [[String: Any]] else {
            throw CoworkError.badManifest
        }
        return entries
    }

    func entry(skillId: String) throws -> [String: Any]? {
        try readSkillEntries().first { $0["skillId"] as? String == skillId }
    }

    /// Atomic replace — Cowork quarantines a manifest it can't parse, so a
    /// half-written file must never be visible. Cowork holds an in-process
    /// mutex around its own writes that we can't take; fresh read + atomic
    /// write keeps the race window to a single flip.
    private func write(manifest: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: manifestURL, options: .atomic)
    }

    // MARK: - Arming

    /// The description is what Cowork puts in front of the model, so it's the
    /// one lever that makes a skill fire on its own at the start of a chat.
    /// Arming prepends this instruction; tripping/disarming strips it.
    static let armPrefix = "IMPORTANT — the user armed this skill to run now: invoke it at the very start of the conversation, before anything else, even if the user's message doesn't mention it. The skill: "

    /// Some skills ship with `disable-model-invocation: true` — Cowork blocks
    /// the model from starting them; only the user's slash command can. For
    /// those, arming instead tells Claude to hand the user the switch: prompt
    /// them to type the command right at the start of the chat. When they do,
    /// the invocation lands in the session log and the breaker trips normally.
    static let armPrefixManual = "IMPORTANT — the user armed this skill to run now, but it can only be started by the user, not by you: at the very start of the conversation, before anything else, tell the user to type this skill's slash command (its name with a leading /) to begin. The skill: "

    static func strippedDescription(_ description: String) -> String {
        for prefix in [armPrefix, armPrefixManual] where description.hasPrefix(prefix) {
            return String(description.dropFirst(prefix.count))
        }
        return description
    }

    static func isArmedDescription(_ description: String) -> Bool {
        description.hasPrefix(armPrefix) || description.hasPrefix(armPrefixManual)
    }

    /// True when the skill's SKILL.md carries `disable-model-invocation: true`.
    /// Checks the live folder first, then the park (OFF skills live there).
    func isManualOnly(skillId: String) -> Bool {
        for dir in [skillsDir.appendingPathComponent(skillId, isDirectory: true),
                    parkedDir(skillId: skillId)] {
            guard let text = try? String(contentsOf: dir.appendingPathComponent("SKILL.md"), encoding: .utf8) else { continue }
            return Frontmatter.parse(text)["disable-model-invocation"] == "true"
        }
        return false
    }

    /// Switch a user skill ON as a one-shot: enabled, with the fire-now prefix
    /// (or, for manual-only skills, the ask-the-user prefix).
    func arm(skillId: String) throws {
        let prefix = isManualOnly(skillId: skillId) ? Self.armPrefixManual : Self.armPrefix
        try update(skillId: skillId) { entry in
            let description = Self.strippedDescription(entry["description"] as? String ?? "")
            entry["description"] = prefix + description
            entry["enabled"] = true
        }
    }

    /// Switch a user skill steadily ON (persona-style): enabled with its
    /// original description — available to Claude, but never force-fired and
    /// never tripped.
    func setSteadyOn(skillId: String) throws {
        try update(skillId: skillId) { entry in
            entry["description"] = Self.strippedDescription(entry["description"] as? String ?? "")
            entry["enabled"] = true
        }
    }

    /// Switch a user skill OFF (manual flip or a tripped breaker): disabled,
    /// original description restored.
    func disarm(skillId: String) throws {
        try update(skillId: skillId) { entry in
            entry["description"] = Self.strippedDescription(entry["description"] as? String ?? "")
            entry["enabled"] = false
        }
    }

    /// Truly hide a user skill from Claude: remove its manifest entry and move
    /// its folder into SkillSwitch's own park, out of Cowork's reach. (Cowork
    /// loads every manifest entry into sessions regardless of the `enabled`
    /// flag — verified against session logs — so entry removal is the only real
    /// OFF. But Cowork's sync then garbage-collects any `skills/<id>/` folder
    /// with no matching entry, so leaving the files there loses them — and the
    /// red flip-back-on breaker with them. Parking keeps them safe.) Returns the
    /// removed entry so the caller can remember it for rewiring.
    ///
    /// `keepLive: true` copies to the park instead of moving — for trips, where
    /// the chat that fired the skill may still read its files mid-session.
    /// Cowork's sync reaps the leftover live copy on its own.
    func unwire(skillId: String, keepLive: Bool = false) throws -> [String: Any] {
        var manifest = try readManifest()
        guard var entries = manifest["skills"] as? [[String: Any]] else { throw CoworkError.badManifest }
        guard let index = entries.firstIndex(where: { $0["skillId"] as? String == skillId }) else {
            throw CoworkError.skillMissing(skillId)
        }
        guard (entries[index]["creatorType"] as? String ?? "user") == "user" else {
            throw CoworkError.builtinCollision(skillId)
        }
        var entry = entries.remove(at: index)
        entry["description"] = Self.strippedDescription(entry["description"] as? String ?? "")
        entry["enabled"] = false
        manifest["skills"] = entries
        try write(manifest: manifest)
        // Entry is gone; get the folder to safety before Cowork's sync reclaims it.
        park(skillId: skillId, keepLive: keepLive)
        return entry
    }

    /// Put a previously unwired entry back on the panel (OFF-shaped: the
    /// caller arms or steadies it as a separate step). Restores the parked
    /// folder first so Cowork never sees an entry without its files.
    func rewire(entry: [String: Any]) throws {
        guard let skillId = entry["skillId"] as? String else { throw CoworkError.badManifest }
        unpark(skillId: skillId)
        var manifest = try readManifest()
        guard var entries = manifest["skills"] as? [[String: Any]] else { throw CoworkError.badManifest }
        if let index = entries.firstIndex(where: { $0["skillId"] as? String == skillId }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        manifest["skills"] = entries
        try write(manifest: manifest)
    }

    // MARK: - Parking
    //
    // Cowork garbage-collects any skills/<id>/ folder with no manifest entry, so
    // an OFF (or tripped) skill's files must live outside Cowork's tree or they
    // vanish. We hold them in SkillSwitch's own Application Support folder and
    // move them back when the skill is armed again.

    /// `SKILLSWITCH_PARK_DIR` overrides for tests, keeping them out of the
    /// real Application Support folder.
    static var parkedRoot: URL {
        if let override = ProcessInfo.processInfo.environment["SKILLSWITCH_PARK_DIR"], !override.isEmpty {
            let dir = URL(fileURLWithPath: override, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        let base = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support"))
            .appendingPathComponent("SkillSwitch/parked", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Parked skills are segregated per account so OFF state never crosses
    /// between two Cowork accounts on the same Mac.
    var parkedAccountRoot: URL {
        Self.parkedRoot.appendingPathComponent(accountKey, isDirectory: true)
    }

    func parkedDir(skillId: String) -> URL {
        parkedAccountRoot.appendingPathComponent(skillId, isDirectory: true)
    }

    /// 0.9.4–0.9.5 parked skills flat at parked/<skillId>. Fold those into
    /// this account's namespace — they could only have been parked while it
    /// was the signed-in account. A flat legacy entry is a folder holding a
    /// SKILL.md; account namespaces never do, so detection can't misfire.
    func adoptLegacyPark() {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: Self.parkedRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return }
        for child in children
        where fm.fileExists(atPath: child.appendingPathComponent("SKILL.md").path) {
            let dest = parkedDir(skillId: child.lastPathComponent)
            guard !fm.fileExists(atPath: dest.path) else { continue }
            try? fm.createDirectory(at: parkedAccountRoot, withIntermediateDirectories: true)
            try? fm.moveItem(at: child, to: dest)
        }
    }

    /// True when a parked copy with real skill files exists.
    func hasParked(skillId: String) -> Bool {
        FileManager.default.fileExists(
            atPath: parkedDir(skillId: skillId).appendingPathComponent("SKILL.md").path)
    }

    /// Move an OFF skill's folder out of Cowork's skills dir into the park.
    /// Best-effort: if Cowork already reclaimed it, there's nothing to save.
    /// `keepLive` copies instead, leaving the live folder for a chat that's
    /// still using it; Cowork's sync deletes that leftover, not us.
    func park(skillId: String, keepLive: Bool = false) {
        let fm = FileManager.default
        let live = skillsDir.appendingPathComponent(skillId, isDirectory: true)
        guard fm.fileExists(atPath: live.path) else { return }
        let parked = parkedDir(skillId: skillId)
        try? fm.createDirectory(at: parkedAccountRoot, withIntermediateDirectories: true)
        try? fm.removeItem(at: parked)          // clear any stale parked copy
        if keepLive {
            try? fm.copyItem(at: live, to: parked)
        } else {
            try? fm.moveItem(at: live, to: parked)
        }
    }

    /// Move a parked skill's folder back into Cowork's skills dir. No-op if
    /// nothing is parked; if a live copy already exists, drop the parked dupe.
    func unpark(skillId: String) {
        let fm = FileManager.default
        let parked = parkedDir(skillId: skillId)
        guard fm.fileExists(atPath: parked.path) else { return }
        let live = skillsDir.appendingPathComponent(skillId, isDirectory: true)
        if fm.fileExists(atPath: live.path) {
            try? fm.removeItem(at: parked)
        } else {
            try? fm.createDirectory(at: skillsDir, withIntermediateDirectories: true)
            try? fm.moveItem(at: parked, to: live)
        }
    }

    private func update(skillId: String, _ mutate: (inout [String: Any]) -> Void) throws {
        var manifest = try readManifest()
        guard var entries = manifest["skills"] as? [[String: Any]] else { throw CoworkError.badManifest }
        guard let index = entries.firstIndex(where: { $0["skillId"] as? String == skillId }) else {
            throw CoworkError.skillMissing(skillId)
        }
        mutate(&entries[index])
        entries[index]["updatedAt"] = Self.timestamp()
        manifest["skills"] = entries
        try write(manifest: manifest)
    }

    /// Add (or refresh) a user skill entry. The skill's files must already be
    /// in `skills/<skillId>/`.
    func register(skillId: String, name: String, description: String, enabled: Bool = true) throws {
        var manifest = try readManifest()
        guard var entries = manifest["skills"] as? [[String: Any]] else { throw CoworkError.badManifest }

        let index = entries.firstIndex { $0["skillId"] as? String == skillId }
        if let index, (entries[index]["creatorType"] as? String ?? "user") != "user" {
            throw CoworkError.builtinCollision(skillId)
        }

        var entry = index.map { entries[$0] } ?? [:]
        entry["skillId"] = skillId
        entry["name"] = name
        entry["description"] = description
        entry["creatorType"] = "user"
        entry["syncManaged"] = false
        entry["enabled"] = enabled
        entry["updatedAt"] = Self.timestamp()

        if let index { entries[index] = entry } else { entries.append(entry) }
        manifest["skills"] = entries
        try write(manifest: manifest)
    }

    /// Remove a user skill: drop its manifest entry and move its folder to
    /// the Trash (recoverable, never a hard delete). Built-ins are refused.
    func remove(skillId: String) throws {
        var manifest = try readManifest()
        guard var entries = manifest["skills"] as? [[String: Any]] else { throw CoworkError.badManifest }
        guard let index = entries.firstIndex(where: { $0["skillId"] as? String == skillId }) else {
            throw CoworkError.skillMissing(skillId)
        }
        guard (entries[index]["creatorType"] as? String ?? "user") == "user" else {
            throw CoworkError.builtinCollision(skillId)
        }
        entries.remove(at: index)
        manifest["skills"] = entries
        try write(manifest: manifest)

        let folder = skillsDir.appendingPathComponent(skillId, isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.trashItem(at: folder, resultingItemURL: nil)
        }
    }

    /// Copy a skill folder from outside Cowork (e.g. Claude Code's
    /// ~/.claude/skills) into `skills/<skillId>/` and register it, OFF.
    /// Dotfiles and .git trees stay behind; the same size caps as the
    /// downloader apply so a stray symlink can't vacuum a home directory in.
    func importFolder(at sourceDir: URL, skillId: String) throws {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent("skillswitch-import-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: staging) }

        var fileCount = 0
        var totalBytes = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        // Resolve /var vs /private/var style symlinks up front so relative
        // paths computed against the base always line up.
        let base = sourceDir.resolvingSymlinksInPath()
        guard let enumerator = fm.enumerator(at: base, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
            throw CoworkError.badManifest
        }
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: keys)
            if values?.isSymbolicLink == true { continue }
            guard values?.isRegularFile == true else { continue }
            fileCount += 1
            totalBytes += values?.fileSize ?? 0
            guard fileCount <= 500, totalBytes <= 100_000_000 else { throw CoworkError.badManifest }

            let subpath = url.resolvingSymlinksInPath().path
                .dropFirst(base.path.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let dest = staging.appendingPathComponent(subpath)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: url, to: dest)
        }

        let meta = Frontmatter.parse(
            (try? String(contentsOf: staging.appendingPathComponent("SKILL.md"), encoding: .utf8)) ?? ""
        )
        let destRoot = skillsDir.appendingPathComponent(skillId, isDirectory: true)
        try fm.createDirectory(at: skillsDir, withIntermediateDirectories: true)
        let backup = skillsDir.appendingPathComponent(".replacing-\(skillId)-\(UUID().uuidString)")
        let hadPrevious = fm.fileExists(atPath: destRoot.path)
        if hadPrevious { try fm.moveItem(at: destRoot, to: backup) }
        do {
            try fm.moveItem(at: staging, to: destRoot)
        } catch {
            if hadPrevious { try? fm.moveItem(at: backup, to: destRoot) }
            throw error
        }
        if hadPrevious { try? fm.removeItem(at: backup) }

        try register(
            skillId: skillId,
            name: meta["name"] ?? skillId,
            description: Self.strippedDescription(meta["description"] ?? ""),
            enabled: false
        )
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
