import Foundation

/// One declared environment variable from a SKILL.md `env:` frontmatter
/// block — the convention documented in SKILL-ENV.md.
struct EnvRequirement: Hashable {
    enum Require: Hashable {
        case always
        case optional
        case oneOf(String)   // group label; ≥1 member of each group must be set
    }

    let name: String
    let require: Require
    let purpose: String?
    let url: String?
}

enum EnvSpec {
    /// Parses the `env:` list out of a SKILL.md's frontmatter. Tolerant of
    /// the YAML subset people actually write: a top-level `env:` key whose
    /// items are `- name: X` entries with indented `key: value` lines.
    static func parse(_ skillMD: String) -> [EnvRequirement] {
        let lines = skillMD.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return [] }

        var requirements: [EnvRequirement] = []
        var inFrontmatter = true
        var inEnv = false
        var current: [String: String] = [:]

        func flush() {
            guard let name = current["name"], !name.isEmpty else { current = [:]; return }
            let require: EnvRequirement.Require
            switch current["require"]?.lowercased() {
            case "always", "required", "must":
                require = .always
            case let raw? where raw.hasPrefix("one-of"):
                let group = raw.dropFirst("one-of".count).trimmingCharacters(in: .whitespaces)
                require = .oneOf(group.isEmpty ? "default" : group)
            default:
                require = .optional
            }
            requirements.append(EnvRequirement(
                name: name, require: require,
                purpose: current["purpose"], url: current["url"]
            ))
            current = [:]
        }

        for line in lines.dropFirst() {
            guard inFrontmatter else { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { inFrontmatter = false; break }

            if !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                // New top-level key: env block ends (flushing any open entry).
                if inEnv { flush() }
                inEnv = trimmed == "env:" || trimmed.hasPrefix("env:")
                continue
            }
            guard inEnv, !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            var body = trimmed
            if body.hasPrefix("- ") {
                flush()
                body = String(body.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
            guard let colon = body.firstIndex(of: ":") else { continue }
            let key = String(body[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            var value = String(body[body.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
               (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            current[key] = value
        }
        if inEnv { flush() }
        return requirements
    }

    /// Is the skill's declared environment satisfied by the given set of
    /// defined variable names? (`always` all present; each one-of group has
    /// at least one member present; optional never blocks.)
    static func satisfied(_ requirements: [EnvRequirement], by defined: Set<String>) -> Bool {
        var groups: [String: Bool] = [:]
        for requirement in requirements {
            switch requirement.require {
            case .always:
                if !defined.contains(requirement.name) { return false }
            case .oneOf(let group):
                groups[group] = (groups[group] ?? false) || defined.contains(requirement.name)
            case .optional:
                break
            }
        }
        return groups.values.allSatisfy { $0 }
    }
}
