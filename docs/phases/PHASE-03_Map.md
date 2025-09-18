PHASE‑03 — Map

### Overview
The pipeline is single-seed deterministic and layer-oriented: each stage writes a vector or raster layer that downstream stages can reference. The pipeline must be strictly executed in the following order to ensure reproducibility and correct placement logic.

**Sequence (enforced):**
1. Terrain
2. Rivers
3. Biomes
4. Kingdom borders (seeded & expanded after consulting rivers & biomes)
5. Cities & villages
6. Roads
7. Forts

### Global parameters (defaults)
- `seed`: integer (default: 12345 or read from UI seed field)
- `map_size`: integer (tiles, default 256)
- `kingdom_count`: integer (default **3**) — UI-exposed
- `sea_level`: float (0.0–1.0, default 0.32)
- `terrain_octaves`: int (default 6)
- `fort_global_cap`: int (default 24)
- `fort_spacing`: int (tiles, default 150)
- `road_aggressiveness`: float (0.0–1.0)

Each UI control must map to one or more of the above parameters; keep existing UI mappings but change the kingdom default to 3.

---

## Stage details

### 1) Terrain
**Outputs:** heightmap raster, slope raster, contour vector layer, sea mask.

**Algorithm:**
- Multi-octave noise (Perlin/Simplex) to produce base elevation.
- Apply a controllable `roughness` and `mountain_scale` parameter.
- Optional thermal/erosion pass to reduce overly jagged features.
- Compute slope via central differences.
- Generate `sea_mask` where height < `sea_level`.

**Constraints:**
- Expose `mountain_threshold` and `sea_level` in UI.
- Produce deterministic result from `seed`.

**Validation:** no isolated ocean tiles beyond expected; slope values normalised.

### 2) Rivers
**Outputs:** river polyline layer (polylines), river width/discharge attributes, watershed polygons (optional).

**Algorithm:**
- Compute flow direction & flow accumulation from heightmap.
- Select river source candidates where accumulation ≥ `river_min_accum` and altitude > `river_source_alt_thresh`.
- Trace river paths downhill to sea or large lake; optionally merge tributaries where paths join.
- Optionally run a river smoothing pass to reduce zig-zagging.

**Important rules:**
- Rivers must originate in higher altitude regions; enforce a minimum source altitude.
- Rivers are barriers for border seeding (borders prefer river lines as natural boundaries).
- Rivers reaching sea are considered complete; enforce fallback to nearest sink if river gets stuck (tie-breaker: route to nearest lower tile with A* on slope costs).

**Validation:** each river must reach the sea or an assigned lake; no silly isolated short rivers.

### 3) Biomes
**Outputs:** biome polygon layer (tagged with biome type), temperature map, rainfall map.

**Algorithm:**
- Compute `temperature` map: latitude (or noise-based pseudo-latitude) - altitude * lapse_rate.
- Compute `rainfall` map: base noise + orographic effect (rain shadow behind mountain ranges) + proximity boost near rivers/lakes.
- Combine temperature+rainfall+altitude to classify biomes (e.g., desert, grassland, temperate forest, taiga, alpine, swamp).
- Optionally add `special` biome tags (coast, delta, marsh) for river mouths/estuaries.

**Rules:**
- Rivers and lakes should increase local moisture and shift biome locally.
- Extremely steep terrain forces alpine/rocky tags irrespective of rainfall.

**Validation:** ensure biome polygons are contiguous and do not create tiny slivers; post-process small polygons by merging to neighbors.

### 4) Kingdom borders
**Outputs:** kingdom polygon layer (labelled with `kingdom_id`, `capital_candidate`), border polylines.

