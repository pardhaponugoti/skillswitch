import Foundation

/// Remembers which GitHub repo each installed skill came from, so the gear
/// menu can update it later. Installs record here; skills that arrived by
/// other roads are looked up on demand (shelf match, then the SKILL.md
/// frontmatter's repository/homepage URL).
enum SourceBook {
    private static let key = "skillSources"

    static func source(for skillId: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String])?[skillId]
    }

    static func record(_ source: String, for skillId: String) {
        var book = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        book[skillId] = source
        UserDefaults.standard.set(book, forKey: key)
    }

    static func forget(_ skillId: String) {
        var book = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        book.removeValue(forKey: skillId)
        UserDefaults.standard.set(book, forKey: key)
    }

    /// Pull "owner/repo" out of a SKILL.md whose frontmatter names its home
    /// (`repository:` or `homepage:` pointing at github.com).
    static func fromFrontmatter(directory: URL) -> String? {
        guard let text = try? String(contentsOf: directory.appendingPathComponent("SKILL.md"), encoding: .utf8) else {
            return nil
        }
        let meta = Frontmatter.parse(text)
        for field in [meta["repository"], meta["homepage"]] {
            guard let url = field,
                  let range = url.range(of: #"github\.com/([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)"#, options: .regularExpression) else { continue }
            let path = String(url[range]).replacingOccurrences(of: "github.com/", with: "")
            return path.hasSuffix(".git") ? String(path.dropLast(4)) : path
        }
        return nil
    }
}
