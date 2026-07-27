# World physical layers v0

## Purpose

`World physical layers v0` defines how hidden world coordinates, terrain areas, landmarks, and the region graph relate to each other.

The goal is to keep the current graph-driven simulation and imperfect parchment map system, while giving routes, observations, and future map drawing richer physical material.

## Design rule

The player map remains an observation artifact.

Simulation may know hidden physical layers, but the player parchment must receive only observed, heard, copied, bought, or otherwise player-visible marks. The map renderer should keep using stable positional error and source quality. The change is to apply that error to observed world objects, not only graph nodes and graph edges.

```text
true world object
-> observed map mark
-> stable map error from object id, source, map seed, and future copy skill
```

## Layer model

### Layer 0: world coordinates and elevation

Layer 0 is hidden physical space.

It owns:

- coordinate positions used by region graph nodes,
- coordinate positions used by route waypoints,
- optional elevation values,
- future height-map or sampled height data.

This layer is not a player-facing GPS grid. It exists so route geometry, visibility, terrain, and map distortion have a stable physical reference.

### Layer 1: terrain areas

Terrain areas are physical blobs or polygons in world coordinates.

Examples:

- forest,
- field,
- marsh,
- hills,
- river valley,
- cultivated land,
- rocky slope.

Terrain may influence travel speed, line of sight, fatigue, off-road difficulty, and encounter conditions. Terrain must not become an abstract danger score. Danger comes from physical entities and events such as bandits, patrols, damaged crossings, hostile retinues, blocked roads, or animals.

### Layer 2: landmarks

Landmarks are visible or locally meaningful physical references.

Examples:

- large tree,
- standing stone,
- shrine,
- ruin,
- bridge,
- ford,
- hill crest,
- river bend,
- lone tower,
- distinctive forest edge.

Landmarks may be point-like or small areas. Some are major landmarks visible from far away; others are only useful locally. They are primary material for landmark navigation, local route descriptions, WorldSim observations, rumors, and player-drawn map marks.

### Layer 3: region graph

The region graph is authored road/track geometry and strategic topology inside
continuous space. It is physical truth, but is neither the whole navigable
space nor an actor's decision contract.

Graph nodes are strategic or decision locations such as cities, villages,
passes, forks and hidden camps. Graph edges are physical route contracts.
Actors decide through private WorldMemory-derived Navigation Knowledge Graphs;
off-road travel/search uses coordinates without creating parallel truth.

## Route geometry relationship

Route geometry is the bridge between the physical layers and the graph.

A graph edge may reference ordered route waypoints or segments. Those route details may carry:

- world coordinates,
- elevation,
- terrain area ids,
- landmark ids or landmark tags,
- travel time modifiers,
- visibility hints.

The canonical planned route shape is defined in `docs/specs/regions/route_geometry_v0.md`. This spec defines the layer ownership around that route shape.

## Player map compatibility

The current sketch-map approach remains valid.

The existing model draws graph nodes, graph edges, river hints, bought maps, copied marks, and rumor marks with stable error. In the layered model, the same pattern should generalize to:

- `map_marks`: settlements, graph nodes, landmarks, bridges, fords, trees, stones, shrines,
- `map_paths`: roads, route fragments, rivers, tracks, travelled traces,
- `map_areas`: forest edges, marsh patches, fields, hill areas, vague terrain blobs.

Each visible map artifact should retain source and confidence metadata:

- `source`: `visited`, `seen`, `heard`, `copied`, `bought`,
- `status`: `verified`, `observed`, `unverified`,
- `medium`: ink, thin ink, charcoal, or later style-specific media,
- `accuracy`,
- stable `map_pos`, `map_path`, or `map_shape`.

Direct travel can improve confidence. It should not casually move old marks unless explicit redraw/correction rules apply. This preserves the current additive parchment-map behavior.

## Observation boundary

Physical layers do not imply omniscient knowledge.

WorldSim should decide what a party can observe from location, route position, elevation, terrain, weather, light, fatigue, skill, and social context. Durable remembered observations and rumors belong in WorldMemory. Client-visible map updates should come from those observations, not from scanning all hidden physical layers.

## V0 implementation slice

The next useful slice should stay data-first and map-prototype-facing:

1. Add a minimal authored physical layer block to the Silesia region data:
   - `terrain_areas` with simple blobs or polygons,
   - `landmarks` with ids, kinds, positions, optional elevation, and visibility class.
2. Extend the region graph loader with typed read-only containers for those two collections.
3. Keep route movement unchanged.
4. Teach the sketch-map prototype to draw observed landmarks and one terrain-area edge from explicit observations or demo controls.
5. Add a smoke test that proves the Silesia graph loads terrain areas, landmarks, and existing graph edges without requiring generated fallback data.

This slice should not implement full line of sight, travel-time terrain costs, off-road travel, or WorldMemory integration.

## Compatibility notes

Missing `terrain_areas` or `landmarks` means no authored physical layer data for that region.

Do not silently generate terrain or landmarks to hide missing data. Prototypes may create temporary demo hints only when clearly named as prototype data and kept outside the authoritative region contract.

## Open questions

- Whether terrain blobs should be circles, ellipses, polygons, or a mix.
- Whether a future height map is stored inline, sampled from an asset, or preprocessed into route/landmark elevation.
- How far major landmarks should be visible before weather, terrain, and fatigue modifiers.
- Whether landmark observations should be command-triggered, automatic during travel ticks, or both.
