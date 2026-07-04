import Foundation

struct Skill: Identifiable, Hashable {
    enum Source: Hashable {
        case user              // added by the user — toggleable
        case builtin(String)   // ships with Cowork (creatorType) — hardwired
    }

    let skillId: String        // manifest key; also the folder name under skills/
    let name: String
    let description: String
    let directory: URL
    let source: Source
    let enabled: Bool
    let armedAt: Date?         // when the circuit was flipped on (entry updatedAt)

    /// A circuit that's ON is armed: it fires once in the next chat, then trips.
    var isArmed: Bool { enabled && !isHardwired }

    var id: String { skillId }
    var invocation: String { "/\(name)" }

    /// Cowork rejects toggling its built-in skills, so their breaker is sealed.
    var isHardwired: Bool {
        if case .builtin = source { return true }
        return false
    }

    var displayName: String {
        name.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }

    var sourceLabel: String {
        switch source {
        case .user: return "Personal"
        case .builtin(let creator): return creator == "anthropic" ? "Built into Claude" : creator
        }
    }
}

/// Minimal YAML-frontmatter reader: enough for SKILL.md files (flat key: value
/// pairs, quoted values, block scalars, and indented continuation lines).
enum Frontmatter {
    static func parse(_ text: String) -> [String: String] {
        var lines = text.components(separatedBy: .newlines)
        guard let first = lines.first,
              first.trimmingCharacters(in: .whitespaces) == "---" else { return [:] }
        lines.removeFirst()

        var result: [String: String] = [:]
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }
            if trimmed.isEmpty || line.hasPrefix("#") { i += 1; continue }
            guard !line.hasPrefix(" "), !line.hasPrefix("\t"),
                  let colon = line.firstIndex(of: ":") else { i += 1; continue }

            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            i += 1

            if ["|", "|-", ">", ">-"].contains(value) {
                var parts: [String] = []
                while i < lines.count {
                    let next = lines[i]
                    let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
                    if nextTrimmed == "---" { break }
                    if !next.hasPrefix(" ") && !next.hasPrefix("\t") && !nextTrimmed.isEmpty { break }
                    if !nextTrimmed.isEmpty { parts.append(nextTrimmed) }
                    i += 1
                }
                value = parts.joined(separator: " ")
            } else {
                while i < lines.count, lines[i].hasPrefix(" ") || lines[i].hasPrefix("\t") {
                    let continuation = lines[i].trimmingCharacters(in: .whitespaces)
                    if continuation == "---" { break }
                    if !continuation.isEmpty { value += " " + continuation }
                    i += 1
                }
                if value.count >= 2,
                   (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
            }

            result[key] = value
        }
        return result
    }
}
