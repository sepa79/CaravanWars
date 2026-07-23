# Travel Intent Command

## Purpose

`TravelIntentCommand` is the first higher-level travel intent. It asks the authoritative simulation to move a party to a known destination, while the server resolves the route through the party's known routes.

This is the command shape future UI, voice, LLM, AI, and multiplayer clients should prefer for "go to this place" actions. `MovePartyCommand` remains the lower-level adjacent-edge command.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: local singleplayer client, future multiplayer clients, AI controllers, patrol/city/faction controllers.

## Command shape

```json
{
  "party_id": "player_party",
  "destination_node_id": "raciborz"
}
```

## Validation rules

The authoritative simulation rejects the command when:

- `party_id` does not exist,
- the party is already traveling,
- `destination_node_id` is not present in the region graph,
- the party does not know the destination node,
- the party is already at the destination,
- no route exists through routes currently known by the party.

Rejected commands return a `CommandResult` with `accepted=false`, an explicit `error_code`, and a message. Rejected commands must not mutate party travel state.

## Path resolution

The server resolves a deterministic shortest-distance path through the party's runtime knowledge:

- every traversed edge must be in `party.knowledge.known_edge_ids`,
- every traversed node must be in `party.knowledge.known_node_ids`,
- hidden graph routes must not be used even if they exist in server state.

Accepted commands store the resolved path on party state and immediately start the first leg. Simulation ticks advance one active leg at a time. On arrival at an intermediate node, the server starts the next planned leg. On arrival at the intent destination, the plan is cleared.

## Runtime events

Accepted intent commands emit:

- `party_travel_intent_started`

Each leg emits the existing:

- `party_travel_started`
- `party_arrived`

Completed plans emit:

- `party_travel_intent_completed`

If a previously accepted plan becomes internally inconsistent during runtime, the server emits `party_travel_intent_failed` and clears the plan.

## Test coverage

Covered by `game/tests/TravelIntentCommandTest.gd`:

- known multi-leg intent starts and completes,
- unknown destination is rejected,
- known destination without known path is rejected,
- client destination listing includes reachable non-neighbor destinations.
