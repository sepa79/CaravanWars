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
- composition,
- cargo,
- runtime party knowledge.

`runtime_event_log` stores the current in-run event log. It is useful for debug continuity, but it is not durable WorldMemory.

`locations` stores physical managed locations and their resource state.

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
- party cargo references unknown goods, negative quantities, or exceeds composition-derived capacity,
- location entries are malformed,
- party current/origin/destination/path nodes do not exist,
- party order target locations or goods ids do not exist,
- location nodes do not exist,
- party known/path route ids do not exist.

No compatibility fallback or graph substitution is allowed in v0.

## Compatibility notes

No backward compatibility is required during this reboot. Future schema changes must increment `schema_version` and document migration behavior explicitly.

## Test coverage

Covered by `game/tests/SimulationSaveCodecTest.gd`:

- new game creates the expected start state,
- save/load preserves day, party state, knowledge, active travel intent, and runtime events,
- save/load preserves location state,
- bad schema version is rejected,
- unknown region graph id is rejected.
