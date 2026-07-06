import Foundation

struct DiscoverySkill: Identifiable, Hashable {
    let source: String    // GitHub "owner/repo"
    let skillId: String
    let installs: Int
    let isOfficial: Bool

    var id: String { "\(source)/\(skillId)" }
    var owner: String { String(source.split(separator: "/").first ?? "") }

    var displayName: String {
        skillId.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }

    var installsLabel: String {
        switch installs {
        case 1_000_000...: return String(format: "%.1fM", Double(installs) / 1_000_000)
        case 1_000...: return "\(installs / 1_000)K"
        default: return "\(installs)"
        }
    }

    var pageURL: URL? {
        URL(string: "https://www.skills.sh/\(source)/\(skillId)")
    }
}

enum DiscoveryError: LocalizedError {
    case badResponse
    case skillNotFound(String)
    case unsafeContents(String)
    case tooLarge(String)

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "Unexpected response from the network."
        case .skillNotFound(let name):
            return "Couldn't locate “\(name)” inside its repository."
        case .unsafeContents(let name):
            return "“\(name)” contains files with unsafe paths — install refused."
        case .tooLarge(let name):
            return "“\(name)” is unreasonably large — install refused."
        }
    }
}

/// Shelf filter by who published the skill. `org` = the GitHub owner is an
/// organization account or skills.sh marks the entry vendor-official;
/// unresolved owners count as `user` so nothing hides on a guess.
enum AuthorShelf: String {
    case all, user, org
}

@MainActor
final class DiscoveryStore: ObservableObject {
    /// Only surface widely-used skills to keep the shelf trustworthy.
    nonisolated static let minInstalls = 50_000

    @Published private(set) var skills: [DiscoverySkill] = []
    @Published private(set) var isLoading = false
    @Published private(set) var installing: Set<String> = []
    @Published private(set) var installedNames: Set<String> = []
    @Published private(set) var descriptions: [String: String] = [:]  // skill.id → description
    @Published private(set) var fetchingDescriptions: Set<String> = []
    @Published var errorMessage: String?
    @Published var query = ""
    @Published var shelf: AuthorShelf {
        didSet { UserDefaults.standard.set(shelf.rawValue, forKey: "authorShelf") }
    }

    private let ownerDirectory = OwnerDirectory()

    init() {
        shelf = AuthorShelf(rawValue: UserDefaults.standard.string(forKey: "authorShelf") ?? "") ?? .user
        ownerDirectory.onChange = { [weak self] in self?.objectWillChange.send() }
    }

    /// Called after a successful install so the panel can rescan.
    var onInstall: ((String) -> Void)?

    private struct Entry: Decodable {
        let source: String
        let skillId: String
        let installs: Int
        let isOfficial: Bool?
    }

    private struct LinkedData: Decodable {
        let type: String?
        let description: String?

        enum CodingKeys: String, CodingKey {
            case type = "@type"
            case description
        }
    }

    private struct TreeResponse: Decodable {
        struct Item: Decodable {
            let path: String
            let type: String
        }
        let tree: [Item]
    }

    func isOrg(_ skill: DiscoverySkill) -> Bool {
        skill.isOfficial || ownerDirectory.kind(of: skill.owner) == .organization
    }

    var orgCount: Int { skills.filter(isOrg).count }

