import Foundation

/// A persona is a labeled zone of the panel: a curated set of skills that get
/// wired in together and switched steadily ON (green — available every chat,
/// no force-fire, no tripping). Skills are real entries from the skills.sh
/// leaderboard, pinned to their sources.
struct Persona: Identifiable, Hashable {
    struct Member: Hashable {
        let skillId: String
        let source: String   // GitHub owner/repo
    }

    let id: String
    let name: String
    let blurb: String
    let members: [Member]

    static let curated: [Persona] = [
        Persona(
            id: "marketer",
            name: "MARKETER",
            blurb: "Copy, content strategy, SEO, and the psychology behind all three.",
            members: [
                Member(skillId: "copywriting", source: "coreyhaines31/marketingskills"),
                Member(skillId: "content-strategy", source: "coreyhaines31/marketingskills"),
                Member(skillId: "seo-audit", source: "coreyhaines31/marketingskills"),
                Member(skillId: "marketing-psychology", source: "coreyhaines31/marketingskills"),
            ]
        ),
        Persona(
            id: "sparring-partner",
            name: "SPARRING PARTNER",
            blurb: "Gets grilled into you: relentless questions, structured brainstorms, real plans.",
            members: [
                Member(skillId: "grill-me", source: "mattpocock/skills"),
                Member(skillId: "brainstorming", source: "obra/superpowers"),
                Member(skillId: "writing-plans", source: "obra/superpowers"),
            ]
        ),
    ]
}
