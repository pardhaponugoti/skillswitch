import SwiftUI

struct PanelView: View {
    enum Tab {
        case breakers, personas, add
    }

    @StateObject private var store = SkillStore()
    @StateObject private var discovery = DiscoveryStore()
    @StateObject private var updates = UpdateChecker()
    @State private var tab: Tab = .breakers

    var body: some View {
        ZStack {
            Theme.wall.ignoresSafeArea()

            VStack(spacing: 0) {
                FaceplateHeader(updates: updates)
                tabs
                content
                footer
            }
            .background(Theme.steel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.steelEdge, lineWidth: 1.5)
            )
            .overlay(alignment: .topLeading) { ScrewView(angle: 20).padding(7) }
            .overlay(alignment: .topTrailing) { ScrewView(angle: 65).padding(7) }
            .overlay(alignment: .bottomLeading) { ScrewView(angle: 80).padding(7) }
            .overlay(alignment: .bottomTrailing) { ScrewView(angle: 40).padding(7) }
            .shadow(color: .black.opacity(0.55), radius: 22, y: 12)
            .padding(16)
            .padding(.top, 8)
        }
        .frame(width: 392)
        .frame(minHeight: 660, idealHeight: 780)
        .onAppear {
            store.scan()
            discovery.onInstall = { [weak store] name in
                store?.scan()
                store?.message = "\(name) installed and ARMED — it fires in your next Cowork chat."
                Chime.pop()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.scan()
            discovery.refreshInstalled()
        }
        .task { await updates.check() }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            PanelTab(title: "BREAKERS", icon: "switch.2", active: tab == .breakers) { tab = .breakers }
            PanelTab(title: "PERSONAS", icon: "theatermasks.fill", active: tab == .personas) { tab = .personas }
            PanelTab(title: "ADD SKILLS", icon: "plus.circle.fill", active: tab == .add) { tab = .add }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var content: some View {
        Group {
            switch tab {
            case .breakers:
                BreakerBoard(store: store, discovery: discovery, addSkills: { tab = .add }, showPersonas: { tab = .personas })
            case .personas:
                PersonasView(store: store, discovery: discovery)
            case .add:
                DiscoveryView(store: discovery)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.interior)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.black.opacity(0.6), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(store.liveCount > 0 ? Theme.liveGreen : Theme.deadGray)
                .frame(width: 8, height: 8)
                .shadow(color: store.liveCount > 0 ? Theme.liveGreen.opacity(0.9) : .clear, radius: 4)
            Text("\(store.liveCount) LIVE")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.inkDark.opacity(0.85))
            Text(store.message.isEmpty ? "armed skills fire in your next chat, then trip off" : store.message)
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkDark.opacity(0.65))
                .lineLimit(2)
            Spacer(minLength: 6)
            Button {
                store.scan()
                discovery.refreshInstalled()
                Task { await discovery.load(force: true) }
                store.message = "Rescanned."
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkDark.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Rescan the panel and refresh the skills.sh shelf")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
    }
}

struct FaceplateHeader: View {
    @ObservedObject var updates: UpdateChecker

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                ZStack {
                    Text("SKILLSWITCH")
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                        .tracking(6)
                        .foregroundStyle(Theme.inkDark)
                        .shadow(color: .white.opacity(0.5), radius: 0, y: 1)
                    HStack {
                        SettingsButton { showSettings.toggle() }
                            .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                                SettingsPopover(updates: updates)
                            }
                        Spacer()
                    }
                    .padding(.leading, 14)
                    if let version = updates.newerVersion {
                        HStack {
                            Spacer()
                            UpdateBadge(version: version, downloading: updates.downloading) { updates.downloadAndOpen() }
                        }
                        .padding(.trailing, 14)
                    }
                }
                Text("SKILL LOAD CENTER · MOD. \(updates.displayVersion) · FOR USE WITH CLAUDE COWORK")
                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Theme.inkDark.opacity(0.55))
            }
            .padding(.top, 14)

            HazardStripe()
                .frame(height: 5)
                .clipShape(Capsule())
                .padding(.horizontal, 40)
        }
        .padding(.bottom, 10)
    }
}

