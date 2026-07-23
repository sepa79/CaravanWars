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
- Ask local information command v0 for reusable physically local goods-source inquiries.
- Party task state v0 so local information inquiries take simulation time before producing memory.
- Documented future actor-owned task direction: one actor runs one task, while party-level tasks lock the group.
- Actor task state v0 target contract for future companion and city action parallelism.
- Durable actor task state on parties, including save/load validation and party-lock busy checks.
- Ask local information now runs as an actor-owned task for the party manager.
- Report back command v0 for physically local actor reports from party memory to a superior's WorldMemory.
- Memory freshness policy for goods-source AI decisions, preventing quartermasters from acting on stale source reports.
- Mayor supply planner now uses memory freshness for source reports and stale active supply intents.
- Mayor supply planner WorldMemory integration test for re-evaluating real mayor memory after report-back.
- Mayor supply intent declaration command and WorldMemory ingest mapping for explicit mayor/location operational memory.
- Mayor supply planner candidate-party selection test coverage for settlements with more than one supply party.
- Procure order completion events and WorldMemory terminal order ledgers so mayor supply planning can close older active intents.
- Cancel party order command and terminal `cancelled` order ledgers for explicit order lifecycle control.
- Replace party order and interrupt travel commands, including durable interrupted travel state and WorldMemory ledgers.
- Opportunity policy v0 notes for bounded secondary trade/courier actions under a single primary order.
- Full mayor-to-quartermaster supply loop WorldMemory integration test covering need, intent, active order, deposit, and completed order memory.
- Report back intent v0 documented and covered through WorldMemory memory-transfer.
- Quartermaster-to-WorldMemory integration test for local information memory ingestion.
- Planned route geometry v0 notes for route segments, waypoints, visibility, and travel time.
- World physical layers v0 notes plus authored Silesia terrain/landmark seed data, typed graph loading, and sketch-map observation rendering.
- Route geometry v0 seed data and typed route waypoint loading for authored Silesia route details, with sketch-map road shaping from route geometry.
- Route observation integration v0 notes for moving route/terrain/landmark discovery into server-authoritative WorldSim events and WorldMemory export.
- Debug party map harness v0 with selected-party and truth map modes in the script-built debug travel panel.
- Local LLM role notes for NPC speech, rumors, navigation text, and player-character intent rendering.
- Historical world tone notes for singleplayer MUD-like simulation, hierarchy, fear, and social brutality.
- Intent adjudication notes for preserving historically loaded player meaning before LLM dialogue rendering.
- Prototype `world_memory` and `llm_service` sidecar services documented in the root README and architecture notes.
