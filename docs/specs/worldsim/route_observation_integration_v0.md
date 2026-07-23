# Route observation integration v0

## Purpose

`Route observation integration v0` defines the next main-code integration slice for authored route geometry, terrain areas, and landmarks.

The goal is to move discovery of route details out of the sketch-map prototype and into the server-authoritative runtime observation flow. The sketch map may remain a lab for presentation, but the main simulation should become the source of route, terrain, and landmark observations.

## Current baseline

The project already has:

- authored physical layers in `data/regions/silesia.json`,
- typed graph loading for `terrain_areas`, `landmarks`, and edge `geometry`,
- `RegionRouteWaypoint` with `position`, `distance_from_start_km`, `elevation_m`, `travel_time_modifier`, `terrain_area_ids`, `landmark_ids`, and `landmark_tags`,
- `WorldSimObservationService` for owner-specific observations,
- `WorldMemoryEventMapper` for exporting selected runtime events,
- a sketch-map prototype that can draw observed physical layer marks.

## Integration rule

Do not make the sketch-map prototype the authority.

Route geometry, terrain, and landmarks are simulation data. Player map marks should eventually be produced from runtime observations. Prototype helpers such as `reveal_physical_layers_near()` are temporary presentation scaffolding and should not become the long-term discovery model.

## V0 event

Add a runtime event named:

```text
worldsim_route_waypoint_observed
```

Suggested event subject:

```text
party
```

Suggested summary:

```text
Party {observer_party_id} observed route waypoint {waypoint_id}.
```

Suggested metadata:

```json
{
  "observer_party_id": "player_party",
  "owner_id": "player_party",
  "edge_id": "wroclaw_opole",
  "from_node_id": "wroclaw",
  "to_node_id": "opole",
  "waypoint_id": "wroclaw_opole_old_willow_ford",
  "waypoint_kind": "ford",
  "distance_from_start_km": 25.0,
  "elevation_m": 92.0,
  "terrain_area_ids": ["odra_valley"],
  "landmark_ids": ["old_willow_ford"],
  "landmark_tags": ["odra", "ford", "crossing"],
  "observation_score": 3
}
```

## V0 timing

Do not implement segment-level route progress yet.

For v0, route waypoint observations may be emitted at travel start or arrival for the selected edge. The first implementation should prefer a deterministic and testable point in the current travel flow over fake precision.

Acceptable v0 options:

- emit route waypoint observations when a party starts direct travel along an edge,
- emit route waypoint observations when a party arrives at the destination node,
- emit only for direct edge travel, not for multi-leg route plans unless each leg already starts through the same travel path.

The implementation must not change travel duration, movement validation, party state, or route choice.

## WorldMemory export

Extend `WorldMemoryEventMapper` so `worldsim_route_waypoint_observed` can export owner-specific route memory.

Suggested memory kind:

```text
route_observation
```

The exported metadata should preserve:

- observer/owner party id,
- edge id,
- from/to node ids,
- waypoint id and kind,
- terrain area ids,
- landmark ids,
- landmark tags,
- observation score,
- observed day when available through the existing event shape.

## Tests

Add or extend tests in the main Godot suite.

Minimum test:

1. Create a new game server.
2. Submit direct travel from `wroclaw` to `opole`.
3. Assert the runtime event log contains `worldsim_route_waypoint_observed`.
4. Assert at least one event has:
   - `edge_id == "wroclaw_opole"`,
   - `waypoint_id == "wroclaw_opole_old_willow_ford"`,
   - `terrain_area_ids` containing `odra_valley`,
   - `landmark_ids` containing `old_willow_ford`.
5. Map the event through `WorldMemoryEventMapper`.
6. Assert the exported memory kind is `route_observation` and retains the route/terrain/landmark metadata.

Additional useful test:

- Travel `great_forest -> opole` and assert `black_pine_edge` is observed.

## Out of scope

Do not implement in this slice:

- travel-time modifiers from terrain or route geometry,
- segment-level position/progress,
- off-road travel,
- line-of-sight simulation,
- permanent player map save format,
- full integration of the sketch-map UI into the main game scene.

## Follow-up slices

After this integration slice:

1. Add map-journal state that consumes route/landmark observations and stores player-visible `map_marks`, `map_paths`, and `map_areas`.
2. Move stable sketch-map rendering pieces toward `game/map/`.
3. Add segment-level travel state only when interruption recovery, encounters on roads, or travel-time modifiers require it.
