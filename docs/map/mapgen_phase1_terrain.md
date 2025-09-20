# Map Generation — Phase 1: Terrain, Objects, Debug View (RectangleHex)

**Scope:** This phase generates **terrain only** on a rectangular hex grid and produces fully renderable tiles for a dumb View:
- Terrain classification (`SEA`, `PLAINS`, `HILLS`, `MOUNTAINS`)
- Visual height (scale of `base_grass`) with terrain bias
- Rotations and visual variants (A/B/C) for rotatable terrains
- Single decor flag: `withTrees: bool`
- Edge shaping (per side: `N, E, S, W`) with type + width
- Random features (peaks/hill clusters with falloff)
- **Debug View** dataset that enumerates combinations

No rivers/roads/borders/cities in this phase.

---

## 1) Determinism & Principles
- **No logic in View.** The generator outputs `MapData` with a ready-to-render `drawStack` for each `Tile`.
- **Deterministic RNG** via scoped hashing: `rand(seed, q, r, purpose)`.
- **Layering order:** `base_grass` (scale=height) → `terrainBase` → `terrainOverlay` → `decor (trees)`.

---

## 2) Inputs

- `seed: int`
- Grid: `RectangleHex` (hex tiles laid out in a rectangle)
  - `width: int`, `height: int`  *(tile counts)*
- **Edges (4 sides):**
  - For each `N, E, S, W`:
    - `edge.type ∈ { SEA, PLAINS, HILLS, MOUNTAINS }`
    - `edge.width: int ≥ 0` (in tiles from the rectangle border)
- **Random features:**
  - `features.intensity ∈ { None, Low, Medium, High }`
  - `features.mode ∈ { Auto, PeaksOnly, HillsOnly }` *(default Auto)*
  - `features.countOverride?: int`
  - `features.falloff ∈ { Smooth, Linear }` *(default Smooth)*

---

## 3) Data Model (Phase 1)

### 3.1 AssetCatalog
Single source of truth for assets and their semantics.
- Roles: `BASE`, `TERRAIN`, `DECOR`.
- Items (examples, not filenames):
  - `base_grass` (`BASE`, non-rotatable, scaled by height)
  - `plains` (`TERRAIN`, non-rotatable)
  - `hill_A/B/C` (`TERRAIN`, rotatable 6 ways)
  - `mountain_A/B/C` (`TERRAIN`, rotatable 6 ways)
  - `*_trees` (`DECOR`, optional per terrain/variant)

### 3.2 LayerInstance
- `assetId: string|enum` (from `AssetCatalog`)
- `rotation: int` (0..5 for hex; 0 if not used)
- `scale: float` *(uniform; used by `base_grass`)*
- `offset: (x,y)` *(usually (0,0))*

### 3.3 Tile
- `q: int, r: int` *(axial)*
- `terrainType: enum { SEA, PLAINS, HILLS, MOUNTAINS }`
- `heightValue: float` *(after bias)*
- `tileRotation: int` *(0..5 for rotatable terrains; 0 otherwise)*
- `visualVariant: enum { A, B, C }` *(minimally)*
- `withTrees: bool`
- `drawStack: LayerInstance[]` *(final order for View)*

### 3.4 MapData
- `seed: int`
- `width: int`, `height: int`
- `tiles: Dict<(q,r), Tile>`

---

## 4) Height, Bias, and Classification

### 4.1 Base Height
Two options (choose one via configuration):
- **Noise-based:** OpenSimplex/Perlin → normalize to `[0..1]` → `heightBase`.
- **Flat base + features:** Start at `0.5` everywhere; shape entirely via features + edges.

### 4.2 Random Features (Peaks/Hill Clusters)
- Select a deterministic number of centers based on `features.intensity` (e.g., None:0; Low:2–3; Medium:5–7; High:10–14).
- Place centers with a margin (avoid edges) deterministically.
- **Modes:**
  - `Peak`: inner peak radius `r_core`, outer halo `r_halo` with `Smooth` falloff.
  - `HillCluster`: halo only (`HILLS`-like) with `Smooth/Linear` falloff.
