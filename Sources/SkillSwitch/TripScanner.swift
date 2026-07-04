import Foundation

/// Watches Cowork's per-session audit logs (`local_*/audit.jsonl`) for
/// evidence that an armed skill actually fired, so the panel can trip its
/// breaker. Each call reads only the bytes appended since the previous one.
struct TripScanner {
    let sessionsRoot: URL
    private var offsets: [String: UInt64] = [:]

    init(sessionsRoot: URL) {
        self.sessionsRoot = sessionsRoot
    }

    /// An invocation is a `Skill` tool_use whose input names this skill
    /// (bare or plugin-namespaced), or the user typing its slash command.
    /// The line is parsed as JSON rather than substring-matched — chat text
    /// can quote a skill's name right next to an unrelated tool call, and
    /// that must not trip the breaker.
    static func lineInvokes(_ line: String, skillId: String) -> Bool {
        guard line.contains(skillId),
              let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = object["message"] as? [String: Any] else { return false }

        let isUserMessage = object["type"] as? String == "user"
        let escaped = NSRegularExpression.escapedPattern(for: skillId)
        let commandTag = "<command-name>/([A-Za-z0-9._-]+:)?\(escaped)</command-name>"

        if isUserMessage, let text = message["content"] as? String,
           text.range(of: commandTag, options: .regularExpression) != nil {
            return true
        }
        guard let content = message["content"] as? [[String: Any]] else { return false }
        for block in content {
            if block["type"] as? String == "tool_use",
               block["name"] as? String == "Skill",
               let skill = (block["input"] as? [String: Any])?["skill"] as? String,
               skill == skillId || skill.hasSuffix(":" + skillId) {
                return true
            }
            if isUserMessage, block["type"] as? String == "text",
               let text = block["text"] as? String,
               text.range(of: commandTag, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    static func timestamp(of line: String) -> Date? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stamp = object["_audit_timestamp"] as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: stamp) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: stamp)
    }

    /// Which of the armed skills (skillId → armed date) have fired since they
    /// were armed?
    mutating func firedSkills(_ armed: [String: Date]) -> Set<String> {
        guard !armed.isEmpty, let oldestArm = armed.values.min() else { return [] }
        let fm = FileManager.default
        guard let sessions = try? fm.contentsOfDirectory(
            at: sessionsRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }

        var fired: Set<String> = []
        for session in sessions where session.lastPathComponent.hasPrefix("local_") {
            let audit = session.appendingPathComponent("audit.jsonl")
            guard let attributes = try? fm.attributesOfItem(atPath: audit.path),
                  let modified = attributes[.modificationDate] as? Date,
                  modified > oldestArm else { continue }

            for line in consumeNewLines(of: audit) {
                for (skillId, armedAt) in armed where !fired.contains(skillId) {
                    if Self.lineInvokes(line, skillId: skillId),
                       let stamp = Self.timestamp(of: line), stamp > armedAt {
                        fired.insert(skillId)
                    }
                }
            }
        }
        return fired
    }

    /// Complete lines appended since the last call. The offset only advances
    /// past the final newline, so a line Cowork is mid-append on is retried
    /// next poll instead of being half-read.
    private mutating func consumeNewLines(of audit: URL) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: audit) else { return [] }
        defer { try? handle.close() }

        let start = offsets[audit.path] ?? 0
        guard let end = try? handle.seekToEnd(), end > start else { return [] }
        try? handle.seek(toOffset: start)
        guard let data = try? handle.read(upToCount: Int(end - start)),
              let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return [] }

        offsets[audit.path] = start + UInt64(lastNewline + 1)
        guard let text = String(data: data.prefix(through: lastNewline), encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }
}
