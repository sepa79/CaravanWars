Changelog

Unreleased
Added
- Rivers now generate from mountain peaks, record per-hex masks, classes, mouths, and emit validation results for missing sinks.
- Map setup preview batches river meshes by class, supports visibility toggles, and marks river mouths above the terrain grid.
Changed
- Plains carved by rivers automatically downgrade to valleys and lakes prefer to open downstream outlets when terrain allows.
- Map generation defaults now start with mountain-mountain-hills-sea-sea-hills edge bands, edge depths 2/2/2/2/5/2, edge jitter 3, and medium random features.
- Default map seed now initializes to 12345 and the base radius default is 16 so generated maps start from the requested large baseline.
Fixed
- Corrected river peak ordering to compare coordinates without using the nonexistent `String` constructor in Godot 4.
- Map preview river batching now preloads all twelve river tiles, classifies masks by canonical rotations, and renders each combination with its dedicated mesh.

0.2.1 — 2025-09-19
Added
- Map setup exposes per-edge terrain type and width selectors with adjustable jitter and random feature density controls.
Changed
- Terrain generation now produces plains maps, applying edge bands and optional random terrain features from the new setup options.
- The automated singleplayer smoke test now opens map setup and returns to the start menu, covering the generator UI navigation.
Fixed
- Nothing yet.

0.2.0 — 2025-09-19
Added
- Singleplayer map setup preview supports mouse zoom, pan, and orbit controls and shows a localized terrain legend beside the viewport.
Changed
- Documented in the README that the project was reset and all systems are being rebuilt from scratch.
- Map setup now displays the prepared singleplayer map with live seed, radius, kingdom, and river controls for regeneration.
Fixed
- Map preview now routes SubViewport, container, and overlay input through a shared handler so orbit and pan drags work alongside zoom instead of getting swallowed by the 3D viewport.
- Renamed hex map seed fields and preload constants to avoid Godot warnings about colliding with built-in names and registered classes.
- Updated the Godot project metadata version to 0.2.0 so tooling and runtime checks report the same release number.
- Corrected terrain region seeding to cast packed vectors before hex conversion, preventing singleplayer map generation crashes.
- Map view now spawns its SubViewport container and world when absent so legacy screens display terrain again.
- Map view preview now instantiates a camera rig and directional lighting so generated terrain is visible during setup.
- Map preview drag rotation and panning persist while drag buttons stay held, so SubViewport events without button masks keep camera control responsive.
- Cleared Map setup preview warnings by renaming conflicting script constants and locals and using static Basis look-at helpers.

0.1.82 — 2025-09-15
Added
- Introduced a hex map generation module with axial coordinate, grid, and metadata scaffolding for future stages.
- Generated terrain discs now classify coastline water, seed all landform regions, and propagate them with deterministic BFS expansion.
- Added repository and game agent guides that direct contributors to `RULES_ALWAYS_READ.md` before changing scripts.
Changed
- Map generation now uses a deterministic HexMapGenerator pipeline with configurable Phase 03 parameters and injectable phase hooks.
- Hex map generation logs each pipeline phase so single player launches show visible progress.
- Terrain stages persist per-hex elevations and validation reports for ridgeline lakes, isolated seas, and unsupported valleys.
- CONTRIBUTING guidelines are now available in English and direct contributors to `RULES_ALWAYS_READ.md`.
- Singleplayer map setup pre-generates a hex map when the screen opens so launches reuse the prepared data.
- CI headless runs now drive the start menu into singleplayer so map preparation errors surface during automated checks.
- Contributor checklists now call for running the automated singleplayer smoke test during implementation, ensuring runtime coverage before review.
Removed
- Replaced the map setup screen with a minimal start/back layout and removed the obsolete map view controls and road network helper.

Fixed
- Restored the Game scene's ability to load the new hex map generator so single player launches build a map again.
- Eliminated typed map generator compile/runtime failures by preloading custom classes and normalising terrain dictionaries.

0.1.81 — 2025-09-14
Added
- CLI smoke test wiring that runs the map generator when `MAPGEN_SMOKE_TEST=1` or via `tests/MapGeneratorSmokeTest.gd`, enabling automated regression checks.
Fixed
- Simplified village road stitching to avoid crossroad explosions and relaxed custom type annotations so the generator can execute under headless tests.
- Replaced the Game scene's full map dump with a compact summary so launching single player no longer stalls on massive console output.
- Treated multi-segment road polylines as individual segments so crossroad insertion no longer loops when forts and village spurs overlap and village scoring can prefer existing bends.
- Prevented the map view's city-to-city labeling from looping forever when village crossroads introduce multi-branch junctions.

0.1.80 — 2025-09-14
Added
- Generated villages per city with road-biased sampling, detailed placement logs, and fallback reporting when space runs out.
Changed
- Map setup exposes a villages-per-city default of two and village insertion defers crossroad checks until after batching.

0.1.79 — 2025-09-14
Added
- Report how many fertility peaks are skipped by city placement because of border margins or minimum distance checks.

0.1.78 — 2025-09-14
Fixed
- Preserved road network ID sequencing while inserting villages so crossroads and village links are created reliably.

0.1.77 — 2025-09-14
Added
- Logged counts of cities and villages found via peaks and fallback placement.
Fixed
- Filled missing village slots with fallback placement when candidate peaks are scarce.

0.1.76 — 2025-09-14
Fixed
- Cast capital indices to a typed array before filtering to satisfy typed GDScript.

