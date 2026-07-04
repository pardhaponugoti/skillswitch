# The `env` frontmatter convention for skills

Skills often need API keys, but SKILL.md has no standard way to say which
ones. Every skill README invents its own prose ("export FOO in your shell"),
and no tool — human or agent — can reliably tell what a skill requires,
what's optional, and what's an either/or choice.

This convention adds one field to SKILL.md frontmatter:

```yaml
---
name: last30days
description: Research what people say about any topic in the last 30 days.
env:
  - name: EXA_API_KEY
    require: one-of search
    purpose: Search provider
    url: https://dashboard.exa.ai/api-keys
  - name: BRAVE_API_KEY
    require: one-of search
    purpose: Search provider
    url: https://api-dashboard.search.brave.com
  - name: SERPER_API_KEY
    require: one-of search
    purpose: Search provider
    url: https://serper.dev/api-keys
  - name: OPENAI_API_KEY
    require: always
    purpose: Summarization
    url: https://platform.openai.com/api-keys
  - name: APIFY_API_TOKEN
    require: optional
    purpose: TikTok results
    url: https://console.apify.com
---
```

## Fields

Each entry under `env:`:

| Field | Required | Meaning |
|---|---|---|
| `name` | yes | The environment variable, exactly as the skill's code reads it |
| `require` | no | `always`, `optional` (default), or `one-of <group>` |
| `purpose` | no | One human-readable line: what this key unlocks |
| `url` | no | Where a person gets one |

## Requirement semantics

A skill's environment is **satisfied** when:

1. every `always` variable is set, and
2. for each distinct `one-of` group name, at least one member variable is set.

`optional` variables never block anything — they unlock extras.

Group names after `one-of` are arbitrary labels (`search`, `llm`, …); a
skill may have several independent groups.

## Who reads it

- **Setup UIs** (like [SkillSwitch](https://skillswitch.cc)) render exactly
  the right form: required fields, pick-one groups, optional extras — with
  links to get each key.
- **Agents** see frontmatter at skill-load time, so the model itself knows
  what's missing and can say so precisely instead of failing mid-task.
- **Anything else** — the field is plain YAML; unknown-field-tolerant
  parsers ignore it, so adding it never breaks an existing loader.

## For tools that scan code instead

Absent an `env` declaration, tools fall back to grepping for
`*_API_KEY`-shaped reads — which finds vocabulary, not meaning. Declare the
field and your users get real setup instead of guesses.
