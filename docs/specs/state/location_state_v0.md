# Location State v0

## Purpose

`Location State v0` defines physical managed locations in the authoritative simulation.

A location is an entity anchored to a region graph node, such as a city, stronghold, village, monastery, fort, or camp. It has a manager actor and local resources. It is physical world state, not rumor or memory.

## Shape

```json
{
  "location_id": "wroclaw_city",
  "location_type": "city",
  "manager_actor_id": "mayor_wroclaw",
  "node_id": "wroclaw",
  "resources": {
    "food": 120,
    "coin": 300,
    "horses": 12
  }
}
```

## Initial locations

New game currently creates:

- `wroclaw_city`, managed by `mayor_wroclaw`,
- `opole_stronghold`, managed by `castellan_opole`,
- `nysa_monastery`, managed by `abbot_nysa`.

These are seed entities for early simulation slices, not final economy data.

## Client visibility

`SimulationServer.get_client_snapshot(party_id)` includes `current_locations`.

Only locations at the party's current graph node are included. The client snapshot must not expose every location in the world.

Full server/debug snapshot may include all locations.

## WorldMemory boundary

Location state is physical truth:

- resources,
- manager,
- location type,
- node attachment.

WorldMemory stores who knows or believes something about a location, such as:

- "Opole lacks food",
- "Wroclaw has horses for sale",
- "the abbot keeps coin for repairs".

Memory does not replace location state. Location state does not imply everyone knows it.

## Save/load

`Simulation Save v0` persists locations and validates that each location references an existing region graph node.

## Test coverage

Covered by `game/tests/LocationStateTest.gd`:

- new game contains managed locations,
- client snapshot exposes only the current node's location,
- snapshot updates after travel,
- save/load preserves manager id and resources.
