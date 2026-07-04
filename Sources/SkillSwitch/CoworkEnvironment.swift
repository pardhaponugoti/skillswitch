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
        guard let orgs = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return nil }

        var best: (dir: URL, modified: Date)?
        for org in orgs {
            guard let accounts = try? fm.contentsOfDirectory(
                at: org, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            for account in accounts {
                let manifest = account.appendingPathComponent("manifest.json")
                guard let attributes = try? fm.attributesOfItem(atPath: manifest.path),
                      let modified = attributes[.modificationDate] as? Date else { continue }
                if best == nil || modified > best!.modified {
                    best = (account, modified)
                }
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

    static func strippedDescription(_ description: String) -> String {
        description.hasPrefix(armPrefix) ? String(description.dropFirst(armPrefix.count)) : description
    }

    /// Switch a user skill ON as a one-shot: enabled, with the fire-now prefix.
    func arm(skillId: String) throws {
        try update(skillId: skillId) { entry in
            let description = entry["description"] as? String ?? ""
            if !description.hasPrefix(Self.armPrefix) {
                entry["description"] = Self.armPrefix + description
            }
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
    func register(skillId: String, name: String, description: String) throws {
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
        entry["enabled"] = true
        entry["updatedAt"] = Self.timestamp()

        if let index { entries[index] = entry } else { entries.append(entry) }
        manifest["skills"] = entries
        try write(manifest: manifest)
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