0.1.75 — 2025-09-14
Fixed
- Typed capital index filtering to avoid assignment errors.

0.1.74 — 2025-09-14
Fixed
- Village sites are selected from extra city candidates, matching the requested village count.

0.1.73 — 2025-09-14
Changed
- Default map parameters: 6 cities, 10 villages, and 3 kingdoms.

0.1.72 — 2025-09-13
Fixed
- Logged node positions using String.join to avoid PackedStringArray errors.
Changed
- Clarified agent guidelines to always run Godot checks on changed scripts.

0.1.71 — 2025-09-13
Fixed
- Replaced unsupported Array.join call in map generation logging.

0.1.70 — 2025-09-13
Changed
- Removed duplicate layer checkboxes; legend buttons now control map element visibility.
- Logged positions of cities, villages, forts, and crossings during map generation.

0.1.69 — 2025-09-13
Added
- Village visibility toggle and legend entry in the map setup UI.

0.1.68 — 2025-09-13
Fixed
- Shuffled extra village road candidates using the road RNG to avoid invalid function calls.

0.1.67 — 2025-09-13
Added
- Converted unused city-site candidates into villages and linked them to the nearest roads with local path networks.

0.1.66 — 2025-09-13
Removed
- Village generation code, leaving cities and forts as the only settlements.

0.1.65 — 2025-09-13
Fixed
- Village generation starts with at least one site per city, restoring default village spawning.

0.1.64 — 2025-09-13
Fixed
- Annular Poisson sampling now yields village candidates, preventing empty clusters.
- Renamed modules and parameters to avoid shadowing global classes and built-in functions.

0.1.63 — 2025-09-13
Changed
- Villages attach to the nearest roman road, linking to their city only when no major route is nearby.
- Direct village paths appear only when the existing road network is over twice as long.
Fixed
- Bounded shortest-path search iterations to prevent road computations from hanging.

0.1.62 — 2025-09-13
Added
- Village placement favours fertile terrain and proximity to existing roads.
- Neighbouring regions of the same kingdom link their closest villages when no shorter route exists.
Fixed
- Cities keep a literal 30-unit buffer from map borders.

0.1.61 — 2025-09-13
Added
- Villages sample via Poisson disks in 8–30 u rings and stay within their city regions.

0.1.60 — 2025-09-13
Fixed
- Preloaded NoiseUtil and capped city sampler iterations to keep map generation from hanging.

0.1.59 — 2025-09-13
Fixed
- Village cluster spacing scales with city spacing to stay below half the minimum city distance.

0.1.58 — 2025-09-13
Fixed
- City generator accepts configurable `border_margin` (default 60 u) and samples extra cities when fertility peaks are insufficient.

0.1.57 — 2025-09-13
Added
- `AGENTS.md` directs contributors to `RULES_ALWAYS_READ.md`.
Fixed
- Road network uses `if/else` instead of banned `?:` operator.

0.1.56 — 2025-09-13
Changed
- Default map size is now 150×150 U and initial kingdom count is 2.

0.1.55 — 2025-09-13
Added
- City placement now keeps 30 u from map edges.
- Village clusters sample in 8–30 u rings and connect via MST with random shortcuts and hierarchical road classes.
- Repo guidelines require `godot --headless --check` for modified scripts.

0.1.54 — 2025-09-13
Added
- Generate up to six noise-based rivers that create bridge crossings when intersecting roads.
- Support drawing spline rivers and new crossing icons in map view.
- Expose river count and crossing layer toggles on the map setup screen.
Fixed
- Replace OpenSimplexNoise with FastNoiseLite and annotate noise variables to satisfy typed GDScript.

0.1.53 — 2025-09-12
Fixed
- Map bundle export/import now preserves fertility and roughness fields.

0.1.52 — 2025-09-12
Fixed
- Capital selection shuffles city indices with the seeded RNG for deterministic results.

0.1.51 — 2025-09-12
Fixed
- Map bundle import restores road lengths and map view respects them, keeping distances unchanged after export/import.

0.1.50 — 2025-09-12
Fixed
- Map bundle export sets kingdom capital IDs and import restores capital indices.

0.1.49 — 2025-09-12
Fixed
- Annotated capital road node in map generator to satisfy typed GDScript.

0.1.48 — 2025-09-12
Changed
- CI checks now run `godot --headless --check-only` for each module to validate scripts on commit.

0.1.47 — 2025-09-12
Added
- Choose city sites from fertility noise peaks with spacing and mark 1–3 capitals.
- Highlight capitals in the map view and preserve them when editing.
- Refresh map setup view on parameter tweaks.
Fixed
- Annotated capital road node type in map setup screen to satisfy typed GDScript.

0.1.46 — 2025-09-11
Removed
- Removed obsolete Map Data Model spec in favor of `/docs/map`.
Fixed
- Renamed map export seed parameter to avoid shadowing the built-in function.
- Map bundle import now casts node IDs and skips edges with missing endpoints to avoid out-of-bounds errors.
- Map bundle loader uses typed arrays for edges and region polygons to satisfy map view constructors.
- Map bundle export now preserves distinct region IDs and includes kingdom assignments so all regions load correctly.
- Map bundle import restores missing kingdom names with defaults so legend entries survive export and reimport.
- Map bundle import sets road ID counters to the next available values so editing imported maps doesn't overwrite nodes or edges.

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
