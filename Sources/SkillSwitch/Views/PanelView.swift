import SwiftUI

struct PanelView: View {
    enum Tab {
        case breakers, add
    }

    @StateObject private var store = SkillStore()
    @StateObject private var discovery = DiscoveryStore()
    @State private var tab: Tab = .breakers

    var body: some View {
        ZStack {
            Theme.wall.ignoresSafeArea()

            VStack(spacing: 0) {
                FaceplateHeader()
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
            store.ensureTesterInstalled()
            discovery.onInstall = { [weak store] name in
                store?.scan()
                store?.message = "\(name) installed and ARMED — it fires in your next Cowork chat."
                NSSound(named: "Pop")?.play()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.scan()
            discovery.refreshInstalled()
        }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            PanelTab(title: "BREAKERS", icon: "switch.2", active: tab == .breakers) { tab = .breakers }
            PanelTab(title: "ADD SKILLS", icon: "plus.circle.fill", active: tab == .add) { tab = .add }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var content: some View {
        Group {
            switch tab {
            case .breakers:
                BreakerBoard(store: store, discovery: discovery) { tab = .add }
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
                store.pressTest()
            } label: {
                Text("TEST")
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(store.tester?.isArmed == true ? AnyShapeStyle(Theme.tapeBlack) : AnyShapeStyle(Theme.inkDark.opacity(0.7)))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(store.tester?.isArmed == true ? AnyShapeStyle(Theme.safety) : AnyShapeStyle(Color.black.opacity(0.08))))
                    .overlay(Capsule().stroke(.black.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
            .help("Arm the circuit tester — it verifies your setup at the start of your next Cowork chat, then trips off")
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
    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("SKILLSWITCH")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(Theme.inkDark)
                    .shadow(color: .white.opacity(0.5), radius: 0, y: 1)
                Text("SKILL LOAD CENTER · MOD. SS-100 · FOR USE WITH CLAUDE COWORK")
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

                    if !store.hardwired.isEmpty {
                        sectionHeader("HARDWIRED", detail: "built into Claude · always on")
                            .padding(.top, 8)
                        ForEach(store.hardwired) { skill in
                            BreakerRow(
                                skill: skill,
                                canUpdate: false,
                                toggle: { store.toggle(skill) },
                                copy: { store.copyInvocation(skill) },
                                update: {},
                                remove: {}
                            )
                        }
                    }

                    if !store.bin.isEmpty {
                        binSection
                    }
                }
                .padding(10)
            }
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

    private var grillMeInstalled: Bool {
        store.circuits.contains { $0.skillId == "grill-me" }
    }

    private var commissioningCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("COMMISSIONING CHECKLIST")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.tapeBlack)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Theme.safety))
                Spacer()
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

            checklistRow(
                number: "1", done: grillMeInstalled,
                text: "Wire up grill-me — the interviewer that sharpens any plan."
            ) {
                Button {
                    store.message = "Installing grill-me…"
                    Task {
                        await discovery.install(DiscoverySkill(
                            source: "mattpocock/skills", skillId: "grill-me",
                            installs: 0, isOfficial: false
                        ))
                        try? CoworkEnvironment.locate()?.disarm(skillId: "grill-me")
                        store.scan()
                        store.message = "grill-me is on the panel — leave it OFF for now."
                    }
                } label: { checklistButton("INSTALL") }
                .buttonStyle(PressStyle())
            }

            checklistRow(
                number: "2", done: store.tester?.isArmed == true,
                text: "Press TEST, then open a Cowork chat and say hi. The tester checks your wiring and trips off."
            ) {
                Button { store.pressTest() } label: { checklistButton("TEST") }
                    .buttonStyle(PressStyle())
            }

            checklistRow(
                number: "3", done: false,
                text: "Flip grill-me's breaker, open a fresh Cowork chat, and start something ambitious. Get grilled."
            ) {
                Button {
                    withAnimation { commissioned = true }
                } label: { checklistButton("DONE") }
                .buttonStyle(PressStyle())
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.breaker))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Theme.safety.opacity(0.55), lineWidth: 1)
        )
    }

    private func checklistRow(number: String, done: Bool, text: String, @ViewBuilder action: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(done ? "✓" : number)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(done ? Theme.liveGreen : Theme.safety)
                .frame(width: 14, height: 14)
                .background(Circle().fill(.black.opacity(0.4)))
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(done ? 0.45 : 0.8))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if !done { action() }
        }
    }

    private func checklistButton(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
            .tracking(1)
            .foregroundStyle(Theme.tapeBlack)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.safety))
            .overlay(Capsule().stroke(.black.opacity(0.4), lineWidth: 1))
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
    let canUpdate: Bool
    let toggle: () -> Void
    let copy: () -> Void
    let update: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            RockerSwitch(isOn: skill.enabled, hardwired: skill.isHardwired, action: toggle)

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
                Text(skill.sourceLabel.uppercased())
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
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
        guard skill.enabled else { return Theme.offRed.opacity(0.55) }
        return skill.isArmed ? Theme.safety : Theme.liveGreen
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
                        if hardwired {
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
        .help(hardwired
            ? "Built into Claude — always on"
            : (isOn ? "ARMED — fires once at the start of your next Cowork chat, then trips off. Click to disarm."
                    : "OFF — click to arm for your next chat"))
    }

    private var paddleColor: Color {
        if hardwired { return Theme.deadGray }
        return isOn ? Theme.safety : Theme.offRed
    }
}
