import Foundation

/// Remembers the manifest entries of skills the user switched OFF. A red
/// breaker means the entry was removed from Cowork's manifest entirely —
/// the only off Cowork actually honors — so this book is what lets the
/// rocker flip back on with the entry exactly as it was.
///
/// Scoped per Cowork account (`CoworkEnvironment.accountKey`): a skill
/// switched off on a work account must never show up as a red ghost — or
/// get rewired — on a personal account sharing the same Mac.
enum OffBook {
    private static let key = "unwiredEntriesByAccount"
    private static let legacyKey = "unwiredEntries"   // pre-0.9.6 global book

    private static var books: [String: [String: [String: Any]]] {
        get { (UserDefaults.standard.dictionary(forKey: key) as? [String: [String: [String: Any]]]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func record(_ entry: [String: Any], for skillId: String, account: String) {
        var current = books
        current[account, default: [:]][skillId] = entry
        books = current
    }

    static func entry(for skillId: String, account: String) -> [String: Any]? {
        books[account]?[skillId]
    }

    static func forget(_ skillId: String, account: String) {
        var current = books
        current[account]?.removeValue(forKey: skillId)
        books = current
    }

    static func skillIds(account: String) -> Set<String> {
        Set(books[account]?.keys ?? [:].keys)
    }

    /// One-time: fold the pre-0.9.6 global book into the given account.
    /// Those entries could only have been written while it was the signed-in
    /// account, so it's the right home; existing scoped entries win ties.
    static func adoptLegacy(into account: String) {
        guard let legacy = UserDefaults.standard.dictionary(forKey: legacyKey) as? [String: [String: Any]],
              !legacy.isEmpty else {
            UserDefaults.standard.removeObject(forKey: legacyKey)
            return
        }
        var current = books
        for (skillId, entry) in legacy where current[account]?[skillId] == nil {
            current[account, default: [:]][skillId] = entry
        }
        books = current
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }
}