/// The "new version available" flag on the faceplate — a small blinking
/// indicator light beside the wordmark that opens the download page.
struct UpdateBadge: View {
    let version: String
    var downloading: Bool = false
    let action: () -> Void
    @State private var glow = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Circle()
                    .fill(Theme.offRed)
                    .frame(width: 5, height: 5)
                    .shadow(color: Theme.offRed.opacity(glow ? 0.9 : 0.2), radius: glow ? 4 : 1)
                Text(downloading ? "DOWNLOADING…" : "UPDATE")
                    .font(.system(size: 7, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Theme.tapeBlack)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(Theme.safety))
            .overlay(Capsule().stroke(.black.opacity(0.35), lineWidth: 0.8))
        }
        .buttonStyle(PressStyle())
        .disabled(downloading)
        .help(downloading
            ? "Downloading SkillSwitch \(version)…"
            : "Version \(version) is available — click to download and open the installer.")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

/// The settings gear on the faceplate — a small etched control beside the
/// wordmark that opens the panel's preferences popover.
struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.inkDark.opacity(0.5))
                .shadow(color: .white.opacity(0.5), radius: 0, y: 1)
        }
        .buttonStyle(PressStyle())
        .help("Settings")
    }
}

/// Preferences popover — mute the panel sounds and check for a newer build.
struct SettingsPopover: View {
    @ObservedObject var updates: UpdateChecker
    @AppStorage(Chime.muteKey) private var muted = false
    @State private var checking = false
    @State private var checkedClean = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SETTINGS")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Theme.inkDark.opacity(0.85))

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: Binding(get: { !muted }, set: { muted = !$0 })) {
                    HStack(spacing: 6) {
                        Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 16)
                        Text("Panel sounds")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.inkDark.opacity(0.9))
                }
                .toggleStyle(.switch)
                .tint(Theme.liveGreen)

                Text(muted ? "Clicks and trips are silenced." : "Clicks and trips play a sound.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkDark.opacity(0.55))
            }

            Divider().overlay(Theme.inkDark.opacity(0.15))

            VStack(alignment: .leading, spacing: 6) {
                Text("VERSION")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Theme.inkDark.opacity(0.5))
                HStack(spacing: 8) {
                    Text("SkillSwitch \(updates.currentVersion)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkDark.opacity(0.9))
                    Spacer(minLength: 6)
                    updateControl
                }
            }
        }
        .padding(16)
        .frame(width: 240, alignment: .leading)
        // The system popover material is dark in dark mode, but our labels are
        // faceplate ink (near-black). Give it the light steel background the
        // rest of the panel uses so the dark ink reads, and force a light
        // scheme so the arrow/edges match.
        .background(Theme.steel)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder private var updateControl: some View {
        if let version = updates.newerVersion {
            Button(action: updates.downloadAndOpen) {
                Text(updates.downloading ? "DOWNLOADING…" : "GET \(version)")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(Theme.tapeBlack)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(Theme.safety))
            }
            .buttonStyle(PressStyle())
            .disabled(updates.downloading)
        } else {
            Button {
                checking = true
                checkedClean = false
                Task {
                    await updates.check()
                    checking = false
                    checkedClean = updates.newerVersion == nil
                }
            } label: {
                Text(checking ? "Checking…" : (checkedClean ? "Up to date ✓" : "Check for updates"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(checkedClean ? Theme.liveGreen : Theme.inkDark.opacity(0.7))
            }
            .buttonStyle(.plain)
            .disabled(checking)
        }
    }
}

