RULES_ALWAYS_READ
=================

1. Technology and style
- The active migration target is Node.js 22+, strict TypeScript, browser-first Canvas UI, and a thin Electron desktop shell.
- New runtime code under `apps/` and `packages/` must use strict TypeScript and explicit public boundary types.
- Godot 4.x and typed GDScript are legacy/reference technology during migration. Do not add new gameplay paths there unless required for parity evidence or an explicitly approved fix.
- For legacy GDScript, declare types for variables, parameters, and return values.
- Do not use Python idioms in GDScript names or comments.
- Do not use the `?:` operator in GDScript. Use `value_if_true if condition else value_if_false`.
- Do not edit `.tscn` or `.tres` manually. Use Godot for legacy scene/resource files.
- Use 4 spaces, UTF-8, LF, and a newline at end of file unless an existing formatter owns the file.

2. Architecture
- Server-authoritative simulation is mandatory from the start.
- Singleplayer is a local server plus local client, not a separate gameplay path.
- Player caravans, bandit bands, city authorities, patrols, AI agents, and future human-controlled roles must all use the same command interface.
- Parchment maps are presentation artifacts. The region graph is the source of truth.
- Hidden world coordinates, graph nodes, route waypoint chains, landmarks, and travel state are simulation data.
- Avoid one giant world map. Use region graphs connected by passages and known routes.

3. Godot naming
- Directories use `lower_snake_case`.
- Scenes and scripts use `PascalCase.tscn` / `PascalCase.gd`.
- Classes use `PascalCase`.
- GDScript variables and functions use `lower_snake_case`.
- Avoid names that shadow Godot APIs, including `show`, `hide`, `ready`, `process`, `physics_process`, `input`, `unhandled_input`, `enter_tree`, `exit_tree`, `duplicate`, `free`, `queue_free`, `update`, `draw`, `play`, `stop`, `scale`, `seed`, and `params`.

4. Data and localization
- Do not guess data values. Use values defined in current config or current code.
- No backward compatibility is required during this reboot.
- UI text must eventually go through i18n keys. Early data-only code may avoid UI entirely.

5. Process
- Keep changes scoped.
- Use Conventional Commits when committing.
- Update `CHANGELOG.md` for meaningful project changes.
- Do not commit secrets.
- Do not commit binary files without an explicit asset decision.
