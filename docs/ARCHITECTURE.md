# Architecture - CaravanWars

This document is the active architecture source of truth. Historical Godot
implementations live under `archive/` and do not define active module
boundaries.

## Baseline

CaravanWars is a server-authoritative simulation. Singleplayer hosts the same
authoritative server locally that multiplayer will host remotely. Every actor
- player caravan, bandit band, patrol, city authority, deterministic manager,
AI agent, or future human-controlled role - submits commands through the same
interface.

```text
intent/input
    -> command boundary
    -> authoritative WorldSim
    -> events and actor-filtered snapshots
    -> browser client / Electron shell
```

The active runtime targets Node.js 22+ and strict TypeScript. The primary
client is browser-first Canvas; Electron is a thin packaging and desktop
integration layer.

## Source-of-truth boundaries

- `packages/world-sim` owns authoritative world state, validation, commands,
  deterministic time advancement, and snapshot production.
- `data/regions` owns authored physical region graphs.
- `data/simulation` owns explicit simulation configuration.
- The region graph is physical truth. Parchment maps are actor-facing
  artifacts derived from knowledge and memory.
- UI and LLM layers may propose commands; they never mutate simulation state.
- Missing or invalid inputs fail explicitly. There are no silent fallback
  chains or heuristic compatibility paths.

## Reusable components

Facilities, World Clock, Trade Hubs, and WorldMemory are independent components
with explicit contracts. They may later become their own packages or services,
but they must not create a second command or state model.

A Facility is a concrete managed capability attached to a physical place or
entity. A Trade Hub is a concrete instance connected to specific Facilities.
Inventory deposited through one Trade Hub instance does not become available
through another instance merely because both share a type or label.

WorldMemory owns durable, actor-specific observations, reports, and rumors.
WorldSim owns physical truth and decides what can be observed. World Clock
provides deterministic simulation time; it does not own gameplay decisions.

## Active repository boundaries

| Path | Responsibility |
|---|---|
| `packages/world-sim` | Active authoritative TypeScript simulation core |
| `data/regions` | Canonical region graph data |
| `data/simulation` | Canonical simulation configuration |
| `docs/specs` | Behavioral contracts and migration conformance targets |
| `archive/godot-legacy` | Original Godot implementation and history |
| `archive/godot-reboot` | Later Godot reboot, map prototype, and history |

Active code must not import from `archive/`. Reusable behavior is promoted by
copying its contract/data into an active boundary and adding conformance tests.

## Migration sequence

1. Load and validate the canonical Silesia region graph in TypeScript.
2. Add deterministic World Clock, travel commands, ticking, and snapshots.
3. Extract Facilities and Trade Hub instance contracts from the SkippyBot
   prototypes.
4. Extract WorldMemory behind its own API and event contracts.
5. Build the browser Truth Map/debug harness, then the actor-facing parchment
   map presentation.
6. Add the thin Electron shell only when browser development flow is stable.

## Required invariants

- Commands are the only gameplay mutation boundary.
- State transitions are deterministic for the same initial state and commands.
- Snapshots reveal only actor-authorized knowledge.
- Contract schemas have one canonical owner.
- Parchment presentation never becomes navigation truth.
- Component outages or invalid data are observable failures, not hidden
  behavior changes.

See `docs/adr/ADR-001-project-direction.md`,
`docs/adr/ADR-002-node-electron-migration.md`, and
`docs/architecture/SERVER_AUTHORITATIVE_MODEL.md`.
