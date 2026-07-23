# Project Context - CaravanWars Reboot

## Purpose

CaravanWars Reboot is a Godot 4 restart of CaravanWars focused on a server-authoritative caravan, trade, travel, rumor, and conflict simulation.

Durable direction decisions are recorded in `docs/adr/ADR-001-project-direction.md`. AI agents should read it when a task touches simulation architecture, memory, hierarchy, route geometry, maps, economy, orders, or LLM/voice boundaries.

## What this project does

The project models a world as region graphs connected by passages and known routes. The region graph is the simulation source of truth; parchment-style maps are presentation artifacts. Current code seeds a Silesia high-level region graph and typed GDScript loader/smoke test. The gameplay architecture must allow singleplayer and multiplayer to use the same command and state model.

## What this project does not do

- It does not use a separate singleplayer gameplay path.
- It does not treat one giant visual world map as the simulation model.
- It does not manually edit Godot scene/resource files outside the editor.
- It does not preserve backward compatibility during this reboot unless explicitly requested.

## Main users / operators

- Players running the Godot game.
- Developers and AI agents evolving the simulation, data, and tooling.
- Future multiplayer hosts/servers that run authoritative simulation state.

## Main modules

| Module | Purpose | Notes |
|---|---|---|
| `game/` | Godot project root | Contains `project.godot`, scripts, tests, and data. |
| `game/world/` | Region graph model and loader | Typed GDScript classes for graph nodes, edges, and loading. |
| `game/data/regions/` | Region graph data | JSON region definitions, currently Silesia. |
| `game/tests/` | Godot smoke tests | Current graph loader smoke test. |
| `docs/architecture/` | Deeper architecture notes | Server-authoritative model. |
| `docs/reboot/` | Reboot planning notes | Navigation and Codex reboot notes. |
| `tools/` | Repo checks | Windows and Unix-like check entry points. |

## Runtime model

Godot runs the game from `game/`. The intended runtime model is local server plus local client for singleplayer, and the same authoritative simulation command/state model for multiplayer. Tests are run through Godot headless where available.

## Deployment model

The project currently has no deployment pipeline. The expected artifact is a Godot game build once export presets and platform targets are defined.

## Data/storage model

Current simulation seed data is file-backed JSON under `game/data/regions/` and `game/data/simulation/`. Hidden world coordinates, graph nodes, route waypoint chains, landmarks, party composition, runtime party knowledge, and travel state are simulation data. Future save/network state must follow the server-authoritative command and state model.

Runtime party knowledge in Godot is only a client visibility boundary. Important long-lived world memory belongs in the separate WorldMemory service backed by SQLite and exposed through its own API.

## External integrations

None are defined yet.

## Important risks

- Diverging singleplayer and multiplayer logic.
- Treating UI maps as authoritative world data.
- Ad hoc route/travel formats instead of canonical graph specs.
- Hard-coding caravan-only logic instead of using neutral party state and composition.
- Letting UI/client code read full server graph truth instead of party-visible knowledge.
- Accidentally turning Godot runtime knowledge into durable WorldMemory.
- Untyped or loosely typed GDScript spreading through core simulation.
- Manual `.tscn` or `.tres` edits corrupting Godot resources.

## Things AI agents must not guess

- Do not guess gameplay data values; use current config or code.
- Do not invent network, save, or command contracts without a spec.
- Do not add fallback behavior to hide missing data.
- Do not assume a scene/resource edit can be safely made as text.
- Do not treat `Party` as synonymous with caravan; party type/composition should carry identity and capabilities.
- Do not implement durable WorldMemory in GDScript; integrate with the external SQLite-backed service when that API exists.