- Combine with base height using **max** blending or `height = max(heightBase, featureHeight)`.

Result → `heightFeat`.

### 4.3 Edge Shaping (RectangleHex)
Compute distance from each rectangular side in tiles:
- `d_N = row`
- `d_S = (height - 1) - row`
- `d_W = col`
- `d_E = (width - 1) - col`

For each side, if `d_edge < edge.width`:
1) Define edge target levels (to be calibrated):
   - `SEA → h_target ≈ 0.10`
   - `PLAINS → h_target ≈ 0.45`
   - `HILLS → h_target ≈ 0.65`
   - `MOUNTAINS → h_target ≈ 0.85`
2) Mix in the edge band using `t = smoothstep(0, edge.width, d_edge)` and  
   `heightEdge = lerp(h_target, heightFeat, t)`.
3) Corners: apply a deterministic merge rule (e.g., priority `MOUNTAINS > HILLS > PLAINS > SEA`, or fixed order `N, E, S, W`).

Result → `heightFinalBase`.

### 4.4 Terrain Classification (from `heightFinalBase`)
Calibrate thresholds; suggested start:
- `SEA: h < 0.20`
- `PLAINS: [0.20 .. 0.55)`
- `HILLS: [0.55 .. 0.75)`
- `MOUNTAINS: ≥ 0.75`

### 4.5 Visual Bias and Scale
- `visualBias(SEA=-0.20, PLAINS=0.00, HILLS=+0.15, MOUNTAINS=+0.35)`
- `heightValue = clamp(heightFinalBase + visualBias(terrainType))`
- `base_grass.scale = 1.0 + K * heightValue` (start `K ≈ 0.3`)

### 4.6 Rotation, Variants, Trees
- `tileRotation = rand6(...)` for rotatable terrains (`HILLS`, `MOUNTAINS`); `0` otherwise.
- `visualVariant ∈ {A,B,C}` deterministically.
- `withTrees: bool` deterministically with per-terrain weights.

### 4.7 Build `drawStack` (Phase 1 only)
- `base_grass` (scale = f(heightValue), rot=0)
- `terrainBase` (e.g., `plains/sea/...`, rot=0)
- `terrainOverlay` (e.g., `hill_B`/`mountain_A`, rot=tileRotation)
- `treesOverlay` (if `withTrees`)

---

## 5) Debug View (Phase 1)
Produce a **special `MapData`** that enumerates combinations to validate assets and transforms:
- Rows/columns spanning: `terrainType × variant(A/B/C) × rotation(0..5 for rotatable) × withTrees(false/true)`.
- Additional sections to validate: edges (`N,E,S,W` × widths) and `features.intensity` (None/Low/Medium/High).
- Base height in debug: `0.5`; visible differences come from bias/edges/features.

---

## 6) Codex Plan (Phase 1)

### A. Contracts
- [ ] Formalize `AssetCatalog` (roles, rotatability, variants, tree overlays, naming conventions).
- [ ] Define data schemas: `LayerInstance`, `Tile`, `MapData` (fields and semantics).
- [ ] Fix render order and which layers receive rotation/scale/offset.

### B. Terrain Generator
- [ ] Implement `heightBase` (noise or flat `0.5`).
- [ ] Implement `RandomFeatures` (centers, falloff, blend).
- [ ] Implement `EdgeShaping` for 4 sides with `h_target` levels and corner merge.
- [ ] Classify terrain by thresholds.
- [ ] Apply `visualBias` and compute `base_grass.scale`.
- [ ] Choose `tileRotation`, `visualVariant`, `withTrees` deterministically.
- [ ] Build `drawStack` (terrain only).

### C. Debug Map
- [ ] Generate enumerated combinations dataset.
- [ ] Generate edge and features calibration boards.
- [ ] Ensure determinism for a given seed.

### D. Calibration
- [ ] Tune thresholds and `K` for asset sizes.
- [ ] Tune `withTrees` probabilities per terrain.
- [ ] Validate edge transitions and feature shapes.
