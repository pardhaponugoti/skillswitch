import AppKit
import SwiftUI

/// Checks GitHub for a newer release than the running build. One lightweight
/// call per launch; publishes the new version string only when it's actually
/// ahead of ours, so the faceplate badge stays hidden until there's something
/// to grab.
@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var newerVersion: String?
    @Published private(set) var downloading = false

    private static let latestAPI = URL(string: "https://api.github.com/repos/pardhaponugoti/skillswitch/releases/latest")!
    private static let dmgURL = URL(string: "https://github.com/pardhaponugoti/skillswitch/releases/latest/download/SkillSwitch.dmg")!
    static let releasesPage = URL(string: "https://github.com/pardhaponugoti/skillswitch/releases/latest")!

    private var bundleVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var currentVersion: String { bundleVersion ?? "0.0.0" }

    /// What the faceplate etches after "MOD." — unbundled dev runs have no
    /// Info.plist, so they read "DEV" rather than a bogus number.
    var displayVersion: String { bundleVersion ?? "DEV" }

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

    /// Download the new DMG straight into ~/Downloads and open it, so the
    /// familiar drag-to-Applications window appears with no browser detour.
    /// Falls back to the releases page if anything goes wrong.
    func downloadAndOpen() {
        guard !downloading else { return }
        downloading = true
        Task {
            defer { downloading = false }
            do {
                let (tmp, response) = try await URLSession.shared.download(from: Self.dmgURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

                let downloads = try FileManager.default.url(
                    for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let dest = uniqueDestination(in: downloads, named: "SkillSwitch.dmg")
                try FileManager.default.moveItem(at: tmp, to: dest)
                // Opening the .dmg mounts it and shows its drag-install window;
                // Gatekeeper verifies the notarized image on open.
                NSWorkspace.shared.open(dest)
            } catch {
                NSWorkspace.shared.open(Self.releasesPage)
            }
        }
    }

    private func uniqueDestination(in dir: URL, named name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = dir.appendingPathComponent(name)
        var n = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(base) \(n).\(ext)")
            n += 1
        }
        return candidate
    }
}
