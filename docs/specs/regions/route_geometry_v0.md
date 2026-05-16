# Route Geometry v0

## Purpose

`Route Geometry v0` is the planned contract for physical route structure inside a region graph edge.

Current route edges are logical connections between important graph nodes. That is enough for early command validation and travel time, but it is too flat for living-world travel. Physical roads need intermediate structure for route progress, travel time modifiers, visibility, encounters, player-drawn maps, and parties meeting on the road.

## Design rule

Do not replace the region graph edge.

The edge remains the logical route contract between major graph nodes. Route geometry lives under the edge as ordered segments or waypoints.

```text
graph node A
  edge A_B
    route waypoint / segment
    route waypoint / segment
    route waypoint / segment
graph node B
```

## Planned edge shape

```json
{
  "id": "wroclaw_opole",
  "from": "wroclaw",
  "to": "opole",
  "distance_km": 80.0,
  "kind": "river_trade_route",
  "geometry": [
    {
      "id": "wroclaw_opole_odra_bend",
      "kind": "river_bend",
      "distance_from_start_km": 24.0,
      "elevation_m": 118,
      "travel_time_modifier": 1.0,
      "landmark_tags": ["odra", "river"]
    },
    {
      "id": "wroclaw_opole_old_bridge",
      "kind": "bridge",
      "distance_from_start_km": 43.0,
      "elevation_m": 120,
      "travel_time_modifier": 1.15,
      "landmark_tags": ["bridge", "crossing"]
    }
  ]
}
```

## Segment vs graph node

Not every physical place should become a graph node.

Graph nodes are strategic or decision locations:

- city,
- village,
- camp,
- bridge or ford when it is a strategic crossing,
- pass,
- fork,
- market or authority location.

Route geometry waypoints are physical details along a route:

- bend,
- hill,
- shrine,
- forest edge,
- roadside inn,
- minor bridge,
- visible landmark,
- slope or rough stretch.

A waypoint can later be promoted to a graph node if it becomes a decision point.

## Travel time

Route geometry should eventually refine travel time.

The current `distance_km / speed_km_per_day` model remains valid for v0 movement. Later travel time can sum segment costs:

```text
segment_time = segment_distance / party_speed * segment.travel_time_modifier
route_time = sum(segment_time)
```

Modifiers must describe physical route conditions, not abstract risk:

- slope,
- road surface,
- ford or bridge delay,
- forest density,
- mud,
- elevation,
- seasonal impassability.

Danger does not live on the route as a risk stat. Danger comes from physical entities, such as bandit parties, patrols, hostile retinues, wolves, blocked crossings, or damaged bridges.

## Visibility and player map

Route geometry can support visibility without exposing the full graph:

- high waypoints can reveal distant landmarks,
- valleys and forests can reduce line of sight,
- the player-drawn parchment map can add seen waypoints or landmarks without learning every route.

Visibility facts are physical simulation observations. Remembered or reported observations belong in WorldMemory.

## Compatibility notes

This is a planned contract. Current region data does not need `geometry` yet. When implemented, missing geometry should mean "no detailed route geometry authored", not a hidden fallback to generated content.

## Open questions

- Whether route progress should be stored as `edge_id + distance_km` or `segment_id + progress`.
- How to model two-way routes when segment ordering is authored from `from` to `to`.
- Whether route geometry belongs inline in region JSON or in separate route files.
