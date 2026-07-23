# Region Graph v0

## Purpose

`Region Graph v0` is the canonical authored-data contract for a physical region
graph during the Node/TypeScript migration. The graph remains simulation truth;
maps remain actor-facing presentation artifacts.

## Owner / consumers

- Owner: `packages/world-sim`.
- Authored data: `data/regions/*.json`.
- Consumers: authoritative WorldSim, conformance tests, debug Truth Map adapter.

## Top-level shape

Required fields:

```text
id
display_name
nodes[]
edges[]
terrain_areas[]
landmarks[]
```

`description` is optional and normalizes to an empty string.

## Coordinates

Positions, centers, radii, polygons, and legacy edge waypoints use finite
two-number arrays `[x, y]`. They are hidden simulation/layout data and must not
be exposed directly through normal player snapshots.

## Nodes

Each node requires `id`, `display_name`, `kind`, and `position`. `notes` is
optional. Node ids must be unique within the region.

## Edges

Each edge requires:

```text
id
from
to
distance_km
kind
```

`from` and `to` must reference existing nodes. `distance_km` must be positive.
Edge ids must be unique. `waypoints` is the legacy coordinate-only list and
normalizes to an empty list when absent.

## Route geometry

`geometry` is an optional ordered list of route waypoints. Each waypoint
requires `id`, `kind`, `position`, and `distance_from_start_km`.

- waypoint distance must be positive and less than the edge distance,
- waypoint distances must be strictly increasing,
- `travel_time_modifier` defaults to `1` and must be positive,
- `elevation_m` defaults to `0`,
- terrain and landmark reference arrays default to empty,
- referenced terrain areas and landmarks must exist in the same region graph.

## Terrain areas

Each terrain area requires `id`, `display_name`, `kind`, and `shape`.

- `polygon` areas require at least three points,
- `ellipse` areas require positive x/y radii,
- omitted center, radius, or polygon fields normalize to their explicit empty
  values according to shape,
- terrain area ids must be unique.

## Landmarks

Each landmark requires `id`, `display_name`, `kind`, and `position`.
`elevation_m` defaults to `0`, `visibility_class` defaults to `local`, and
`notes` defaults to an empty string. Landmark ids must be unique.

## Failure behavior

Malformed JSON, wrong field types, missing required arrays, invalid references,
duplicate ids, non-finite coordinates, and invalid physical values fail
explicitly. The loader must not return an empty graph or silently overwrite a
duplicate id.

## Compatibility

This contract intentionally describes the current authored Silesia data. There
is no implicit compatibility promise for malformed legacy data. Contract
changes require an explicit spec and fixture update.
