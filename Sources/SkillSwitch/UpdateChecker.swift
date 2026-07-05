import AppKit
import SwiftUI

/// Checks GitHub for a newer release than the running build. One lightweight
/// call per launch; publishes the new version string only when it's actually
/// ahead of ours, so the faceplate badge stays hidden until there's something
/// to grab.
@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var newerVersion: String?

    private static let latestAPI = URL(string: "https://api.github.com/repos/pardhaponugoti/skillswitch/releases/latest")!
    static let releasesPage = URL(string: "https://github.com/pardhaponugoti/skillswitch/releases/latest")!

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func check() async {
        var request = URLRequest(url: Self.latestAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String else { return }
        let remote = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        if Self.isNewer(remote, than: currentVersion) {
            newerVersion = remote
        }
    }

    /// Numeric dotted-version compare (0.7.10 > 0.7.2), tolerant of missing
    /// or non-numeric segments.
    static func isNewer(_ candidate: String, than base: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let a = parts(candidate), b = parts(base)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    func openReleases() {
        NSWorkspace.shared.open(Self.releasesPage)
    }
}
