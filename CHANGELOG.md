Changelog

0.1.46 — 2025-09-11
Removed
- Removed obsolete Map Data Model spec in favor of `/docs/map`.
Fixed
- Renamed map export seed parameter to avoid shadowing the built-in function.
- Map bundle import now casts node IDs and skips edges with missing endpoints to avoid out-of-bounds errors.
- Map bundle loader uses typed arrays for edges and region polygons to satisfy map view constructors.

0.1.45 — 2025-09-11
Changed
- Documentation now references `/docs/map` as the single source of truth for map behaviour.

0.1.44 — 2025-09-11
Changed
- Villages spawn around each town with per-city count controls, linking locally via paths and only attaching to towns or nearby Roman roads with a single road connection.
- Border forts no longer insert crossroads when roads cross kingdom boundaries.

0.1.43 — 2025-09-11
Changed
- Villages now connect to the nearest town or existing road of any class, not just Roman roads.

0.1.42 — 2025-09-11
Changed
- Villages spawn from a global Poisson layer and connect to the nearest town or Roman road, downgrading leaf branches to paths.

0.1.41 — 2025-09-11
Fixed
- Villages spawn via Poisson clusters, remain within map bounds, and each connects to its town with roads while paths link villages.

0.1.40 — 2025-09-11
Changed
- Capped road connection options at 7 and stopped auto-increasing when adding more cities.
- Rivers now end at the map edge and villages and forts clamp to map bounds.

0.1.39 — 2025-09-10
Changed
- Villages now form path-focused clusters and only hook into towns or Roman roads when necessary.

0.1.38 — 2025-09-10
Changed
- Town routes now use the Roman road class.
- Villages connect to towns by roads and link to each other with paths.

0.1.37 — 2025-09-10
Added
- Rivers crossing paths create ford nodes while roads and Roman roads receive bridges.
Changed
- Road intersections now spawn `crossroad` nodes and skip settlements when roads meet inside existing structures.

0.1.36 — 2025-09-10
Added
- Villages branch off main roads with lower-class spurs and per-city count controls.
- Border forts spawn on both sides of kingdom borders with configurable per-kingdom limits.
Changed
- Fort spurs and village roads use lower classes than their parent roads.

0.1.35 — 2025-09-10
Added
- Forts spawn near kingdom borders with short spurs off main roads.
Changed
- Path, road and Roman road classes render with distinct widths and colors.

0.1.34 — 2025-09-10
Changed
- Removed automatic fort placement at road crossings.

0.1.33 — 2025-09-10
Added
- Legend with clickable icons toggling roads, rivers, settlements, crossings and regions.

0.1.32 — 2025-09-10
Added
- Village and fort nodes with road class support and editing tools.
- Finalize Map action validating, cleaning, snapshotting and locking edits.

0.1.31 — 2025-09-10
Added
- World autoload for game state.

0.1.30 — 2025-09-10
Added
- Address input for joining sessions with connection retry and handshake timeouts.

Fixed
- Synchronized VERSION file with project.godot and added consistency check.

0.1.29 — 2025-09-10
Added
- Support editing city positions.
- Validate Map control to run road and river checks from map setup screen.
- Road network cleanup helper to prune invalid edges and orphan nodes.
- Automatic bridge insertion where roads cross rivers.
Changed
- Updated Phase-03 map plan with villages, forts, road types and finalization workflow.

0.1.28 — 2025-09-10
Removed
- Reverted addition of `version` and `rng_seed` to unsafe variable names list.

0.1.27 — 2025-09-10
Fixed
- Linked disconnected road graphs when Delaunay triangulation produced no edges, preventing hangs on some random seeds.

0.1.26 — 2025-09-10
Fixed
- Renamed shadowed snapshot parameters and limited road crossing insertion iterations to guard against bad random seeds.

0.1.25 — 2025-09-10
Added
- Documented `params` as an unsafe variable name in naming guidelines.

