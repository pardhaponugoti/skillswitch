import SwiftUI

struct DiscoveryView: View {
    @ObservedObject var store: DiscoveryStore
    @State private var expandedIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 7)
            authorChips
                .padding(.horizontal, 10)
                .padding(.bottom, 9)

            if store.isLoading && store.skills.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking skills.sh…")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.errorMessage, store.skills.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(error)
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.6))
                    Button("Try Again") {
                        Task { await store.load() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 7) {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8))
                            Text("MOST-INSTALLED SKILLS · SKILLS.SH · 50K+ INSTALLS")
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .tracking(1)
                        }
                        .foregroundStyle(Theme.safety.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                        if let error = store.errorMessage {
                            Text(error)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.offRed)
                                .padding(.horizontal, 4)
                        }

                        ForEach(store.filtered) { skill in
                            DiscoveryRow(
                                skill: skill,
                                installed: store.installedNames.contains(skill.skillId),
                                installing: store.installing.contains(skill.id),
                                expanded: expandedIDs.contains(skill.id),
                                description: store.descriptions[skill.id],
                                fetchingDescription: store.fetchingDescriptions.contains(skill.id),
                                install: { Task { await store.install(skill) } },
                                toggle: { toggleExpanded(skill) }
                            )
                        }

                        if store.filtered.isEmpty && !store.skills.isEmpty {
                            Text("Nothing matches “\(store.query)”")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.top, 20)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
            }
        }
        .task { await store.load() }
    }

    private func toggleExpanded(_ skill: DiscoverySkill) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if expandedIDs.contains(skill.id) {
                expandedIDs.remove(skill.id)
            } else {
                expandedIDs.insert(skill.id)
            }
        }
        if expandedIDs.contains(skill.id) {
            Task { await store.loadDescription(for: skill) }
        }
    }

    private var authorChips: some View {
        HStack(spacing: 6) {
            Text("AUTHOR TYPE")
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.35))
            ShelfChip(title: "ALL", active: store.shelf == .all) { store.shelf = .all }
            ShelfChip(title: "USER", active: store.shelf == .user) { store.shelf = .user }
            ShelfChip(title: "ORG · \(store.orgCount)", active: store.shelf == .org) { store.shelf = .org }
            Spacer(minLength: 0)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            TextField("Search skills…", text: $store.query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
            if !store.query.isEmpty {
                Button {
                    store.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.black.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ShelfChip: View {
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(active ? AnyShapeStyle(Theme.tapeBlack) : AnyShapeStyle(.white.opacity(0.6)))
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(
                    Capsule().fill(active ? AnyShapeStyle(Theme.safety) : AnyShapeStyle(Color.white.opacity(0.08)))
                )
                .overlay(Capsule().stroke(.black.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(PressStyle())
        .help(title.hasPrefix("ORG")
            ? "Skills published by companies and organizations"
            : (title == "USER" ? "Skills published by individual people" : "Everything"))
    }
}

struct DiscoveryRow: View {
    let skill: DiscoverySkill
    let installed: Bool
    let installing: Bool
    let expanded: Bool
    let description: String?
    let fetchingDescription: Bool
    let install: () -> Void
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(skill.displayName)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.94))
                                .lineLimit(1)
                            if skill.isOfficial {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.liveGreen.opacity(0.85))
                                    .help("Official — published by the vendor itself")
                            }
                        }
                        HStack(spacing: 6) {
                            Text(skill.source)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 8))
                                Text(skill.installsLabel)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Theme.safety.opacity(0.75))
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: toggle)
                .help(expanded ? "Hide description" : "Show description")

                Spacer(minLength: 8)

                if installed {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("WIRED")
                            .tracking(1)
                    }
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.liveGreen.opacity(0.9))
                } else if installing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(action: install) {
                        Text("INSTALL")
                            .tracking(1)
                            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.tapeBlack)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5.5)
                            .background(Capsule().fill(Theme.safety))
                            .overlay(Capsule().stroke(.black.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            if expanded {
                descriptionSection
                    .padding(.leading, 25)
                    .padding(.trailing, 10)
                    .padding(.bottom, 9)
                    .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.breaker)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if fetchingDescription && description == nil {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Fetching from skills.sh…")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
            } else if let description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No description available.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Button {
                if let url = skill.pageURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 3) {
                    Text("View on skills.sh")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.safety.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }
}
