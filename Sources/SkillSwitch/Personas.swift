import Foundation

/// A persona is a set of skills you switch on together — a whole toolkit,
/// one flip. Energized members are held steadily ON (green: available every
/// chat, no force-fire, no tripping). Personas belong to the user and live
/// in SkillSwitch's own storage, never in Cowork's manifest.
struct Persona: Identifiable, Hashable, Codable {
    struct Member: Hashable, Codable {
        let skillId: String
        /// GitHub owner/repo when known — lets ENERGIZE reinstall a member
        /// that's gone missing. nil for purely local skills.
        var source: String?
    }

    let id: UUID
    var name: String
    var blurb: String
    var members: [Member]

    /// Prebuilt bundles offered on the Personas tab. Every member is a real
    /// skills.sh leaderboard entry (≥50k installs), pinned to its source.
    static let starters: [Persona] = [
        Persona(
            id: UUID(uuidString: "5B32B1D6-9C1E-4E60-8A31-6A2D2D9A0001")!,
            name: "SPARRING PARTNER",
            blurb: "Claude pushes back: relentless questions, structured brainstorms, plans that survive contact.",
            members: [
                Member(skillId: "grill-me", source: "mattpocock/skills"),
                Member(skillId: "brainstorming", source: "obra/superpowers"),
                Member(skillId: "writing-plans", source: "obra/superpowers"),
                Member(skillId: "executing-plans", source: "obra/superpowers"),
            ]
        ),
        Persona(
            id: UUID(uuidString: "5B32B1D6-9C1E-4E60-8A31-6A2D2D9A0002")!,
            name: "MARKETER",
            blurb: "Positioning, copy, SEO, and the psychology that makes it convert.",
            members: [
                Member(skillId: "copywriting", source: "coreyhaines31/marketingskills"),
                Member(skillId: "content-strategy", source: "coreyhaines31/marketingskills"),
                Member(skillId: "seo-audit", source: "coreyhaines31/marketingskills"),
                Member(skillId: "marketing-psychology", source: "coreyhaines31/marketingskills"),
                Member(skillId: "social-content", source: "coreyhaines31/marketingskills"),
            ]
        ),
        Persona(
            id: UUID(uuidString: "5B32B1D6-9C1E-4E60-8A31-6A2D2D9A0003")!,
            name: "DESIGNER",
            blurb: "Design foundations and taste, plus a critic that polishes until it's right.",
            members: [
                Member(skillId: "frontend-design", source: "anthropics/skills"),
                Member(skillId: "web-design-guidelines", source: "vercel-labs/agent-skills"),
                Member(skillId: "critique", source: "pbakaus/impeccable"),
                Member(skillId: "polish", source: "pbakaus/impeccable"),
            ]
        ),
        Persona(
            id: UUID(uuidString: "5B32B1D6-9C1E-4E60-8A31-6A2D2D9A0004")!,
            name: "EDITOR",
            blurb: "Sharpens anything you write: structure, rhythm, and a ruthless copy edit.",
            members: [
                Member(skillId: "edit-article", source: "mattpocock/skills"),
                Member(skillId: "writing-shape", source: "mattpocock/skills"),
                Member(skillId: "copy-editing", source: "coreyhaines31/marketingskills"),
                Member(skillId: "doc-coauthoring", source: "anthropics/skills"),
            ]
        ),
        Persona(
            id: UUID(uuidString: "5B32B1D6-9C1E-4E60-8A31-6A2D2D9A0005")!,
            name: "CONTENT CREATOR",
            blurb: "Hooks, captions, and short-form ideas that actually travel.",
            members: [
                Member(skillId: "viral-short-form-ideas", source: "vyralcontent/content-skills"),
                Member(skillId: "viral-hooks", source: "vyralcontent/content-skills"),
                Member(skillId: "viral-captions-and-ctas", source: "vyralcontent/content-skills"),
                Member(skillId: "viral-short-form", source: "vyralcontent/content-skills"),
            ]
        ),
        Persona(
            id: UUID(uuidString: "5B32B1D6-9C1E-4E60-8A31-6A2D2D9A0006")!,
            name: "SENIOR ENGINEER",
            blurb: "TDD, systematic debugging, and architecture review — an old head on young code.",
            members: [
                Member(skillId: "tdd", source: "mattpocock/skills"),
                Member(skillId: "systematic-debugging", source: "obra/superpowers"),
                Member(skillId: "improve-codebase-architecture", source: "mattpocock/skills"),
                Member(skillId: "review", source: "mattpocock/skills"),
            ]
        ),
    ]
}

/// Persistence for user personas (UserDefaults-backed JSON).
enum PersonaBook {
    private static let key = "personas"

    static func load() -> [Persona] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let personas = try? JSONDecoder().decode([Persona].self, from: data) else { return [] }
        return personas
    }

    static func save(_ personas: [Persona]) {
        if let data = try? JSONEncoder().encode(personas) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
