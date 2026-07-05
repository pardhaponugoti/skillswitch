import AppKit

/// Every panel sound routes through here so one mute flag silences them all.
/// The flag lives in UserDefaults under `muteKey`; the settings toggle writes
/// the same key via @AppStorage, so this stays the single source of truth.
enum Chime {
    static let muteKey = "muteSounds"

    static var muted: Bool { UserDefaults.standard.bool(forKey: muteKey) }

    /// The everyday flip/wire/import click.
    static func pop() { play("Pop") }

    /// The breaker-trip sound when an armed one-shot fires.
    static func trip() { play("Funk") }

    private static func play(_ name: String) {
        guard !muted else { return }
        NSSound(named: name)?.play()
    }
}
