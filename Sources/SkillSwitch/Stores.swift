import AppKit
import SwiftUI

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var skills: [Skill] = []
    @Published private(set) var coworkFound = true
    @Published var message = ""

    private var tripTimer: Timer?
    private var tripScanner: TripScanner?

    var circuits: [Skill] { skills.filter { !$0.isHardwired } }
    var hardwired: [Skill] { skills.filter { $0.isHardwired } }
    var liveCount: Int { skills.filter { $0.enabled }.count }

    func scan() {
        if let found = SkillScanner.scan() {
            skills = found
            coworkFound = true
        } else {
            skills = []
            coworkFound = false
        }
        syncTripWatcher()
    }

    func toggle(_ skill: Skill) {
        if skill.isHardwired {
            message = "\(skill.displayName) is built into Claude — it's always on."
            return
        }
        do {
            try SkillToggler.setEnabled(skill, !skill.enabled)
            NSSound(named: "Pop")?.play()
            scan()
            message = skill.enabled
                ? "\(skill.displayName) disarmed."
                : "\(skill.displayName) is ARMED — it fires at the start of your next Cowork chat, then trips off."
        } catch {
            scan()
            message = error.localizedDescription
        }
    }

    // MARK: - Tripping

    /// Armed circuits are one-shots: poll Cowork's session logs and trip the
    /// breaker the moment the skill actually fires in a chat.
    private var armedCircuits: [String: Date] {
        Dictionary(
            circuits.filter(\.isArmed).map { ($0.skillId, $0.armedAt ?? Date()) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func syncTripWatcher() {
        guard !armedCircuits.isEmpty else {
            tripTimer?.invalidate()
            tripTimer = nil
            tripScanner = nil
            return
        }
        if tripScanner == nil, let env = CoworkEnvironment.locate() {
            tripScanner = TripScanner(sessionsRoot: env.sessionsRoot)
        }
        guard tripTimer == nil else { return }
        tripTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkTrips() }
        }
    }

    private func checkTrips() {
        let armed = armedCircuits
        guard !armed.isEmpty, var scanner = tripScanner else { return }
        let fired = scanner.firedSkills(armed)
        tripScanner = scanner
        guard !fired.isEmpty, let env = CoworkEnvironment.locate() else { return }

        for skillId in fired {
            try? env.disarm(skillId: skillId)
        }
        NSSound(named: "Funk")?.play()
        let names = skills
            .filter { fired.contains($0.skillId) }
            .map(\.displayName)
            .joined(separator: ", ")
        scan()
        message = "\(names) fired in your chat — breaker tripped."
    }

    func copyInvocation(_ skill: Skill) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(skill.invocation, forType: .string)
        message = "Copied \(skill.invocation) — paste it into Cowork, or just ask for it."
    }
}
