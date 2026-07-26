# Simulation Save v0

## Purpose

`Simulation Save v0` is the first canonical save snapshot for the authoritative simulation. It is a dictionary/JSON-shaped contract, not yet a full save-slot UI or file management system.

The snapshot exists so `new game`, `load game`, tests, and future WorldMemory session binding can share one explicit state boundary.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: local singleplayer client, debug tools, future save-slot UI, future service/session orchestration.

## Shape

```json
{
  "schema_version": 0,
  "current_day": 1.0,
  "region_graph_id": "silesia",
  "parties": [],
  "locations": [],
  "runtime_event_log": [],
  "player_map_state": {}
}
```

`parties` stores the current `PartyState.to_dictionary()` shape, including:

- party identity and type,
- manager actor id,
- authorized issuer actor ids,
- current node,
- active travel state,
- active travel intent destination,
- planned path node/edge ids,
- assigned/active party order,
- active or recently completed party task,
- active or recently completed actor tasks,
- composition,
- cargo,
- runtime party knowledge.

`runtime_event_log` stores the current in-run event log. It is useful for debug continuity, but it is not durable WorldMemory.

`locations` stores physical managed locations and their resource state.

The active TypeScript scheduled-domain snapshot additionally stores one
canonical World Clock snapshot (elapsed time, next scheduling sequence, and all
pending/cancelled/completed/failed scheduled records), Governance state,
Facility state, host inventories, cohort aggregates, Trade Hub inventories,
accounts, escrow, order books, idempotency ledgers, and emitted foundation
events. `WorldSimulation` embeds only the foundation domain snapshot beside its
top-level clock, avoiding a duplicated clock contract. The standalone
`SimulationFoundationSnapshot` includes the clock for component save/load and
deterministic continuation tests.

The active TypeScript snapshot also stores the canonical WorldMemory snapshot:
next append sequence, private entries, and processed-ingest fingerprints.
WorldMemory JSON load validates deterministic ids, owner scope, provenance,
timestamps, payload serialization, and idempotency records.

`player_map_state` is reserved for the future player-drawn parchment map journal. It is intentionally empty in v0. The region graph remains the source of truth; player map state is presentation/memory state.

## New game

`GameSessionFactory.create_new_game_server()` creates a fresh authoritative local simulation:

- loads the configured region graph,
- loads party travel config,
- loads party cargo config,
- sets `current_day` to `0.0`,
- adds the starting player party,
- adds initial managed locations.

Singleplayer still uses the same server and command model as future multiplayer.

## Load rules

`SimulationSaveCodec.load_from_dictionary()` rejects snapshots when:

- required root fields are missing,
- `schema_version` is not exactly `0`,
- `region_graph_id` does not match the loaded graph,
- party entries are malformed,
- party entries are missing `authorized_issuer_actor_ids`,
- party entries are missing `task`,
- party entries are missing `actor_tasks`,
- party cargo references unknown goods, negative quantities, or exceeds composition-derived capacity,
- location entries are malformed,
- party current/origin/destination/path nodes do not exist,
- party order target locations or goods ids do not exist,
- party task locations or goods ids do not exist,
- actor task locations or goods ids do not exist,
- actor task party ids do not match the containing party,
- location nodes do not exist,
- party known/path route ids do not exist.

No compatibility fallback or graph substitution is allowed in v0.

## Compatibility notes

No backward compatibility is required during this reboot. Future schema changes must increment `schema_version` and document migration behavior explicitly.

## Test coverage

The active TypeScript Trade Hub integration round-trips its foundation snapshot
through JSON and proves identical matching, expiry, balances, and event order
after continuation from the loaded state.

Active TypeScript coverage in
`packages/world-sim/test/simulation-foundation.test.ts` proves JSON round-trip
save/load with pending retry intents, Facility generation/idempotency state,
inventory, cohorts, event history, and identical deterministic continuation.
Shortage policies and active Facility/cohort episode keys are part of that
snapshot. Supply assignments, results, and reports are owner-scoped WorldMemory
entries, so their command ids, provenance, order, and replay state use the
canonical WorldMemory snapshot rather than a parallel task save.

Autonomous Regional Economy v1 also snapshots its typed config,
LogisticsTaskBoard, decision sequence, action ordinals, per-Governor append-log
observation cursors, and party route-observation ids. These are required for
identical continuation and are never reconstructed heuristically.

Legacy evidence remains covered by `game/tests/SimulationSaveCodecTest.gd`:

- new game creates the expected start state,
- save/load preserves day, party state, knowledge, active travel intent, and runtime events,
- save/load preserves location state,
- bad schema version is rejected,
- unknown region graph id is rejected.
