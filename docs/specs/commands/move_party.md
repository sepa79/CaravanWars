# Move Party Command

## Purpose

`MovePartyCommand` is the first server-authoritative travel command. It moves a neutral `Party` between adjacent nodes in the current region graph.

A party can represent a caravan, pilgrim group, bishop retinue, local lord with escort, bandit band, patrol, or another field group. Travel mechanics must not depend on a specialized caravan-only type.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: local singleplayer client, future multiplayer clients, AI controllers, patrol/city/faction controllers.

## Command shape

```json
{
  "party_id": "player_party",
  "from_node_id": "wroclaw",
  "to_node_id": "opole"
}
```

## Validation rules

The authoritative simulation rejects the command when:

- `party_id` does not exist,
- the party is already traveling,
- `from_node_id` is not the party's current node,
- either graph node is missing,
- no edge connects `from_node_id` and `to_node_id`.
- the edge exists, but the party does not know that route.

Rejected commands return a `CommandResult` with `accepted=false`, an explicit `error_code`, and a message. Rejected commands must not mutate party state.

## State transition

Accepted commands:

1. Resolve the graph edge between `from_node_id` and `to_node_id`.
2. Verify that the party knows the route.
3. Calculate party travel speed from `PartyComposition` and `party_travel.json`.
4. Set the party travel state to `traveling`.
5. Store origin, destination, route distance, speed, and progress.

Simulation ticks advance travel progress in days. When progress reaches route distance, the party arrives at `to_node_id` and returns to `idle`.

## Party composition

Party composition is data, not a subtype hierarchy. Current fields:

```json
{
  "foot_count": 8,
  "horse_count": 2,
  "wagon_count": 1,
  "pack_animal_count": 1,
  "guard_count": 2
}
```

Current travel speed config lives in:

```text
game/data/simulation/party_travel.json
```

The initial formula is intentionally small:

```text
speed = base_speed + horse_count * horse_bonus - wagon_count * wagon_penalty
speed = max(minimum_speed, speed)
```

Future work can add terrain, weather, road type, burden, morale, fatigue, and skills without changing the command boundary.

## Knowledge boundary

Godot stores only lightweight runtime party knowledge for known nodes/routes. This prevents client snapshots and debug UI from seeing full server graph truth.

Durable world memory is explicitly out of scope for this GDScript layer. It belongs in the separate WorldMemory service with SQLite storage and its own API.

## Test coverage

Covered by `game/tests/PartyTravelCommandTest.gd`:

- valid adjacent move starts travel and arrives after ticks,
- unconnected destination is rejected,
- origin mismatch is rejected,
- busy party is rejected,
- existing but unknown route is rejected,
- wagon-heavy composition is slower than mounted composition.
