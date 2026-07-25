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

### Ownership, governors, and authority

Ownership and operational control are separate relationships. An entity such
as a Facility, Trade Hub, party, settlement, or future MarsKolony installation
may be owned by an actor, organisation, polity, or other principal while being
operated by a different governor.

- `owner_id` answers who possesses or ultimately benefits from the entity.
- `governor_actor_id` identifies its direct operational decision maker.
- A governor may manage multiple entities and may be human-controlled,
  deterministic code, an AI policy, or an LLM-assisted actor.
- A governor may have an optional explicit `superior_actor_id`. Root governors
  have no superior.
- Roles and authority scopes determine which commands a governor or superior
  may issue. Ownership alone does not grant an implicit command bypass.
- Delegation, temporary substitution, and exceptional issuers must be explicit
  authority records rather than hard-coded social layers.

Small organisations may assign several roles and Facilities to one actor.
Larger organisations may use an arbitrary superior chain. Setting-specific
roles such as mayor, quartermaster, guild master, colony governor, or chief
engineer are configuration over this generic model, not engine-level classes.

Authority and communication are separate. Permission to issue a command does
not make that command reach a remote subordinate instantly; delivery must use
an available physical or communications mechanism.

### Scheduled domain work

World Clock owns deterministic time and an ordered queue of serializable
scheduled-event intents. It does not contain Facility logic or call opaque
callbacks. When an intent becomes due, WorldSim dispatches it to the component
that owns the referenced entity through a typed handler.

A Facility production cycle follows this pattern:

```text
facility created or resumed
    -> schedules FacilityProductionTickDue
    -> World Clock reaches due time
    -> WorldSim dispatches the due intent to Facilities
    -> Facility validates current state and applies one deterministic cycle
    -> Facility returns domain events and an optional next-tick intent
    -> WorldSim records events and schedules the next intent
```

The queued item says that work is due; the resulting
`FacilityProductionTicked` domain event says what actually happened. Keeping
these distinct supports cancellation, pause/resume, save/load, deterministic
replay, and explicit failures without embedding component behavior in the
clock.

World Clock never reorders due work by gameplay category. Scheduling order is
causal order: if consumption is due before an arrival, it sees no arrived
goods. The consumer may schedule a later retry, but the arrival cannot
retroactively alter the completed consumption attempt.

The active TypeScript foundation implements this boundary in `world-clock.ts`,
`governance.ts`, `facilities.ts`, and the thin `simulation-foundation.ts`
dispatcher composed into canonical `WorldSimulation`. Clock snapshots retain
the complete event lifecycle; Facility snapshots retain generation/idempotency
state and cohort-level host state. Operational pause/resume decisions enter
through an authority-checked command; automatic ticks remain previously
configured domain work.

### Local Trade Hub settlement

Each Trade Hub owns a location-bound inventory, local accounts, escrow, and an
order book. Deposits and withdrawals cross the normal physical transfer
boundary: Facilities may supply only explicitly connected hubs, while parties
must be present at the hub node and have the required cargo or free capacity.
Moving goods between hubs therefore requires a physical carrier and normal
travel commands.

Orders reserve only goods or abstract currency already deposited in that hub.
Matching is deterministic by explicit price and stable placement sequence;
full and partial fills are atomic. Expiry is a serializable World Clock intent,
so matching and expiry at the same instant follow actual scheduling order, not
event-type priority. Governance authorizes transfer, order, and cancellation
commands but does not imply communication, memory, or global market knowledge.

### Private WorldMemory

WorldMemory is an append-ordered, owner-scoped knowledge component. WorldSim
adjudicates local physical observations and writes bounded entries with
provenance plus observed-at and known-at simulation times. Queries require the
owner kind and id and derive explicit freshness without mutating historical
entries.

Deterministic AI receives only its private WorldMemory view, directly managed
party state, and immediate local affordances. It proposes normal
`WorldCommandEnvelope` commands, which remain subject to physical validation
and Governance. Neither authority nor a shared textual identifier transfers
knowledge between actors, parties, locations, or remote Trade Hubs.

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
