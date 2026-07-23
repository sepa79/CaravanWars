# Inspect Local Routes Command

## Purpose

`InspectLocalRoutesCommand` lets an idle party check immediate local route options from its current graph node. It is a server-authoritative command that updates runtime party knowledge only.

This is not long-range scouting and does not represent sending scouts away from the party. It covers local inspection, asking nearby people, checking visible roads, and confirming practical options from the current place.

This command does not write durable WorldMemory. Long-lived knowledge, history, and learned world facts belong in the external WorldMemory service with SQLite storage and its own API.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: debug UI, future player intent/voice layer, AI controllers.

## Command shape

```json
{
  "party_id": "player_party"
}
```

## Validation rules

The authoritative simulation rejects the command when:

- `party_id` does not exist,
- the party is already traveling.

Rejected commands return `CommandResult.accepted=false` with an explicit `error_code`.

## State transition

Accepted commands:

1. Inspect all region graph edges adjacent to the party's current node.
2. Add those edge ids to runtime party knowledge.
3. Add both endpoint node ids for each discovered edge to runtime party knowledge.
4. Return discovery counts in `CommandResult.details`.

## Result details

```json
{
  "discovered_edge_count": 3,
  "discovered_node_count": 2
}
```

Counts report newly discovered items only. Inspecting the same node twice should be accepted but may return zero newly discovered routes.

## Test coverage

Covered by `game/tests/PartyKnowledgeSnapshotTest.gd` and `game/tests/DebugTravelPanelTest.gd`:

- initial client snapshot hides unknown local routes,
- local route inspection reveals hidden local route options,
- local route inspection while traveling is rejected,
- debug panel check button reveals new route buttons.
