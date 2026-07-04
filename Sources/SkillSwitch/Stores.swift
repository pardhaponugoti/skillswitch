import AppKit
import SwiftUI

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var skills: [Skill] = []
    @Published private(set) var orphans: [ExternalSkill] = []
    @Published private(set) var bin: [ExternalSkill] = []
    @Published private(set) var coworkFound = true
    @Published var message = ""

    private var tripTimer: Timer?
    private var tripScanner: TripScanner?

    /// The bundled diagnostic rides the panel's TEST button, not a breaker row.
    static let testerId = "circuit-tester"

    var circuits: [Skill] { skills.filter { !$0.isHardwired && $0.skillId != Self.testerId } }
    var hardwired: [Skill] { skills.filter { $0.isHardwired } }
    var tester: Skill? { skills.first { $0.skillId == Self.testerId } }
    var liveCount: Int { skills.filter { $0.enabled && $0.skillId != Self.testerId }.count }

    /// Quietly wire in the bundled circuit-tester (OFF) the first time we see
    /// a healthy Cowork install without one.
    func ensureTesterInstalled() {
        guard coworkFound, tester == nil, let env = CoworkEnvironment.locate(),
              let bundled = Bundle.main.resourceURL?.appendingPathComponent("skills/circuit-tester", isDirectory: true),
              FileManager.default.fileExists(atPath: bundled.appendingPathComponent("SKILL.md").path) else { return }
        try? env.importFolder(at: bundled, skillId: Self.testerId)
        scan()
    }

    /// The panel's TEST button: arm the diagnostic; it runs in the next
    /// Cowork chat, reports, and trips off.
    func pressTest() {
        guard let env = CoworkEnvironment.locate() else {
            message = CoworkError.notFound.localizedDescription
            return
        }
        do {
            if tester == nil {
                guard let bundled = Bundle.main.resourceURL?.appendingPathComponent("skills/circuit-tester", isDirectory: true),
                      FileManager.default.fileExists(atPath: bundled.appendingPathComponent("SKILL.md").path) else {
                    message = "The bundled circuit tester is missing from this build."
                    return
                }
                try env.importFolder(at: bundled, skillId: Self.testerId)
            }
            try env.arm(skillId: Self.testerId)
            NSSound(named: "Pop")?.play()
            scan()
            message = "TEST armed — open a Cowork chat and the tester runs, then trips off."
        } catch {
            scan()
            message = error.localizedDescription
        }
    }

    func scan() {
        if let found = SkillScanner.scan() {
            skills = found
            coworkFound = true
        } else {
            skills = []
            coworkFound = false
        }
        if coworkFound, let env = CoworkEnvironment.locate() {
            orphans = SkillScanner.scanOrphans(env: env, manifestIds: Set(skills.map(\.skillId)))
            bin = SkillScanner.scanClaudeCode(
                manifestUserIds: Set(circuits.map(\.skillId)),
                builtinIds: Set(hardwired.map(\.skillId))
            )
        } else {
            orphans = []
            bin = []
        }
        syncTripWatcher()
    }

    /// Wire an orphan folder (already inside Cowork's skills dir) into the
    /// manifest, OFF.
    func wireIn(_ orphan: ExternalSkill) {
        guard let env = CoworkEnvironment.locate() else { return }
        do {
            try env.register(
                skillId: orphan.skillId, name: orphan.name,
                description: orphan.description, enabled: false
            )
            NSSound(named: "Pop")?.play()
            scan()
            message = "\(orphan.displayName) wired in — flip to arm."
        } catch {
            scan()
            message = error.localizedDescription
        }
    }

    /// Copy a Claude Code skill into Cowork and register it, OFF.
    func importPart(_ part: ExternalSkill) {
        guard part.status == .importable, let env = CoworkEnvironment.locate() else { return }
        do {
            try env.importFolder(at: part.directory, skillId: part.skillId)
            if let source = SourceBook.fromFrontmatter(directory: part.directory) {
                SourceBook.record(source, for: part.skillId)
            }
            NSSound(named: "Pop")?.play()
            scan()
            message = "\(part.displayName) imported from Claude Code — flip to arm."
        } catch {
            scan()
            message = error.localizedDescription
        }
    }

    /// Remove a user skill: manifest entry dropped, folder to the Trash.
    func remove(_ skill: Skill) {
        guard !skill.isHardwired, let env = CoworkEnvironment.locate() else { return }
        do {
            try env.remove(skillId: skill.skillId)
            SourceBook.forget(skill.skillId)
            NSSound(named: "Pop")?.play()
            scan()
            message = "\(skill.displayName) removed — its folder is in the Trash."
        } catch {
            scan()
            message = error.localizedDescription
        }
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
            if skill.enabled {
                message = skill.armed
                    ? "\(skill.displayName) disarmed."
                    : "\(skill.displayName) switched off."
            } else {
                message = "\(skill.displayName) is ARMED — it fires at the start of your next Cowork chat, then trips off."
            }
        } catch {
            scan()
            message = error.localizedDescription
        }
    }

    // MARK: - Personas

    /// How much of a persona is currently wired and steadily on.
    func personaState(_ persona: Persona) -> (installed: Int, on: Int) {
        let byId = Dictionary(circuits.map { ($0.skillId, $0) }, uniquingKeysWith: { a, _ in a })
        let installed = persona.members.filter { byId[$0.skillId] != nil }.count
        let on = persona.members.filter { byId[$0.skillId]?.isSteadyOn == true }.count
        return (installed, on)
    }

    /// Switch every member of a persona steadily ON (green). Members not yet
    /// installed are skipped here — the caller installs them first.
    func energize(_ persona: Persona) {
        guard let env = CoworkEnvironment.locate() else { return }
        for member in persona.members where circuits.contains(where: { $0.skillId == member.skillId }) {
            try? env.setSteadyOn(skillId: member.skillId)
        }
        NSSound(named: "Pop")?.play()
        scan()
    }

    /// Switch every member of a persona OFF.
    func unplug(_ persona: Persona) {
        guard let env = CoworkEnvironment.locate() else { return }
        for member in persona.members where circuits.contains(where: { $0.skillId == member.skillId }) {
            try? env.disarm(skillId: member.skillId)
        }
        NSSound(named: "Pop")?.play()
        scan()
        message = "\(persona.name.capitalized) unplugged — its breakers are off."
    }

    // MARK: - Tripping

    /// Armed circuits are one-shots: poll Cowork's session logs and trip the
    /// breaker the moment the skill actually fires in a chat. Includes the
    /// TEST-button diagnostic, which trips the same way.
    private var armedCircuits: [String: Date] {
        Dictionary(
            skills.filter { !$0.isHardwired && $0.isArmed }.map { ($0.skillId, $0.armedAt ?? Date()) },
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
