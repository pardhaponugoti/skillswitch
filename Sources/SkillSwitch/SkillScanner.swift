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
