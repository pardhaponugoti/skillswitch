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
            discovery.onInstall = { [weak store] name in
                store?.scan()
                store?.message = "\(name) installed and ARMED — it fires in your next Cowork chat."
                NSSound(named: "Pop")?.play()
            }
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
                BreakerBoard(store: store) { tab = .add }
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
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkDark.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Rescan skills")
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
    var addSkills: () -> Void

    var body: some View {
        if !store.coworkFound {
            missingCowork
        } else if store.skills.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    if store.circuits.isEmpty {
                        miniEmptyCircuits
                    } else {
                        sectionHeader("CIRCUITS", detail: "flip to arm · fires once next chat")
                        ForEach(store.circuits) { skill in
                            BreakerRow(skill: skill) {
                                store.toggle(skill)
                            } copy: {
                                store.copyInvocation(skill)
                            }
                        }
                    }

                    if !store.hardwired.isEmpty {
                        sectionHeader("HARDWIRED", detail: "built into Claude · always on")
                            .padding(.top, 8)
                        ForEach(store.hardwired) { skill in
                            BreakerRow(skill: skill) {
                                store.toggle(skill)
                            } copy: {
                                store.copyInvocation(skill)
                            }
                        }
                    }
                }
                .padding(10)
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
    let toggle: () -> Void
    let copy: () -> Void

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