**Algorithm (recommended):**
- **Seed capitals:** Choose `kingdom_count` = `3` seed candidates biased to: large habitable biome patches, river proximity, and resource-rich nodes. Use Poisson-disc or weighted sampling to ensure spread.
- **Expansion:** Run a multi-source constrained flood-fill (Dijkstra-like) where cell expansion cost = `terrain_cost` + `biome_mismatch_penalty` + `river_crossing_penalty`. Assign each cell to the seed with lowest cumulative cost.
- **River-aware snapping:** Where a river separates regions, prefer the river line as a boundary (if cost difference is within threshold) to produce natural borders.
- **Smoothing & cleanup:** Smooth tiny enclaves (< area threshold), dissolve micro-peninsulas, and ensure border polygons remain contiguous.

**Rules & heuristics:**
- Avoid seeding capitals in sea or extremely steep slope.
- Prefer capitals in plains near rivers when possible.
- **Do not force borders to split roads** — roads are created later and must be continuous across borders.

**Validation:**
- Exactly `kingdom_count` polygons exist and cover all non-ocean land (or flagged unclaimed areas if intended).
- Capitals are validated for placement rules; if a capital candidate is invalid (e.g., inside a swamp) re-pick.

### 5) Cities & villages
**Outputs:** point layer for `cities` and `villages` with attributes (population, role, resources).

**Algorithm:**
- Score candidate tiles by:
  - Flatness (inverse slope)
  - River proximity (bonus)
  - Biome suitability (cities prefer plains/temperate forest)
  - Resource proximity (if a resource layer exists)
  - Strategic value (near borders or road nodes — roads come later; for cities prefer distribution)
- Place **cities** first (higher threshold) using Poisson-disc sampling with min-distance constraints; then **villages** with lower thresholds and more randomness.
- Assign each settlement to the kingdom polygon containing it. If a tile is near multiple kingdoms (border area), assign by the polygon ownership from Stage 4.

**Rules:**
- Minimum distance city→city, city→village, village→village must be enforced (configurable knobs).
- Ports: if a candidate is at coastline, mark as `port` if it meets population criteria.

**Validation:**
- All cities pass placement filters (not inside ocean, slope < threshold).
- Ensure each kingdom has at least one city (if possible). If not, re-run capital seeding with stronger bias.

### 6) Roads
**Outputs:** road polyline layer (continuous), connectivity graph (nodes & edges), road attributes (type, length, crosses_border boolean).

**Algorithm (two-pass):**
1. **Backbone graph:** compute Delaunay/Voronoi or MST between cities to propose primary connections. Optionally add extra connections based on `road_aggressiveness`.
2. **Path carving:** for each proposed edge run A* on the cost grid where cost = slope_cost + biome_cost + water_crossing_penalty. Place bridges at narrow river crossings where beneficial.

**Rules:**
- **Do not split road at kingdom borders.** Keep road geometry continuous; tag edges with `traversed_kingdoms` list.
- Bridges or fords: place them at logical crossing points (narrow river valley, short bridge length) and mark as chokepoints for fort logic.
- Roads avoid impassable tiles; if forced, apply high cost rather than disallowing entirely to allow remote connections.

**Validation:**
- Every city should be connected to the road network (or flagged as isolated with reason).
- Road geometry is topologically correct; no self-intersections or short dangling segments.

### 7) Forts
**Outputs:** fort point layer with attributes: `kingdom_id`, `priority_score`, `type` (border, road_guard, frontier), `elevation`, `nearby_road`.

**Algorithm:**
- For each kingdom, compute candidate fort sites with heuristics:
  - Road chokepoints (bridges, narrow corridor crossings)
  - Terrain chokepoints (passes between mountains)
  - Near borders where defense makes sense (but avoid symmetric placements facing each other)
  - Prefer elevated positions near roads
- Score candidates: `score = strategic_value + proximity_to_road_bonus + elevation_bonus - proximity_to_other_forts_penalty`.
- Enforce a per-kingdom cap: `forts_in_kingdom = min( floor(num_cities_in_kingdom / 4), kingdom_cap_dynamic )`, where `kingdom_cap_dynamic` is derived from global settings but ensures at least 1 fort if kingdom has ≥1 city.
- Enforce **global spacing** (`fort_spacing`) between forts (across the map, including across borders). If two selected forts violate spacing, either bump the lower-scoring one to its next candidate or drop it.
- Apply special check to **avoid symmetrical face-off:** if two forts are placed on opposite sides of a short border segment and face each other within `face_off_distance`, then relocate the lower-scoring fort to a nearby alternate candidate.

