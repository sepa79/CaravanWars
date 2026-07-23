# ADR-002 - Node, TypeScript, and Electron migration

## Status

Accepted on 2026-07-23.

## Context

The Godot reboot proved the server-authoritative command/state model, seeded the
Silesia region graph, and produced a useful parchment-map prototype. It also made
iteration expensive: domain logic, tests, debug tooling, and presentation all
depend on the engine runtime even though most of the game is a deterministic
simulation and service orchestration problem.

Separate SkippyBot prototypes have already exercised reusable Node-based domain
components for Facilities, World Clock, and Trade Hubs. CaravanWars also has a
stateful WorldMemory service. These components should converge behind explicit
contracts instead of being rebuilt inside another engine-specific gameplay path.

## Decision

- The new CaravanWars host uses Node.js 22+ and strict TypeScript.
- The player client is developed browser-first with Canvas 2D for the map.
- Electron is a thin desktop shell added after the browser slice works.
- WorldSim remains server-authoritative and owns physical world state,
  authorization, command validation, and accepted state transitions.
- Singleplayer remains a local server plus local client using the same commands
  and snapshots intended for future multiplayer transport.
- Facilities, World Clock, and Trade are reusable domain components with no
  CaravanWars presentation dependency.
- WorldMemory remains a separately owned stateful service with a canonical API.
- The region graph remains simulation truth. Parchment maps remain presentation
  artifacts derived from actor-visible information.
- The Godot implementation remains migration evidence until explicit parity
  gates pass. New gameplay is implemented in the TypeScript path.
- Primary development runs on the dedicated Devbox. Other machines connect to
  that environment rather than maintaining divergent working copies.

## Migration method

Migration proceeds through vertical slices, not a line-by-line rewrite:

1. load and validate the Silesia graph,
2. submit a travel command,
3. advance canonical world time,
4. emit arrival/state events,
5. produce an actor-limited client snapshot,
6. render Party Map and Truth Map in Canvas 2D.

Each slice must preserve canonical contracts and add conformance fixtures or
tests before the equivalent Godot path can be retired.

## Component boundaries

### WorldSim

Owns physical entities, authority, command handling, world orchestration, and
client-visible snapshots. UI, AI policies, and services do not mutate its state
directly.

### World Clock

Owns canonical world time and scheduled event lifecycle. It does not interpret
domain event semantics or call domain handlers directly.

### Facilities

Owns deterministic facility state transitions such as inventory, production,
upkeep, workforce, development, and farm cycles. It returns domain events and
future-event intents to WorldSim.

### Trade

Owns Trade Hub instances, orders, escrow, fills, cancellation, and collection.
WorldSim owns physical presence and transport between hubs.

### WorldMemory

Owns durable private knowledge, provenance, observations, and memory transfer.
It does not own physical truth or authorize gameplay commands.

## Parity gates

Godot may be archived after the TypeScript implementation proves:

- deterministic command/event behavior for the current travel slice,
- equivalent graph validation and route knowledge boundaries,
- Party Map and Truth Map feature parity,
- save/load and deterministic replay behavior,
- Facilities integration for the current location economy slice,
- WorldMemory observation integration,
- local Trade Hub settlement with physical inter-hub transport.

## Consequences

- Existing Godot code is reference evidence, not the target extension point.
- Shared components need one canonical implementation and contract each.
- Browser development provides the fast UI loop; Electron packaging cannot own
  gameplay truth.
- A temporary increase in repository size and duplicate behavior is accepted
  only where conformance tests make the migration explicit.
- Rust/native implementations are deferred. A future native backend must obey
  the same contracts and conformance fixtures rather than becoming a second
  source of truth.

## Deferred decisions

- UI component framework around Canvas 2D.
- Electron packaging and update mechanism.
- Final repository/package publishing topology for shared components.
- Whether the current Python WorldMemory implementation is retained or later
  replaced behind its stable API.
