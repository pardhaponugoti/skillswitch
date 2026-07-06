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
        if coworkFound, let env = CoworkEnvironment.locate() {
            orphans = SkillScanner.scanOrphans(env: env, manifestIds: Set(skills.map(\.skillId)).union(OffBook.skillIds))
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
            Chime.pop()
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
            Chime.pop()
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
            if try env.entry(skillId: skill.skillId) != nil {
                try env.remove(skillId: skill.skillId)
            }
            // Sweep every remaining copy — parked and live leftover alike — so
            // no stray folder resurrects a ghost or an INSTALLED badge later.
            let fm = FileManager.default
            for dir in [env.parkedDir(skillId: skill.skillId),
                        env.skillsDir.appendingPathComponent(skill.skillId, isDirectory: true)]
            where fm.fileExists(atPath: dir.path) {
                try? fm.trashItem(at: dir, resultingItemURL: nil)
            }
            OffBook.forget(skill.skillId)
            SourceBook.forget(skill.skillId)
            Chime.pop()
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
            Chime.pop()
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

    @Published private(set) var personas: [Persona] = PersonaBook.load()

    func addPersona(_ persona: Persona) {
        guard !personas.contains(where: { $0.id == persona.id }) else { return }
        personas.append(persona)
        PersonaBook.save(personas)
    }

    func removePersona(_ persona: Persona) {
        personas.removeAll { $0.id == persona.id }
        PersonaBook.save(personas)
        message = "\(persona.name.capitalized) removed — its skills stay on the panel."
    }

    /// How much of a persona is currently wired and armed.
    func personaState(_ persona: Persona) -> (installed: Int, on: Int) {
        let byId = Dictionary(circuits.map { ($0.skillId, $0) }, uniquingKeysWith: { a, _ in a })
        let installed = persona.members.filter { byId[$0.skillId] != nil }.count
        let on = persona.members.filter { byId[$0.skillId]?.isArmed == true }.count
        return (installed, on)
    }

    /// Arm every member of a persona (green + ⚡). They fire at the start of
    /// the next chat, then each trips off — same one-shot rule as a single
    /// breaker. Members not yet installed are skipped here — the caller
    /// installs them first.
    func energize(_ persona: Persona) {
        guard let env = CoworkEnvironment.locate() else { return }
        for member in persona.members where circuits.contains(where: { $0.skillId == member.skillId }) {
            if let remembered = OffBook.entry(for: member.skillId), (try? env.entry(skillId: member.skillId)) == nil {
                try? env.rewire(entry: remembered)
                OffBook.forget(member.skillId)
            }
            try? env.arm(skillId: member.skillId)
        }
        Chime.pop()
        scan()
    }

    /// Switch every member of a persona OFF.
    func unplug(_ persona: Persona) {
        guard let env = CoworkEnvironment.locate() else { return }
        for member in persona.members where circuits.contains(where: { $0.skillId == member.skillId }) {
            if let removed = try? env.unwire(skillId: member.skillId) {
                OffBook.record(removed, for: member.skillId)
            }
        }
        Chime.pop()
        scan()
        message = "\(persona.name.capitalized) unplugged — its breakers are off."
    }

    // MARK: - Tripping

    /// Armed circuits are one-shots: poll Cowork's session logs and trip the
    /// breaker the moment the skill actually fires in a chat.
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
            // keepLive: the chat that fired this skill may still read its files.
            if let removed = try? env.unwire(skillId: skillId, keepLive: true) {
                OffBook.record(removed, for: skillId)
            }
        }
        Chime.trip()
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
