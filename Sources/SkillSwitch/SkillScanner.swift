import Foundation

enum SkillScanner {
    /// Reads the board straight from Cowork's manifest. Returns nil when no
    /// Claude desktop install (with Cowork's skills plugin) can be found, so
    /// the panel can show a friendly "no fuse box here" state.
    static func scan() -> [Skill]? {
        guard let env = CoworkEnvironment.locate(),
              let entries = try? env.readSkillEntries() else { return nil }

        // Fold pre-0.9.6 global OFF state into this account's namespace once.
        OffBook.adoptLegacy(into: env.accountKey)
        env.adoptLegacyPark()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let skills = entries.compactMap { entry -> Skill? in
            guard let skillId = entry["skillId"] as? String else { return nil }
            let creator = entry["creatorType"] as? String ?? "user"
            let updatedAt = (entry["updatedAt"] as? String).flatMap { formatter.date(from: $0) }
            let rawDescription = entry["description"] as? String ?? ""
            return Skill(
                skillId: skillId,
                name: entry["name"] as? String ?? skillId,
                description: CoworkEnvironment.strippedDescription(rawDescription),
                directory: env.skillsDir.appendingPathComponent(skillId, isDirectory: true),
                source: creator == "user" ? .user : .builtin(creator),
                // Cowork loads every manifest entry regardless of the stored
                // enabled flag, so entry-present IS on. Red only ever means
                // "no entry" (the OffBook ghosts below).
                enabled: true,
                armed: CoworkEnvironment.isArmedDescription(rawDescription),
                armedAt: updatedAt,
                manualOnly: creator == "user" && env.isManualOnly(skillId: skillId)
            )
        }
        // Skills the user switched OFF are absent from the manifest (the only
        // off Cowork honors) — resurrect them as red breakers from the OffBook.
        // Their files live in SkillSwitch's park (moved there on OFF so Cowork's
        // sync can't reclaim them). A live folder with no parked copy is a
        // skill that went OFF before parking existed — rescue it now, before
        // Cowork's sync gets to it.
        let manifestIds = Set(skills.map { $0.skillId.lowercased() })
        let ghosts = OffBook.skillIds(account: env.accountKey)
            .filter { !manifestIds.contains($0.lowercased()) }
            .compactMap { skillId -> Skill? in
                let live = env.skillsDir.appendingPathComponent(skillId, isDirectory: true)
                let dir: URL
                if env.hasParked(skillId: skillId) {
                    dir = env.parkedDir(skillId: skillId)
                } else if FileManager.default.fileExists(atPath: live.appendingPathComponent("SKILL.md").path) {
                    env.park(skillId: skillId)
                    dir = env.hasParked(skillId: skillId) ? env.parkedDir(skillId: skillId) : live
                } else {
                    OffBook.forget(skillId, account: env.accountKey)   // files truly gone — nothing to flip back on
                    return nil
                }
                let entry = OffBook.entry(for: skillId, account: env.accountKey) ?? [:]
                return Skill(
                    skillId: skillId,
                    name: entry["name"] as? String ?? skillId,
                    description: CoworkEnvironment.strippedDescription(entry["description"] as? String ?? ""),
                    directory: dir,
                    source: .user,
                    enabled: false,
                    armed: false,
                    armedAt: nil,
                    manualOnly: env.isManualOnly(skillId: skillId)
                )
            }

        return (skills + ghosts).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Folders sitting inside Cowork's skills dir with no manifest entry —
    /// dropped there by hand or by another tool. Cowork can't see them until
    /// they're wired in.
    static func scanOrphans(env: CoworkEnvironment, manifestIds: Set<String>) -> [ExternalSkill] {
        externalSkills(in: env.skillsDir, excluding: manifestIds, builtinIds: [])
    }

    /// Skills living in Claude Code's personal folder (~/.claude/skills) —
    /// a different product's skills, importable into Cowork with one click.
    static func scanClaudeCode(manifestUserIds: Set<String>, builtinIds: Set<String>) -> [ExternalSkill] {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/skills", isDirectory: true)
        return externalSkills(in: root, excluding: manifestUserIds, builtinIds: builtinIds)
    }

    private static func externalSkills(in root: URL, excluding: Set<String>, builtinIds: Set<String>) -> [ExternalSkill] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        // Case-insensitive comparisons: APFS is case-insensitive by default.
        let taken = Set(excluding.map { $0.lowercased() })
        let builtins = Set(builtinIds.map { $0.lowercased() })

        return entries.compactMap { dir -> ExternalSkill? in
            let skillId = dir.lastPathComponent
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                  !taken.contains(skillId.lowercased()),
                  let text = try? String(contentsOf: dir.appendingPathComponent("SKILL.md"), encoding: .utf8) else {
                return nil
            }
            let meta = Frontmatter.parse(text)
            return ExternalSkill(
                skillId: skillId,
                name: meta["name"] ?? skillId,
                description: CoworkEnvironment.strippedDescription(meta["description"] ?? ""),
                directory: dir,
                status: builtins.contains(skillId.lowercased()) ? .nameTaken : .importable
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

enum SkillToggler {
    enum ToggleError: LocalizedError {
        case hardwired

        var errorDescription: String? {
            switch self {
            case .hardwired:
                return "This skill is built into Claude — it's always on."
            }
        }
    }

    /// ON arms the skill (one-shot: fires next chat, then trips); OFF
    /// unwires it — the manifest entry is removed and remembered, because
    /// Cowork loads every entry regardless of the `enabled` flag.
    static func setEnabled(_ skill: Skill, _ enabled: Bool) throws {
        guard !skill.isHardwired else { throw ToggleError.hardwired }
        guard skill.enabled != enabled else { return }
        guard let env = CoworkEnvironment.locate() else { throw CoworkError.notFound }
        if enabled {
            if let remembered = OffBook.entry(for: skill.skillId, account: env.accountKey),
               (try env.entry(skillId: skill.skillId)) == nil {
                try env.rewire(entry: remembered)
                OffBook.forget(skill.skillId, account: env.accountKey)
            }
            try env.arm(skillId: skill.skillId)
        } else {
            let removed = try env.unwire(skillId: skill.skillId)
            OffBook.record(removed, for: skill.skillId, account: env.accountKey)
        }
    }
}
