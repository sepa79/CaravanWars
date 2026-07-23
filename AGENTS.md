# AGENTS.md - CaravanWars Reboot

This file defines how AI contributors should work in this repository.

Always read and follow `RULES_ALWAYS_READ.md` before working in this repository.

## Non-negotiable rules

- The server-authoritative simulation is the baseline architecture.
- Singleplayer must use the same command and state model as multiplayer.
- Player caravans, bandit bands, city authorities, patrols, AI agents, and future human-controlled roles must all use the same command interface.
- Parchment maps are presentation artifacts. The region graph is the source of truth.
- Do not add silent fallback chains, heuristic recovery, or implicit compatibility behavior.
- Keep contracts/specs single-source. Do not duplicate schemas, parsers, or command models for the same boundary without a documented reason.
- Keep changes small and scoped. Avoid unrelated refactors.
- Do not edit `.tscn` or `.tres` manually. Use Godot for scene/resource files.
- Do not commit ZIP files or other binary reference packs unless the user explicitly approves a specific asset.
- Do not commit unless the human explicitly asks for a commit. Do not run `git push`.

## Source of truth order

Read in this order:

1. `RULES_ALWAYS_READ.md`
2. `README.md`
3. `docs/ai/PROJECT_CONTEXT.md`
4. `docs/ARCHITECTURE.md`
5. `docs/adr/ADR-001-project-direction.md`
6. `docs/architecture/SERVER_AUTHORITATIVE_MODEL.md`
7. `docs/reboot/WORLD_NAVIGATION_REBOOT.md`
8. `docs/specs/README.md`
9. `docs/ai/COMMANDS.md`
10. `docs/ai/AI_HATS.md`
11. `docs/ai/REVIEW_CHECKS.md`
12. `docs/ai/JESTER_CHECKS.md`
13. `docs/ai/HIVEMIND_RULES.md`

If sources conflict, hard rules in `RULES_ALWAYS_READ.md` and this file win, then project architecture/specs, then implementation evidence. If the conflict still matters, stop and ask.

## GDScript and Godot checks

- Use Godot 4.x typed GDScript.
- Declare types for variables, parameters, and return values.
- Use 4 spaces, UTF-8, LF, and a newline at end of file.
- Avoid names that shadow Godot APIs, as listed in `RULES_ALWAYS_READ.md`.
- Before committing, run `godot --headless --path game --check <modified .gd files>` for every GDScript file you change when available.
- Also run `tools/check.bat` on Windows or `tools/check.sh` on Unix-like shells before committing.

## Working style

Before implementation:

1. Identify scope.
2. Read relevant docs/specs/code.
3. Identify affected contracts and command/state models.
4. Identify tests to run or add.
5. Apply relevant AI hats from `docs/ai/AI_HATS.md`.

During implementation:

- stay inside existing boundaries,
- update docs when behavior, architecture, commands, or risk changes,
- test meaningful behavior, contracts, and failure handling.

Before final response or PR:

- apply Reviewer hat,
- apply Jester hat,
- run relevant checks from `docs/ai/COMMANDS.md`,
- capture command results in the final response or evidence when requested.

## HiveMind

If HiveMind is available:

- start a session for meaningful work,
- search prior lessons/rules before repeating investigation,
- store concise decisions, progress, risks, and lessons,
- do not dump transcripts,
- end the session when work is complete or abandoned.

If HiveMind is not available, use `docs/ai/LESSONS_LEARNED.md` as a fallback only.
