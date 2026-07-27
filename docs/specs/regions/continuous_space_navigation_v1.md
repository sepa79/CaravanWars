# Continuous Space, Exploration & Private Navigation Graph v1

## Purpose and ownership

`WorldSimulation` owns one physical 2D truth: finite coordinates, terrain,
public and hidden locations, landmarks, road/track geometry, relocations and
Party positions. `data/regions/*.json` is the authored source; this contract
does not introduce a second map. A hidden object has one stable world ID and
one truth position. Privacy belongs to knowledge, never to physical state.

`WorldMemory` owns observations. `buildNavigationKnowledgeGraph(ownerView)` is
a pure projection of one owner-scoped view into known nodes, landmarks, edges,
uncertain areas and landmark relations. Routing, commands and AI may consume
this projection and legal local affordances only. Missing or stale knowledge is
rejected; callers cannot resolve an unknown world ID through truth.

## Spatial primitives

- `Vec2`, segment/polyline distance and interpolation are finite and stable.
- Terrain sampling reads authored ellipse/polygon areas.
- Uncertainty v1 is a circle with center and radius; polygons are deferred.
- Roads and tracks are faster geometry, not the boundary of existence.
- Speed combines travel mode, terrain, burden, health, winter/weather and
  visibility configuration.
- Detection uses an explicit stable key, range, skill and concealment, never
  wall time or `Math.random`.

## Commands and events

The canonical envelope includes `spatial_travel`, `search_area`,
`observe_surroundings`, `report_navigation_knowledge` and
`relocate_spatial_object`. Navigation requires Party-manager authority or the
`navigation:command` Governance scope. Relocation requires `spatial:relocate`.

Travel and search enqueue serializable `SpatialTravelDue` and
`SpatialSearchDue` intents in the ordinary `WorldClock`, without type priority.
A Party has one canonical position: node coordinate, exact idle off-road
coordinate, or deterministic progress along one road/search/off-road polyline.
Commands and due events are idempotent; command IDs fingerprint their payload.

## Observation and reporting

WorldSimulation adjudicates observation from physical coordinates, traversed
path, season/light config, observer skill and concealment. Proximity does not
guarantee detection. A success appends owner-scoped WorldMemory with
`observedAt`, `knownAt`, provenance, confidence, uncertainty and staleness.
Direct discovery may add a node and connected hidden track. Repeated ingest is
idempotent and other owners remain unchanged.

A rumor/report can contain only a landmark relation, uncertain area or
distorted estimate. V1 reports require a strictly positive simulated courier
delay. This is the explicit abstract transport boundary: carrier interception
is deferred, but zero-time remote communication is forbidden. Provenance and
confidence loss survive transfer. Relocation changes truth only; old memories
age and can cause false leads rather than receiving broadcast invalidation.

## Fixture, security and saves

Silesia contains one `black_pine_bandit_base` truth object beside a lake and a
hidden `great_forest_bandit_track`. Bandits seed knowledge of both; ordinary
merchants do not. Existing Route Security resolution remains the only source of
captured cargo; continuous movement conserves that cargo to/from the base.

`WorldSnapshot.continuousSpace` stores configuration, metrics, relocations and
deduplication state. Party saves store seed node, exact position, path and
progress, enabling identical mid-search/mid-off-road continuation. Searches
have a maximum step count and each active movement owns one pending due event;
processed history grows linearly with accepted commands/events.

Party Map shows only its owner's projected nodes, tracks, uncertainty and
relations. Labelled TRUTH/DEBUG may show all coordinates, hidden objects,
selected-owner graph and discovery/search metrics.

Coordinate scale, speeds, terrain multipliers, visibility, concealment,
discovery radius and search steps are explicit v1 fixture data, not final
historical or MarsKolony balance. Richer weather and tactical site attacks are
documented deferrals.
