# Security Policy

SkillSwitch edits Claude Cowork's local skills manifest and installs skill
files from GitHub, so security reports get taken seriously and handled fast.

## Reporting

Please report vulnerabilities through
[GitHub's private vulnerability reporting](https://github.com/pardhaponugoti/skillswitch/security/advisories/new)
— not a public issue. You'll get a response within a few days.

## Scope notes for researchers

- Everything is local: no backend, no telemetry, no accounts. The attack
  surfaces that matter are (1) content fetched from skills.sh and GitHub
  during skill installs, and (2) the manifest/description-rewriting
  mechanism ("arming").
- Skill installs are staged, size-capped, path-traversal-checked, and
  charset-validated; a skill's description is an instruction channel read
  by the model, which is why installs never take descriptions from scraped
  web pages — only from the downloaded SKILL.md.
- Anything that lets a hostile skills.sh page, GitHub repo, or session log
  escalate beyond those boundaries is exactly what we want to hear about.