struct PanelTab: View {
    let title: String
    let icon: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(1.2)
            }
            .foregroundStyle(active ? .white : Theme.inkDark.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(active ? AnyShapeStyle(Theme.interior) : AnyShapeStyle(Color.white.opacity(0.25)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.black.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Breaker board

struct BreakerBoard: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var discovery: DiscoveryStore
    var addSkills: () -> Void
    var showPersonas: () -> Void

    @State private var removalCandidate: Skill?
    @AppStorage("binExpanded") private var binExpanded = false
    @AppStorage("panelCommissioned") private var commissioned = false

    var body: some View {
        if !store.coworkFound {
            missingCowork
        } else if store.skills.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    if !commissioned {
                        commissioningCard
                    }
                    if store.circuits.isEmpty && store.orphans.isEmpty {
                        miniEmptyCircuits
                    } else {
                        sectionHeader("CIRCUITS", detail: "flip to arm · fires once next chat")
                        ForEach(store.circuits) { skill in
                            BreakerRow(
                                skill: skill,
                                subtitle: provenance(skill),
                                canUpdate: discovery.sourceForInstalled(skill) != nil,
                                toggle: { store.toggle(skill) },
                                copy: { store.copyInvocation(skill) },
                                update: { updateSkill(skill) },
                                remove: { removalCandidate = skill }
                            )
                        }
                        ForEach(store.orphans) { orphan in
                            UnwiredRow(part: orphan) { store.wireIn(orphan) }
                        }
                    }

                    if !store.bin.isEmpty {
                        binSection
                    }

                    if !store.hardwired.isEmpty {
                        sectionHeader("HARDWIRED", detail: "built into Claude · always on")
                            .padding(.top, 8)
                        ForEach(store.hardwired) { skill in
                            BreakerRow(
                                skill: skill,
                                subtitle: skill.sourceLabel,
                                canUpdate: false,
                                toggle: { store.toggle(skill) },
                                copy: { store.copyInvocation(skill) },
                                update: {},
                                remove: {}
                            )
                        }
                    }
                }
                .padding(10)
            }
            .onAppear { discovery.resolveOwners(for: store.circuits) }
            .confirmationDialog(
                "Remove \(removalCandidate?.displayName ?? "this skill")?",
                isPresented: Binding(
                    get: { removalCandidate != nil },
                    set: { if !$0 { removalCandidate = nil } }
                )
            ) {
                Button("Remove — folder goes to the Trash", role: .destructive) {
                    if let skill = removalCandidate { store.remove(skill) }
                    removalCandidate = nil
                }
                Button("Cancel", role: .cancel) { removalCandidate = nil }
            } message: {
                Text("Its breaker disappears from the panel and the skill folder is moved to the Trash — drag it back out if you change your mind.")
            }
        }
    }

    /// Sub-label for a circuit: who published it, when we know.
    private func provenance(_ skill: Skill) -> String {
        guard let source = discovery.sourceForInstalled(skill),
              let owner = source.split(separator: "/").first.map(String.init) else {
            return "INSTALLED"
        }
        switch discovery.ownerKind(of: owner) {
        case .organization: return "ORG: \(owner)"
        case .user: return "USER: \(owner)"
        case nil: return "FROM: \(owner)"
        }
    }

    /// First three starters make the friendliest intro (roles everyone knows).
    private var onboardingStarters: [Persona] { Array(Persona.starters.prefix(3)) }

    private var commissioningCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOT SURE WHERE TO START?")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Theme.safety)
                    Text("Turn on a persona and Claude plays the role — no skills to pick, no setup.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Button {
                    withAnimation { commissioned = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }

            ForEach(onboardingStarters) { persona in
                onboardingPersonaRow(persona)
            }

            Button(action: showPersonas) {
                Text("SEE ALL \(Persona.starters.count) PERSONAS →")
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            .padding(.top, 1)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.breaker))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Theme.safety.opacity(0.55), lineWidth: 1)
        )
    }

    private func onboardingPersonaRow(_ persona: Persona) -> some View {
        let on = store.personaState(persona).on == persona.members.count && !persona.members.isEmpty
        return HStack(spacing: 9) {
            VStack(alignment: .leading, spacing: 1) {
                Text(persona.name)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
                Text(persona.blurb)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 6)
            if on {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                    Text("ON")
                }
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.liveGreen)
            } else {
                Button {
                    turnOnPersona(persona)
                } label: {
                    Text("TURN ON")
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(Theme.tapeBlack)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.safety))
                        .overlay(Capsule().stroke(.black.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 9)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.black.opacity(0.22)))
    }

    private func turnOnPersona(_ persona: Persona) {
        store.addPersona(persona)
        store.message = "Turning on \(persona.name.capitalized)…"
        Task {
            for member in persona.members where !store.circuits.contains(where: { $0.skillId == member.skillId }) {
                if let source = member.source {
                    await discovery.install(DiscoverySkill(
                        source: source, skillId: member.skillId, installs: 0, isOfficial: false))
                }
            }
            store.scan()
            store.energize(persona)
            store.message = "\(persona.name.capitalized) is on — Claude plays the role in your next chat."
        }
    }

    private func updateSkill(_ skill: Skill) {
        store.message = "Updating \(skill.displayName)…"
        Task {
            let result = await discovery.updateInstalled(skill)
            store.scan()
            store.message = result
        }
    }

    private var binSection: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { binExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.safety.opacity(0.9))
                        .rotationEffect(.degrees(binExpanded ? 90 : 0))
                    Text("SPARE PARTS BIN")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.safety.opacity(0.9))
                    Spacer()
                    Text("FROM CLAUDE CODE · \(store.bin.count)")
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            if binExpanded {
                ForEach(store.bin) { part in
                    BinRow(part: part) { store.importPart(part) }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(Theme.safety.opacity(0.9))
            Spacer()
            Text(detail.uppercased())
                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 4)
    }

    private var miniEmptyCircuits: some View {
        VStack(spacing: 10) {
            Text("No personal skills wired up yet")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            addButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var missingCowork: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
            Text("Can't find Claude's fuse box")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            Text("SkillSwitch flips skills for Claude Cowork.\nInstall the Claude desktop app, open a\nCowork chat once, then check again.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.45))
            Button {
                store.scan()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("CHECK AGAIN")
                        .tracking(1.5)
                }
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.tapeBlack)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.safety))
                .overlay(Capsule().stroke(.black.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "powerplug")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
            Text("Nothing on the panel")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            Text("Add skills and they show up here\nas switches you can flip on and off.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.45))
            addButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addButton: some View {
        Button(action: addSkills) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("ADD SKILLS")
                    .tracking(1.5)
            }
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.tapeBlack)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.safety))
            .overlay(Capsule().stroke(.black.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct BreakerRow: View {
    let skill: Skill
    let subtitle: String
    let canUpdate: Bool
    let toggle: () -> Void
    let copy: () -> Void
    let update: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            RockerSwitch(isOn: skill.enabled, hardwired: skill.isHardwired, armed: skill.enabled, action: toggle)

            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name.uppercased())
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Theme.tapeBlack))
                Text(subtitle.uppercased())
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
                if !skill.isHardwired {
                    Text(skill.enabled ? "ARMED — FIRES NEXT CHAT, THEN TRIPS OFF" : "OFF — CLAUDE CAN'T SEE IT")
                        .font(.system(size: 7.5, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle((skill.enabled ? Theme.liveGreen : Theme.offRed).opacity(0.85))
                        .lineLimit(1)
                }
            }
            .onTapGesture(perform: copy)
            .help("\(skill.invocation) — \(skill.description.isEmpty ? "no description" : skill.description)\n\nClick label to copy \(skill.invocation)")

            Spacer(minLength: 4)

            if !skill.isHardwired {
                Menu {
                    Button("Update from GitHub", action: update)
                        .disabled(!canUpdate)
                    Divider()
                    Button("Remove…", role: .destructive, action: remove)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Update or remove this skill")
            }

            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .shadow(color: skill.enabled ? dotColor.opacity(0.9) : .clear, radius: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.breaker)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var dotColor: Color {
        skill.enabled ? Theme.liveGreen : Theme.offRed.opacity(0.55)
    }
}

/// A persona: a curated zone of skills armed together — they fire next chat, then trip.
struct PersonaRow: View {
    let persona: Persona
    let state: (installed: Int, on: Int)
    let energize: () -> Void
    let unplug: () -> Void

    private var fullyOn: Bool { state.on == persona.members.count }

    var body: some View {
        HStack(spacing: 10) {
            RockerSwitch(
                isOn: fullyOn,
                hardwired: false,
                armed: true,
                helpOverride: fullyOn
                    ? "ARMED — every skill in this persona fires at the start of your next chat, then trips off. Click to disarm."
                    : "OFF — click to install anything missing and arm the whole persona for your next chat."
            ) {
                fullyOn ? unplug() : energize()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(persona.name)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Theme.tapeBlack))
                Text(persona.blurb)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(persona.members.count) SKILLS · \(state.on) ON")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer(minLength: 8)

            Circle()
                .fill(fullyOn ? Theme.liveGreen : Theme.offRed.opacity(0.55))
                .frame(width: 6, height: 6)
                .shadow(color: fullyOn ? Theme.liveGreen.opacity(0.9) : .clear, radius: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.breaker)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(fullyOn ? Theme.liveGreen.opacity(0.4) : .white.opacity(0.07), lineWidth: 1)
        )
    }
}

