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

    /// The one packaged starter, offered from the empty state.
    static let packagedSparringPartner = Persona(
        id: UUID(uuidString: "5B32B1D6-9C1E-4E60-8A31-6A2D2D9A0001")!,
        name: "SPARRING PARTNER",
        blurb: "Relentless questions, structured brainstorms, real plans.",
        members: [
            Member(skillId: "grill-me", source: "mattpocock/skills"),
            Member(skillId: "brainstorming", source: "obra/superpowers"),
            Member(skillId: "writing-plans", source: "obra/superpowers"),
        ]
    )
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