**Validation:**
- Fort counts per kingdom ≤ allowed cap.
- No two forts violate spacing rules.
- Forts placed on valid terrain (not water, not extremely steep).

---

## Post-generation validation & fixer pass
Run a deterministic validation suite that applies the rules below. If violations are found, run a fixer pass that attempts local repairs and logs changes.

**Checks:**
- All rivers reach sink (sea or large lake).
- All cities are on land and slope < max_slope.
- Road connectivity: every city is connected or flagged.
- Fort caps + spacing satisfied.
- Kingdom polygons count == `kingdom_count`.

**Fixer actions:**
- Reassign or remove illegal settlements.
- Reroute roads with higher cost thresholds if they intersect invalid tiles.
- Re-pick capital seeds if some kingdom ended with zero cities.

---

## Data model / Layer outputs (recommended)
- `terrain/heightmap` (raster)
- `terrain/slope` (raster)
- `rivers/polylines` (vector)
- `biomes/polygons` (vector)
- `kingdoms/polygons` (vector with `kingdom_id`, `capital_candidate`)
- `settlements/points` (vector: type=`city|village`, `population`, `kingdom_id`)
- `roads/polylines` (vector with `traversed_kingdoms`)
- `forts/points` (vector)

Each layer must be exportable independently (SVG / GeoJSON / custom vector format) for debugging and UI preview.

---

## UI mapping & controls
- `Seed` (int) — full map reproducibility.
- `Map Size` — affects resolution of heightmap and grid costs.
- `Kingdom Count` — default **3**; min 1, max configurable.
- `Sea Level`, `Mountain Scale`, `Terrain Roughness` — terrain knobs.
- `Road Aggressiveness` — how many extra roads to try.
- `Fort Global Cap`, `Fort Spacing` — fort controls.

Expose a step-per-stage preview toggle so users can inspect intermediate layers (terrain, rivers, biomes, borders, etc.). Also expose an `Advanced` option to re-run a single stage deterministically without re-running preceding stages (for debugging), but default runs should enforce full-sequence runs.

## Tests / QA cases
1. **Small map smoke:** `map_size=512`, `seed=42`, `kingdom_count=3` — assert generation completes under time limit and produces layers.
2. **High mountain test:** high `mountain_scale` — verify rivers originate from mountains and kingdoms avoid uninhabitable mountains for capitals.
3. **River network test:** ensure major rivers are preserved as natural borders when appropriate.
4. **Fort spacing test:** iterate seeds and ensure fort spacing / cap rules hold.
5. **Border-road rule test:** create map where proposed roads cross planned borders — assert roads remain continuous and are not split.

Record test outputs, diffs of layers, and a human-readable report.

---

## Implementation checklist (developer tasks)
- [ ] Create `backup/old-mapgen-<date>` branch.
- [ ] Remove old generator and update CI.
- [ ] Create new `mapgen/` module with staged pipeline and deterministic seeding.
- [ ] Implement stage outputs and intermediate export functions.
- [ ] Add UI controls and default `kingdom_count = 3`.
- [ ] Implement validation & fixer pass.
- [ ] Add test cases to CI and run full QA.

---

## Notes & rationale
- Using a **strict stage order** ensures predictable placement (particularly rivers then borders then settlements) and simplifies debugging.
- Defaulting to **3 kingdoms** yields larger kingdoms that are easier to design and test visually; it reduces edge-case micro-kingdoms that created awkward fort placements.
- Removing the old generator first reduces accidental regressions and makes the new pipeline the single source of truth.

---

*End of Phase 3 plan.*