/// Build a persona from the skills already on the panel.
struct PersonaBuilderSheet: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var discovery: DiscoveryStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BUILD A PERSONA")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(Theme.safety)

            TextField("Name it — MARKETER, EDITOR, COACH…", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            if store.circuits.isEmpty {
                Text("No skills on the panel yet — install a few from Add Skills first, then come back and group them.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Text("Pick its skills:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(store.circuits) { skill in
                            Toggle(isOn: Binding(
                                get: { selected.contains(skill.skillId) },
                                set: { on in
                                    if on { selected.insert(skill.skillId) } else { selected.remove(skill.skillId) }
                                }
                            )) {
                                Text(skill.name)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    let persona = Persona(
                        id: UUID(),
                        name: name.trimmingCharacters(in: .whitespaces).uppercased(),
                        blurb: "\(selected.count) skills, one flip.",
                        members: store.circuits
                            .filter { selected.contains($0.skillId) }
                            .map { Persona.Member(skillId: $0.skillId, source: discovery.sourceForInstalled($0)) }
                    )
                    store.addPersona(persona)
                    store.energize(persona)
                    store.message = "\(persona.name.capitalized) built — \(persona.members.count) breakers on."
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selected.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 330)
    }
}

/// A folder found inside Cowork's skills dir with no manifest entry — one
/// click wires it onto the panel.
struct UnwiredRow: View {
    let part: ExternalSkill
    let wireIn: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: wireIn) {
                Text("WIRE IN")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Theme.tapeBlack)
                    .frame(width: 60, height: 30)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.safety))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(.black.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(PressStyle())

            VStack(alignment: .leading, spacing: 3) {
                Text(part.name.uppercased())
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Theme.tapeBlack))
                Text("UNWIRED — FOUND IN THE BOX")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.safety.opacity(0.7))
            }
            .help(part.description.isEmpty ? "No description" : part.description)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.breaker.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Theme.safety.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }
}

