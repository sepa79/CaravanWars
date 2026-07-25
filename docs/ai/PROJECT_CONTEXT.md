# Project Context - CaravanWars

## Purpose

CaravanWars is a server-authoritative caravan, trade, travel, rumor,
settlement, and conflict simulation. The active reboot uses Node.js and strict
TypeScript with a browser-first client and a thin future Electron shell.

## Current state

- The canonical GitHub history is preserved.
- Both Godot implementations are archived under `archive/`.
- The authored Silesia graph is active under `data/regions/silesia.json`.
- `packages/world-sim` loads and validates the region graph with explicit
  failures and conformance tests.
- Deterministic travel, World Clock, Truth Map, actor-filtered Party Map, route
  observations, physical cargo/location economy, and the first memory-bounded
  merchant AI vertical slice are active in TypeScript.
- World Clock scheduled intents, generic Governance, and deterministic
  Facilities are active with save/load and a cohort-based shortage integration
  fixture.
- Trade Hub v0 is active with per-location physical inventory, local accounts,
  escrowed buy/sell orders, deterministic matching and expiry, and party-based
  transport between independent hubs.

## Non-negotiable model

- Singleplayer and multiplayer share one command and state model.
- Every physical or managerial actor uses the same command interface.
- WorldSim owns physical truth; clients receive filtered snapshots.
- The region graph is truth; parchment maps are presentation artifacts.
- Facilities, World Clock, Trade Hubs, and WorldMemory are separate reusable
  components with explicit contracts.
- Trade Hubs are instances connected to specific Facilities, never a global
  virtual inventory.
- WorldMemory owns durable actor-specific knowledge; WorldSim owns observation
  adjudication.

## Active paths

| Path | Purpose |
|---|---|
| `packages/world-sim` | Authoritative TypeScript simulation core |
| `data/regions` | Canonical region graph data |
| `data/simulation` | Explicit simulation configuration |
| `docs/architecture` | Architecture boundaries |
| `docs/specs` | Behavioral contracts and conformance targets |
| `archive/godot-legacy` | Original Godot code and evidence |
| `archive/godot-reboot` | Godot reboot and map prototype evidence |

## Development and deployment

Development runs on the Devbox with Node.js 22+. Use `npm ci`,
`npm run typecheck`, and `npm test`. No active deployment pipeline exists yet.
Electron packaging comes after the browser client is useful.

## Risks

- Accidentally importing active code from an archive.
- Diverging local singleplayer behavior from multiplayer behavior.
- Exposing hidden coordinates or global state through client snapshots.
- Duplicating command/schema definitions between components.
- Treating Trade Hubs as shared inventories instead of physical instances.
- Allowing LLM output to bypass command validation.

## Do not guess

- Do not invent gameplay values when configuration or contracts own them.
- Do not add fallback behavior for missing data or unavailable components.
- Do not introduce a second authoritative state model.
- Do not equate `Party` with caravan; composition and role define capability.
- Do not treat archived Godot class names as active TypeScript boundaries.
