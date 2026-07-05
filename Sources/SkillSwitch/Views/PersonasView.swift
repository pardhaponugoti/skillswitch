import SwiftUI

/// The Personas tab: bundles of skills that make Claude act a certain way.
/// The concept a newcomer already understands — skills come later.
struct PersonasView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var discovery: DiscoveryStore
    @State private var showBuilder = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                explainer

                if !store.personas.isEmpty {
                    header("YOUR PERSONAS", detail: "one flip · whole toolkit")
                    ForEach(store.personas) { persona in
                        PersonaRow(
                            persona: persona,
                            state: store.personaState(persona),
                            energize: { energize(persona) },
                            unplug: { store.unplug(persona) }
                        )
                        .contextMenu {
                            Button("Remove persona (keeps its skills)", role: .destructive) {
                                store.removePersona(persona)
                            }
                        }
                    }
                }

                let available = Persona.starters.filter { starter in
                    !store.personas.contains { $0.id == starter.id }
                }
                if !available.isEmpty {
                    header("STARTERS", detail: "prebuilt · one click")
                        .padding(.top, store.personas.isEmpty ? 0 : 8)
                    ForEach(available) { starter in
                        StarterRow(persona: starter) {
                            store.addPersona(starter)
                            energize(starter)
                        }
                    }
                }

                Button {
                    showBuilder = true
                } label: {
                    Text("+ BUILD YOUR OWN")
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .help("Group skills already on your panel into a named persona")
            }
            .padding(10)
        }
        .sheet(isPresented: $showBuilder) {
            PersonaBuilderSheet(store: store, discovery: discovery)
        }
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("WHAT'S A PERSONA?")
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Theme.safety.opacity(0.9))
            Text("A persona is a bundle of skills that makes Claude act a certain way — a sparring partner, a marketer, an editor. Turn one on and Claude plays that role at the start of your next chat. It fires once, then the switch trips off — turn it on again whenever you want the role back.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.breaker.opacity(0.55)))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func header(_ title: String, detail: String) -> some View {
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

    private func energize(_ persona: Persona) {
        store.message = "Wiring \(persona.name.capitalized)…"
        Task {
            var skippedUnsourced = 0
            for member in persona.members where !store.circuits.contains(where: { $0.skillId == member.skillId }) {
                guard let source = member.source else {
                    skippedUnsourced += 1
                    continue
                }
                await discovery.install(DiscoverySkill(
                    source: source, skillId: member.skillId, installs: 0, isOfficial: false
                ))
            }
            store.scan()
            store.energize(persona)
            store.message = skippedUnsourced > 0
                ? "\(persona.name.capitalized) armed — \(skippedUnsourced) local skill(s) couldn't be reinstalled (no known source)."
                : "\(persona.name.capitalized) is ARMED — Claude plays the role in your next chat, then the switches trip off."
        }
    }
}

/// A prebuilt persona not yet on the user's panel.
struct StarterRow: View {
    let persona: Persona
    let install: () -> Void

    var body: some View {
        HStack(spacing: 10) {
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
                Text(persona.members.map(\.skillId).joined(separator: " · ").uppercased())
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.3))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: install) {
                Text("INSTALL")
                    .tracking(1)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.tapeBlack)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.safety))
                    .overlay(Capsule().stroke(.black.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
            .help("Install its skills and arm them — Claude plays the role in your next chat, then they trip off")
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
}