0.1.24 — 2025-09-10
Fixed
- Avoided integer division and shadowed built-in name in region generator.

0.1.23 — 2025-09-10
Added
- Configurable kingdom count with contiguous allocation and kingdom-aware region rendering.
- Map setup screen exposes kingdom count parameter.

0.1.22 — 2025-09-10
Fixed
- Corrected Voronoi half-plane clipping so region edges fall midway between cities without overlapping.

0.1.21 — 2025-09-10
Fixed
- Replaced missing `Geometry2D` calls with Delaunay-based Voronoi generation and manual clockwise sorting for consistent region polygons.

0.1.20 — 2025-09-10
Added
- Debug logs for region coordinates and MapView drawing to trace region display issues.
Fixed
- Voronoi clipping produced identical polygons; revised half-plane construction and logged neighbor sites for debugging.

0.1.19 — 2025-09-09
Added
- Expanded game design doc with kingdom mechanics and region generation workflow.
- Configurable crossing detour margin with UI and road pruning.

0.1.18 — 2025-09-09
Added
- Toggle to show or hide regions in map setup screen.

0.1.17 — 2025-09-09
Removed
- Map node count parameter and UI from map setup.

0.1.16 — 2025-09-09
Added
- Variable road connections per city supporting min/max connection bounds.

0.1.15 — 2025-09-09
Added
- Mouse wheel zoom and drag panning in map view with configurable limits.

0.1.14 — 2025-09-09
Added
- Random seed button in map setup screen replacing generate button.

0.1.13 — 2025-09-09
Added
- Localized map setup parameter labels for seed, nodes, cities and rivers, removing hardcoded text.

0.1.12 — 2025-09-09
Added
- Documented map setup preview flow and manual test checklist.

0.1.11 — 2025-09-08
Added
- Map setup screen to preview generated maps and handle start flow.
Fixed
- Explicit polyline type in map setup screen to satisfy typed GDScript.
- Casted map view node to its script class to avoid Control assignment error.
- Renamed shadowed `scale` and `seed` variables and documented them as unsafe names.
- Attached dedicated MapView script to prevent nil preview node.

0.1.10 — 2025-09-08
Added
- Validation utilities for road connectivity, dangling edges and river intersections.
- Manual map-generation checklist.

0.1.9 — 2025-09-08
Fixed
- Corrected river-road intersection detection using `segment_intersects_segment`.

0.1.8 — 2025-09-08
Fixed
- Replaced `?:` ternary with `if/else` in river generation and documented prohibition.

0.1.7 — 2025-09-08
Added
- Blue-noise city placement with minimum spacing.
- Road network using Delaunay triangulation, MST and k-nearest edges with villages and forts.
- River generation producing polylines and converting road intersections into bridge/ford nodes.

0.1.6 — 2025-09-08
Added
- Map data model with nodes, edges, regions and snapshot/diff serialization.

0.1.5 — 2025-09-08
Added
- Net autoload with basic run-mode state machine.
- Start menu hooks for single-player and multiplayer run modes.
- Connecting UI scene for connection feedback.
- Naming guideline to avoid variable names shadowing Godot built-in methods.
- Networking and common UI translations.
- Logging to confirm menu actions and network state transitions.
Fixed
- Avoided shadowed variable warning in connecting UI.
- Corrected invalid indent rules in `.editorconfig`.
- Default focus in start menu ensures keyboard navigation works without mouse.

0.1.4 — 2025-09-08
Added
- Start menu with runtime language toggle and i18n resources.

0.1.3 — 2025-09-08
Removed
- Obsolete placeholder Import file.

0.1.2 — 2025-09-08
Added
- Godot project scaffold with Main scene and directory structure.
- Localization guide pluralization rules.

0.1.1 — 2025-09-08
Added
- PHASE-00 work log added.

0.1.0 — 2025-09-08
Added
- Pełne i szczegółowe instrukcje dla pojedynczej binarki, I18N, faz PHASE‑00..08, bez kodu.
