# Changelog

All notable changes to this project will be documented in this file.

## 0.1.0 - Unreleased

### Added
- Reboot repository structure.
- Server-authoritative architecture notes.
- Region graph reboot notes.
- Initial Silesia high-level graph seed.
- Minimal typed GDScript region graph loader and smoke test.
- HiveMind `base@v1` bootstrap guidance files and project AI documentation.
- Server-authoritative party movement slice with composition-based travel speed and command tests.
- Script-built debug travel panel with headless button-event test.
- Runtime party knowledge for client-visible route snapshots, keeping durable WorldMemory out of Godot.
- Server-authoritative inspect local routes command and debug panel local route check action.
- Runtime simulation event log for travel, arrival, and local route inspection observability.
- Server-authoritative travel intent command with known-route pathfinding and multi-leg travel plans.
- New-game session factory and `Simulation Save v0` snapshot/load contract.
- WorldMemory event export v0 mapper and in-process event sink contract.
- Managed world parties v0 with manager actor ids and same-node client visibility.
- Party orders v0 with manager-authorized `travel_to` orders executed through travel intent.
- Location state v0 with managed physical locations, resources, client visibility, and save/load.
- Goods catalog v0 for canonical trade goods used by authoritative resource stores.
- Party cargo v0 with composition-derived capacity, seed cargo, save/load validation, and tests.
- Transfer goods command v0 for physical party-location goods movement with capacity and inventory validation.
- Location economy v0 with deterministic daily production, consumption, storage caps, and tests.
- Merchant autoplay scenario v0 covering deterministic food transport through real commands.
- WorldMemory domain event ingest v0 with per-entity memory entries and memory-entry search.
- Godot WorldMemory domain event sink and HTTP transport v0 for explicit local sidecar export.
- Optional merchant-to-WorldMemory HTTP integration test.
- Queued WorldMemory HTTP transport so authoritative simulation can export events without blocking on service I/O.
- Mayor food manager v0 and location need declaration events exported to WorldMemory.
- AI memory boundary and WorldSim observation pipeline v0 for owner-specific WorldMemory observations.
- Merchant memory AI v0 that chooses food delivery actions from owner memory entries instead of scanning global state.
- City supply party v0 with mayor-issued `procure_goods` intent and quartermaster-managed physical party state.
- Quartermaster AI v0 for executing supply procurement from order ledger and own WorldMemory observations.
- Physical communication constraint for mayor-issued supply orders; remote orders require future courier delivery instead of implicit telepathy.
- Mayor supply planner v0 that checks remembered active supply intent before issuing a new procure order.
- Planned route geometry v0 notes for route segments, waypoints, visibility, and travel time.
- Local LLM role notes for NPC speech, rumors, navigation text, and player-character intent rendering.
- Historical world tone notes for singleplayer MUD-like simulation, hierarchy, fear, and social brutality.
- Intent adjudication notes for preserving historically loaded player meaning before LLM dialogue rendering.
- Prototype `world_memory` and `llm_service` sidecar services documented in the root README and architecture notes.
