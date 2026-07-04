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
            return Skill(
                skillId: skillId,
                name: entry["name"] as? String ?? skillId,
                description: CoworkEnvironment.strippedDescription(entry["description"] as? String ?? ""),
                directory: env.skillsDir.appendingPathComponent(skillId, isDirectory: true),
                source: creator == "user" ? .user : .builtin(creator),
                enabled: entry["enabled"] as? Bool ?? true,
                armedAt: updatedAt
            )
        }
        return skills.sorted {
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

    /// ON arms the skill (one-shot: fires next chat, then trips); OFF disarms.
    static func setEnabled(_ skill: Skill, _ enabled: Bool) throws {
        guard !skill.isHardwired else { throw ToggleError.hardwired }
        guard skill.enabled != enabled else { return }
        guard let env = CoworkEnvironment.locate() else { throw CoworkError.notFound }
        if enabled {
            try env.arm(skillId: skill.skillId)
        } else {
            try env.disarm(skillId: skill.skillId)
        }
    }
}
