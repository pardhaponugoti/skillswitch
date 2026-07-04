import Foundation

enum OwnerKind: String, Codable {
    case organization
    case user
}

/// Classifies GitHub owners as organizations or individuals so the shelf can
/// filter by author. Ships with a seed covering every owner on the
/// release-day leaderboard (regenerate with tools/make-owner-seed.sh);
/// anyone new is resolved lazily against the GitHub API and cached for 30
/// days. An unresolved owner counts as an individual — the filter fails open
/// into visibility, it never hides a skill on a guess.
@MainActor
final class OwnerDirectory {
    private struct Cached: Codable {
        let kind: OwnerKind
        let fetchedAt: Date
    }

    private static let cacheKey = "ownerKindCache"
    private static let ttl: TimeInterval = 30 * 24 * 3600

    private var cache: [String: Cached]
    private var attempted: Set<String> = []
    var onChange: (() -> Void)?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let stored = try? JSONDecoder().decode([String: Cached].self, from: data) {
            cache = stored
        } else {
            cache = [:]
        }
    }

    func kind(of owner: String) -> OwnerKind? {
        if let seeded = OwnerSeed.kinds[owner] { return seeded }
        if let cached = cache[owner], Date().timeIntervalSince(cached.fetchedAt) < Self.ttl {
            return cached.kind
        }
        return nil
    }

    /// Look up owners the seed and cache don't cover. Capped per call to stay
    /// well inside GitHub's unauthenticated rate budget, which the install
    /// path also draws from.
    func resolve(_ owners: [String]) async {
        let missing = Array(Set(owners).filter { kind(of: $0) == nil && !attempted.contains($0) }.prefix(20))
        guard !missing.isEmpty else { return }
        attempted.formUnion(missing)

        var changed = false
        for owner in missing {
            guard let escaped = owner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://api.github.com/users/\(escaped)"),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  // A 403 rate-limit body is valid JSON — only trust a 200.
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = object["type"] as? String else { continue }
            cache[owner] = Cached(
                kind: type == "Organization" ? .organization : .user,
                fetchedAt: Date()
            )
            changed = true
        }
        if changed {
            if let data = try? JSONEncoder().encode(cache) {
                UserDefaults.standard.set(data, forKey: Self.cacheKey)
            }
            onChange?()
        }
    }
}
