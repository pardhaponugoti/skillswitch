---
name: circuit-tester
description: SkillSwitch panel diagnostic. Verifies the environment skills actually run in — runtime, network, tools — and reports anything that needs attention.
---

# Circuit Tester

SkillSwitch's TEST button armed this. Run the check exactly once, right now:

1. Execute `bash scripts/health.sh` from this skill's directory. It prints a
   compact report and also writes `skillswitch-health-report.txt` to the
   current working directory.
2. Read the report and give the user a short, friendly summary — one line
   per check with ✅ / ⚠️ icons:
   - runtime (sandbox VM or host, OS)
   - network egress (GitHub reachable — installing skills depends on it)
   - tools (python3, node, git present)
   - write access (skill folder, temp)
3. If everything passed, end with exactly: "🔌 Panel's healthy — every
   circuit checks out." If something failed, say what it breaks in plain
   language and suggest the fix.

Keep the whole summary under 10 lines. Never paste the raw report into chat.
