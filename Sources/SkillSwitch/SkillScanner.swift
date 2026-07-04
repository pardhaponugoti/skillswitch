import Foundation

enum SkillScanner {
    /// Reads the board straight from Cowork's manifest. Returns nil when no
    /// Claude desktop install (with Cowork's skills plugin) can be found, so
    /// the panel can show a friendly "no fuse box here" state.
    static func scan() -> [Skill]? {
        guard let env = CoworkEnvironment.locate(),
              let entries = try? env.readSkillEntries() else { return nil }

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
                armed: rawDescription.hasPrefix(CoworkEnvironment.armPrefix),
                armedAt: updatedAt
            )
        }
        // Skills the user switched OFF are absent from the manifest (the only
        // off Cowork honors) — resurrect them as red breakers from the OffBook
        // as long as their files are still there.
        let manifestIds = Set(skills.map { $0.skillId.lowercased() })
        let ghosts = OffBook.skillIds
            .filter { !manifestIds.contains($0.lowercased()) }
            .compactMap { skillId -> Skill? in
                let dir = env.skillsDir.appendingPathComponent(skillId, isDirectory: true)
                guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("SKILL.md").path) else {
                    OffBook.forget(skillId)   // files gone — nothing to flip back on
                    return nil
                }
                let entry = OffBook.entry(for: skillId) ?? [:]
                return Skill(
                    skillId: skillId,
                    name: entry["name"] as? String ?? skillId,
                    description: CoworkEnvironment.strippedDescription(entry["description"] as? String ?? ""),
                    directory: dir,
                    source: .user,
                    enabled: false,
                    armed: false,
                    armedAt: nil
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
            if let remembered = OffBook.entry(for: skill.skillId), (try env.entry(skillId: skill.skillId)) == nil {
                try env.rewire(entry: remembered)
                OffBook.forget(skill.skillId)
            }
            try env.arm(skillId: skill.skillId)
        } else {
            let removed = try env.unwire(skillId: skill.skillId)
            OffBook.record(removed, for: skill.skillId)
        }
    }
}
