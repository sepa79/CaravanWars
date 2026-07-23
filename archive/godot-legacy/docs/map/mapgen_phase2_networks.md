# Map Generation — Phase 2: Hydrology, Settlements, Roads, Borders (Planning)

**Scope:** This phase extends **on top of Phase 1 outputs**. It **does not** change Phase 1 contracts with the View.
It adds new data and layers (still emitted in `drawStack`) for: rivers/lakes (later), settlements (cities/villages),
roads, forts, and borders. Everything remains deterministic. No implementation code here — only design and Codex tasks.

> Note: Phase 2 must be toggleable (can run after Phase 1 or be skipped).

---

## 1) Principles
- Preserve Phase 1 fields; only **append** new layers/metadata.
- All per-tile render decisions are **precomputed** — View remains dumb.
- Deterministic RNG scopes: new `purpose` keys for each subsystem (e.g., `"river"`, `"settlement"`, `"road"`, `"border"`).

---

## 2) Additions to the Data Model (Phase 2)

### 2.1 Tile (extensions)
- `networks?: { riverMask6?: byte, roadMask6?: byte }` *(6-bit bitmasks per tile; optional if using mask assets)*
- `admin?: { borderMask6?: byte }`
- `poi?: { city?: CityRef, village?: VillageRef, fort?: FortRef }`
- `drawStack`: append new `LayerInstance`s in the agreed order

### 2.2 MapData (extensions)
- `settlements?: City[] | Village[]` (catalogue of nodes with coordinates and ids)
- `roads?: Edge[]` (logical graph if needed for scenario generation; optional for render-only)
- `rivers?: RiverSegment[]` / `lakes?: Lake[]` (optional in first cut)
- `borders?: BorderSegment[]`
- (Future) `biomes`, `resources`, etc.

---

## 3) Rendering Order (Phase 2 add-on)
Append to Phase 1 order (terrain stack already built):
- `WATER: river_mask_*` / `lake_*` (after terrain & decor)
- `ROADS: road_mask_*`
- `BORDERS: border_mask_*`
- `POI: city/fort/village` icons (top-most within tile)

Exact z-order may be fine-tuned per asset needs.

---

## 4) Subsystems (Planning Only)

### 4.1 Rivers & Lakes (later)
- Inputs: height field from Phase 1.
- MVP: seeded sources at high `heightFinalBase`, follow downslope; ensure connectivity; simple carving not required for Phase 1 visuals.
- Output: per-tile 6-bit masks or segment list → converted to mask assets in `drawStack`.

### 4.2 Settlements
- Seed N cities (configurable), optionally K villages per city.
- Constraints: minimum distances, near plains/hills, near water (optional in later iteration).
- Output: POIs with per-tile placement (single icon layer per POI).

### 4.3 Roads
- Graph on POIs (Steiner-lite): connect cities; optionally connect villages to nearest hub.
- Output: per-tile road 6-bit masks → asset layers.

### 4.4 Borders
- Based on Voronoi over POIs or watershed lines (choose later).
- Output: border masks (6-bit) per tile; render layer after roads/water as needed.

---

## 5) Codex Plan (Phase 2)

### A. Contracts
- [ ] Extend `AssetCatalog` with `WATER`, `ROAD`, `BORDER`, `POI` roles and mask sets.
- [ ] Extend `Tile` and `MapData` with optional fields (as above).
- [ ] Fix Phase 2 z-order additions.

### B. Subsystem Stubs
- [ ] Define RNG scopes and config structures for rivers, settlements, roads, borders.
- [ ] Implement empty pass-through that **leaves Phase 1 output unchanged** when disabled.

### C. Minimal Implementations (order of delivery)
1. **Settlements MVP**: place a few cities; emit POI layers.  
2. **Roads MVP**: connect cities with simple shortest paths; emit road masks.  
3. **Borders MVP**: split territory around cities; emit border masks.  
4. **Rivers MVP**: basic downhill traces; emit river masks.

### D. Debug/Calibration
- [ ] Separate debug boards for each subsystem (e.g., mask shapes, spacing rules).
- [ ] Determinism tests: same seed → same networks.
