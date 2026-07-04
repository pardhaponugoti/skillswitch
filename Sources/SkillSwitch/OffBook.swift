import Foundation

/// Remembers the manifest entries of skills the user switched OFF. A red
/// breaker means the entry was removed from Cowork's manifest entirely —
/// the only off Cowork actually honors — so this book is what lets the
/// rocker flip back on with the entry exactly as it was.
enum OffBook {
    private static let key = "unwiredEntries"

    private static var book: [String: [String: Any]] {
        get { (UserDefaults.standard.dictionary(forKey: key) as? [String: [String: Any]]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func record(_ entry: [String: Any], for skillId: String) {
        var current = book
        current[skillId] = entry
        book = current
    }

    static func entry(for skillId: String) -> [String: Any]? {
        book[skillId]
    }

    static func forget(_ skillId: String) {
        var current = book
        current.removeValue(forKey: skillId)
        book = current
    }

    static var skillIds: Set<String> { Set(book.keys) }
}
