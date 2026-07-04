# SkillSwitch

**A breaker panel for your Claude.** Skills are invisible — nobody uses tools they can't see. SkillSwitch is a small macOS app that sits next to Claude Cowork and shows every skill on your machine as a switch on an electrical panel. Arm a breaker and the skill fires at the start of your next conversation — then the breaker trips off, ready for next time. No terminal, no config files, no tmux.

Inspired by [Shift](https://www.shiftcc.app/) — the stick shift for Claude Code models.

## How it works

- **Breakers** — every skill in Cowork's own skills list gets a rocker switch. SkillSwitch reads and writes the manifest Cowork actually loads from (`~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/…/manifest.json`). Flipping a circuit ON **arms** it: the skill is enabled and its description gets a fire-now instruction, so your next Cowork chat invokes it right at the start. Once it fires, SkillSwitch notices (it watches Cowork's session logs) and the breaker **trips** back off — armed skills are one-shots. Skills that ship with Cowork appear as **hardwired** circuits (always on).
- **Add Skills** — a discovery shelf preloaded from [skills.sh](https://www.skills.sh/) with every skill above 50k installs (mirror sources deduped, sorted by popularity, searchable). One click downloads the skill from its GitHub repo into Cowork's skills folder and registers it in the manifest as a user skill (`creatorType: "user", syncManaged: false` — the shape Cowork's sync explicitly preserves), armed and ready to fire in your next chat. Click a row to unfold its description (fetched on demand from its skills.sh page) with a link to the page itself.
- **Labels** — click a skill's label to copy its `/name` invocation; in Cowork you can paste it, or just ask for the skill in plain English.

Flips apply to your next Cowork conversation (a running chat keeps the skills it started with). If a chat never uses an armed skill, the breaker simply stays armed for the chat after that.

## Install

Grab `SkillSwitch.dmg`, drag SkillSwitch to Applications, done. (Build it yourself with `./build-app.sh && ./tools/make-dmg.sh`.)

SkillSwitch is distributed directly rather than through the Mac App Store: App Store apps are sandboxed and can't touch Cowork's skills manifest, which is the whole point of the app. Release builds are signed and notarized (`./tools/release.sh`, needs an Apple Developer ID) so Gatekeeper opens them without complaint.

## Requirements

- macOS 14+
- The Claude desktop app, signed in, with a Cowork chat opened at least once (that's what creates the skills manifest)

## Development

```sh
swift build          # compile
swift run            # run from the CLI
./build-app.sh       # assemble build/SkillSwitch.app (regenerates Assets/AppIcon.icns if missing)
./tools/make-icns.sh # redraw the app icon (tools/make-icon.swift is the source of truth)
./tools/make-dmg.sh  # package build/SkillSwitch.dmg
./tools/release.sh   # sign + notarize + DMG (needs a Developer ID certificate)
```

The website lives in `docs/index.html` (GitHub Pages–ready).

## Architecture

- `CoworkEnvironment` — finds the signed-in account's skills-plugin folder and does all manifest I/O. JSON is read and written with `JSONSerialization` (not `Codable`) so fields SkillSwitch doesn't know about survive the round trip, and every write is atomic (Cowork quarantines a manifest it can't parse).
- `SkillScanner` — turns manifest entries into breakers: `creatorType: "user"` entries are flippable circuits, everything else is hardwired.
- `SkillToggler` — ON arms (enables the skill and prepends the fire-now instruction to its description — the description is what Cowork's model reads, so that's the auto-invoke lever); OFF disarms and restores the original description.
- `TripScanner` — tails Cowork's per-session `audit.jsonl` logs (incremental byte offsets, newline-safe) for a `Skill` tool-use of an armed skill; the store polls it every 4s and trips the breaker on a hit.
- `DiscoveryStore` — parses the skills.sh homepage leaderboard payload, filters to GitHub-installable sources with ≥50k installs, downloads via the GitHub trees API (`HEAD` ref, so any default branch works) into a staging dir, swaps it into Cowork's skills folder, then registers the manifest entry.
- `PanelView` / `DiscoveryView` — the SwiftUI electrical panel.

## License

[MIT](LICENSE)