/// A Claude Code skill (~/.claude/skills) importable into Cowork.
struct BinRow: View {
    let part: ExternalSkill
    let importPart: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(part.name.uppercased())
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(part.status == .importable ? 0.92 : 0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Theme.tapeBlack))
                Text(part.status == .importable ? "~/.CLAUDE/SKILLS" : "NAME TAKEN BY A BUILT-IN")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .help(part.description.isEmpty ? "No description" : part.description)

            Spacer(minLength: 4)

            if part.status == .importable {
                Button(action: importPart) {
                    Text("IMPORT")
                        .tracking(1)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.tapeBlack)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.safety))
                        .overlay(Capsule().stroke(.black.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(PressStyle())
                .help("Copy into Claude Cowork and put it on the panel")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.breaker.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
    }
}

struct RockerSwitch: View {
    let isOn: Bool
    let hardwired: Bool
    var armed: Bool = false
    var helpOverride: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.tapeBlack)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )

                HStack {
                    Text("O")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(isOn ? 0.35 : 0.7))
                    Spacer()
                    Text("I")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(isOn ? 0.9 : 0.35))
                }
                .padding(.horizontal, 6)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(paddleColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.white.opacity(0.22))
                            .frame(height: 6)
                            .offset(y: -6),
                        alignment: .center
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(.black.opacity(0.5), lineWidth: 1)
                    )
                    .overlay {
                        // Bolt = electricity flows on its own: hardwired mains,
                        // or a one-shot that fires next chat and trips.
                        if hardwired || (armed && isOn) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.black.opacity(0.5))
                        }
                    }
                    .frame(width: 24, height: 22)
                    .offset(x: isOn ? 14 : -14)
                    .animation(.spring(response: 0.22, dampingFraction: 0.55), value: isOn)
            }
            .frame(width: 60, height: 30)
        }
        .buttonStyle(.plain)
        .help(helpOverride ?? (hardwired
            ? "Built into Claude — always on"
            : (isOn ? "ARMED — Claude uses this at the start of your next chat, then the breaker trips off. Click to disarm."
                    : "OFF — click to arm it for your next chat")))
    }

    /// Red: off — unwired, Claude can't see it. Green + ⚡: armed — fires next
    /// chat, then trips back to off.
    private var paddleColor: Color {
        if hardwired { return Theme.deadGray }
        return isOn ? Theme.liveGreen : Theme.offRed
    }
}