    var filtered: [DiscoverySkill] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        // A live search overrides the shelf — searching "azure" from the USER
        // shelf and finding nothing would read as a bug.
        guard q.isEmpty else {
            return skills.filter {
                $0.skillId.lowercased().contains(q)
                    || $0.displayName.lowercased().contains(q)
                    || $0.source.lowercased().contains(q)
            }
        }
        switch shelf {
        case .all: return skills
        case .user: return skills.filter { !isOrg($0) }
        case .org: return skills.filter(isOrg)
        }
    }

    func refreshInstalled() {
        guard let env = CoworkEnvironment.locate() else {
            installedNames = []
            return
        }
        let fm = FileManager.default
        // OFF skills are parked outside Cowork's tree — still installed.
        let names = ((try? fm.contentsOfDirectory(atPath: env.skillsDir.path)) ?? [])
            + ((try? fm.contentsOfDirectory(atPath: CoworkEnvironment.parkedRoot.path)) ?? [])
        installedNames = Set(names.filter { !$0.hasPrefix(".") })
    }

    func load(force: Bool = false) async {
        guard force || skills.isEmpty, !isLoading else { return }
        if force { skills = [] }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        refreshInstalled()

        do {
            let (data, response) = try await URLSession.shared.data(from: URL(string: "https://www.skills.sh/")!)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else { throw DiscoveryError.badResponse }
            skills = Self.parseLeaderboard(html)
            if skills.isEmpty { errorMessage = "skills.sh returned no skills — its page format may have changed." }
            let owners = skills.map(\.owner)
            Task { await ownerDirectory.resolve(owners) }
        } catch {
            errorMessage = "Couldn't reach skills.sh: \(error.localizedDescription)"
        }
    }

    /// The leaderboard is embedded in the homepage's payload as JSON objects
    /// (quote-escaped). Unescape, pull each {...installs...} object, decode.
    nonisolated static func parseLeaderboard(_ html: String) -> [DiscoverySkill] {
        let unescaped = html.replacingOccurrences(of: "\\\"", with: "\"")
        guard let regex = try? NSRegularExpression(pattern: #"\{[^{}]*?"installs":\d+[^{}]*?\}"#) else { return [] }
        let range = NSRange(unescaped.startIndex..., in: unescaped)
        let decoder = JSONDecoder()

        var best: [String: DiscoverySkill] = [:]  // skillId → highest-install source
        for match in regex.matches(in: unescaped, range: range) {
            guard let r = Range(match.range, in: unescaped),
                  let entry = try? decoder.decode(Entry.self, from: Data(unescaped[r].utf8)) else { continue }
            // Only GitHub owner/repo sources are installable from here.
            guard entry.source.split(separator: "/").count == 2 else { continue }
            guard entry.installs >= minInstalls else { continue }
            let skill = DiscoverySkill(
                source: entry.source,
                skillId: entry.skillId,
                installs: entry.installs,
                isOfficial: entry.isOfficial ?? false
            )
            if let existing = best[entry.skillId], existing.installs >= skill.installs { continue }
            best[entry.skillId] = skill
        }
        return best.values.sorted { $0.installs > $1.installs }
    }

    /// Lazily fetch a skill's description from its skills.sh page the first
    /// time its row is expanded. Failures aren't cached, so re-expanding retries.
    func loadDescription(for skill: DiscoverySkill) async {
        guard descriptions[skill.id] == nil,
              !fetchingDescriptions.contains(skill.id),
              let url = skill.pageURL else { return }
        fetchingDescriptions.insert(skill.id)
        defer { fetchingDescriptions.remove(skill.id) }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else { return }
        descriptions[skill.id] = Self.parseDescription(html) ?? ""
    }

    /// The skill page embeds its full description in a JSON-LD
    /// SoftwareApplication block (the og:description meta is truncated).
    nonisolated static func parseDescription(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"<script type="application/ld\+json">(.*?)</script>"#,
            options: [.dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        let decoder = JSONDecoder()

        for match in regex.matches(in: html, range: range) {
            guard let r = Range(match.range(at: 1), in: html),
                  let entry = try? decoder.decode(LinkedData.self, from: Data(html[r].utf8)),
                  entry.type == "SoftwareApplication",
                  let description = entry.description?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !description.isEmpty else { continue }
            return description
        }
        return nil
    }

    func install(_ skill: DiscoverySkill) async {
        guard !installing.contains(skill.id) else { return }
        installing.insert(skill.id)
        defer { installing.remove(skill.id) }
        errorMessage = nil

        do {
            // Both values come from scraped skills.sh HTML: the skillId becomes
            // a folder name and the source is spliced into GitHub URLs, so hold
            // them to a strict charset instead of trusting the page.
            guard skill.skillId.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil,
                  skill.skillId != ".", skill.skillId != ".." else {
                throw DiscoveryError.skillNotFound(skill.skillId)
            }
            guard skill.source.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil else {
                throw DiscoveryError.skillNotFound(skill.skillId)
            }
            guard let env = CoworkEnvironment.locate() else { throw CoworkError.notFound }
            if let existing = try env.entry(skillId: skill.skillId),
               (existing["creatorType"] as? String ?? "user") != "user" {
                throw CoworkError.builtinCollision(skill.skillId)
            }

            // One tree listing per repo; HEAD resolves the default branch.
            guard let treeURL = URL(string: "https://api.github.com/repos/\(skill.source)/git/trees/HEAD?recursive=1") else {
                throw DiscoveryError.skillNotFound(skill.skillId)
            }
            var request = URLRequest(url: treeURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DiscoveryError.badResponse }
            let tree = try JSONDecoder().decode(TreeResponse.self, from: data).tree

            // The skill's root is the shallowest dir named after it holding a SKILL.md.
            let manifests = tree
                .filter { $0.type == "blob" }
                .filter { $0.path == "SKILL.md" || $0.path.hasSuffix("/SKILL.md") }
                .filter { path -> Bool in
                    let dir = path.path.split(separator: "/").dropLast().last.map(String.init)
                    return dir == skill.skillId || (path.path == "SKILL.md" && skill.source.hasSuffix("/\(skill.skillId)"))
                }
                .sorted { $0.path.count < $1.path.count }
            guard let manifest = manifests.first else { throw DiscoveryError.skillNotFound(skill.skillId) }

            let prefix = manifest.path == "SKILL.md" ? "" : String(manifest.path.dropLast("SKILL.md".count))
            let files = tree.filter { $0.type == "blob" && $0.path.hasPrefix(prefix) }
            guard files.count <= 500 else { throw DiscoveryError.tooLarge(skill.skillId) }

            // Stage the download, then swap it in — a failed fetch must not
            // leave a half-installed skill in Cowork's folder.
            let staging = FileManager.default.temporaryDirectory
                .appendingPathComponent("skillswitch-install-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: staging) }

            var totalBytes = 0
            for file in files {
                let subpath = String(file.path.dropFirst(prefix.count))
                // A hostile repo must not be able to write outside the staging
                // dir — and a skill with any unsafe path doesn't get installed
                // at all, rather than partially.
                guard !subpath.split(separator: "/").contains("..") else {
                    throw DiscoveryError.unsafeContents(skill.skillId)
                }

                let escaped = file.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file.path
                guard let raw = URL(string: "https://raw.githubusercontent.com/\(skill.source)/HEAD/\(escaped)") else { continue }
                let (blob, blobResponse) = try await URLSession.shared.data(from: raw)
                guard (blobResponse as? HTTPURLResponse)?.statusCode == 200 else { throw DiscoveryError.badResponse }
                totalBytes += blob.count
                guard totalBytes <= 100_000_000 else { throw DiscoveryError.tooLarge(skill.skillId) }

                let dest = staging.appendingPathComponent(subpath)
                try FileManager.default.createDirectory(
                    at: dest.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try blob.write(to: dest)
            }

            // Swap the staging dir in, keeping the old install as a backup
            // until the move succeeds — a failed reinstall must not destroy a
            // working skill.
            let destRoot = env.skillsDir.appendingPathComponent(skill.skillId, isDirectory: true)
            try FileManager.default.createDirectory(at: env.skillsDir, withIntermediateDirectories: true)
            let backup = env.skillsDir.appendingPathComponent(".replacing-\(skill.skillId)-\(UUID().uuidString)")
            let hadPrevious = FileManager.default.fileExists(atPath: destRoot.path)
            if hadPrevious {
                try FileManager.default.moveItem(at: destRoot, to: backup)
            }
            do {
                try FileManager.default.moveItem(at: staging, to: destRoot)
            } catch {
                if hadPrevious { try? FileManager.default.moveItem(at: backup, to: destRoot) }
                throw error
            }
            if hadPrevious { try? FileManager.default.removeItem(at: backup) }

            let meta = Frontmatter.parse(
                (try? String(contentsOf: destRoot.appendingPathComponent("SKILL.md"), encoding: .utf8)) ?? ""
            )
            // The description written to Cowork's manifest comes only from the
            // downloaded SKILL.md — never from scraped skills.sh page text,
            // since arming turns the description into an instruction channel.
            try env.register(
                skillId: skill.skillId,
                name: meta["name"] ?? skill.skillId,
                description: meta["description"] ?? ""
            )
            SourceBook.record(skill.source, for: skill.skillId)
            // A fresh install comes up armed: it fires in the next chat, then trips.
            try env.arm(skillId: skill.skillId)

            refreshInstalled()
            onInstall?(skill.skillId)
        } catch {
            errorMessage = "Install failed: \(error.localizedDescription)"
        }
    }

    /// Where an installed skill came from: recorded at install time, else
    /// matched against the shelf, else read from its SKILL.md frontmatter.
    func sourceForInstalled(_ skill: Skill) -> String? {
        SourceBook.source(for: skill.skillId)
            ?? skills.first { $0.skillId == skill.skillId }?.source
            ?? SourceBook.fromFrontmatter(directory: skill.directory)
    }

    func ownerKind(of owner: String) -> OwnerKind? {
        ownerDirectory.kind(of: owner)
    }

    /// Kick off classification for the owners of installed skills that the
    /// seed doesn't cover (e.g. skills imported from outside the shelf).
    func resolveOwners(for installed: [Skill]) {
        let owners = installed.compactMap { skill in
            sourceForInstalled(skill)?.split(separator: "/").first.map(String.init)
        }
        guard !owners.isEmpty else { return }
        Task { await ownerDirectory.resolve(owners) }
    }

    /// Re-download an installed skill from its GitHub source, preserving its
    /// armed/off state. Returns a footer message.
    func updateInstalled(_ skill: Skill) async -> String {
        guard let source = sourceForInstalled(skill) else {
            return "Can't tell where \(skill.displayName) came from — no update source on file."
        }
        let wasArmed = skill.isArmed
        let shelfSkill = DiscoverySkill(source: source, skillId: skill.skillId, installs: 0, isOfficial: false)
        await install(shelfSkill)
        if let failure = errorMessage {
            return failure.replacingOccurrences(of: "Install failed", with: "Update failed")
        }
        if let env = CoworkEnvironment.locate() {
            if wasArmed {
                try? env.arm(skillId: skill.skillId)
            } else {
                try? env.disarm(skillId: skill.skillId)
            }
        }
        return "\(skill.displayName) updated from \(source)."
    }
}
