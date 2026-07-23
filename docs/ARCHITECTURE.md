# Architecture - CaravanWars Reboot

This file is the starting SSOT for architecture. Deeper notes live in `docs/architecture/` and `docs/reboot/`.

Durable project direction decisions are summarized in `docs/adr/ADR-001-project-direction.md`.

## Purpose

CaravanWars Reboot is a Godot 4 game architecture centered on a server-authoritative party simulation. A party is a neutral field group such as a caravan, pilgrim group, retinue, patrol, or bandit band. The main architectural constraint is that singleplayer and multiplayer share one command and state model.

## Architecture principles

- Keep boundaries explicit.
- Keep contracts/specs as SSOT.
- Prefer simple, observable flows.
- Prefer explicit configuration over hidden defaults.
- Avoid hidden synchronous dependencies.
- Avoid fallback chains that hide real failures.
- Design retries with idempotency, backoff, limits, and visibility.
- Make recovery and debugging possible.
- Treat region graphs as simulation truth and maps as presentation.

## System overview

```text
Input command -> authoritative simulation -> state snapshot/events -> client presentation
                                      |
                                      v
                             region graph data
```

Singleplayer is a local server plus local client. Multiplayer will use the same command interface and authoritative simulation state. Player caravans, bandit bands, city authorities, patrols, AI agents, and future human-controlled roles must all submit commands through the same model.

Local LLM support is a presentation and interpretation layer, not a simulation owner. The player acts as the mind of the character: microphone, typed, or UI-selected intent can be converted by the LLM into in-world speech shaped by character statistics and context. See `docs/architecture/LOCAL_LLM_ROLE.md`.

Durable NPC and party memory lives outside Godot in the WorldMemory service. Rumors spread by copying and mutating private memory entries between important actors and parties, not through a central rumor registry. See `docs/architecture/WORLD_MEMORY_AND_RUMORS.md`.

AI memory is exclusively WorldMemory-owned. Godot managers and LLM decision jobs must not keep separate private memory or scan global authoritative state as knowledge. Observations pass through WorldSim and become owner-specific WorldMemory entries before AI uses them. See `docs/architecture/AI_MEMORY_BOUNDARY.md`.

LLM execution should live in a separate stateless LLM Service. The simulation orchestrates: it pulls context from WorldMemory, calls the LLM Service, validates the proposal, and writes accepted results. See `docs/architecture/LLM_SERVICE.md`.

## Main components

| Component | Responsibility | Notes |
|---|---|---|
| Authoritative simulation | Owns command validation and state transitions | Must be shared by singleplayer and multiplayer. |
| Command model | Common input contract for all actors | Not fully specified yet; keep canonical when introduced. |
| Party state | Neutral field group state | Represents caravans, pilgrims, retinues, patrols, bandits, or similar groups; significant parties have manager actors. |
| Party order state | Authorized actor-issued party directive | Stores assigned travel orders and high-level supply intents issued through normal server commands. |
| Party task state | Timed local party action | Stores active city/local tasks such as asking for information. |
| Party knowledge state | Runtime client visibility boundary | Tracks currently known nodes/routes for snapshots and commands; not durable WorldMemory. |
| Party composition | Data that feeds derived stats | Horses, wagons, foot members, guards, and pack animals affect travel speed. |
| Party cargo | Physical goods carried by parties | Uses goods catalog ids and composition-derived carrying capacity. |
| Location state | Managed physical location state | Stores city/stronghold/monastery resources and manager actor ids. |
| Goods catalog | Canonical trade goods config | Defines goods ids used by physical resource stores; combat equipment remains separate. |
| Location economy config | Deterministic location metabolism | Defines daily production, consumption, and storage caps for managed locations. |
| Deterministic managers | Actor decision code | Submit authoritative commands without directly mutating simulation state. |
| Runtime event log | Observable in-run simulation history | Used by tests/debug UI; not durable WorldMemory. |
| WorldSim observation service | Local observation adjudication | Converts local physical observations into owner-specific events that can become WorldMemory entries. |
| Event sinks | In-process event adapters | Receive authoritative events without owning simulation state. |
| WorldMemory event mapper | Export contract mapper | Converts selected runtime events to WorldMemory-shaped payloads without owning transport. |
| WorldMemory domain event sink | Durable memory adapter boundary | Sends mapped authoritative events through an explicit WorldMemory transport and records visible failures. |
| Game session factory | New-game bootstrap | Creates the initial local authoritative server state. |
| Simulation save codec | Save/load boundary | Serializes and validates authoritative simulation snapshots. |
| Region graph | Source of truth for movement topology | Seeded by `game/data/regions/silesia.json`. |
| Local LLM layer | Renders speech, rumors, descriptions, and player-character intent | Must not own authoritative truth or mutate simulation state. |
| Debug travel panel | Script-built local client harness | Sends real movement commands and renders server snapshots. |
| Presentation maps | Player-facing map artifacts | Must not become simulation truth. |
| Godot client | Rendering, input, UI, local presentation | Reads authoritative state rather than owning gameplay truth. |

## Boundaries

- `game/world/` owns current graph loading/model code.
- `game/simulation/` owns server-authoritative simulation state, command validation, and travel ticking.
- `game/debug/` owns script-built debug UI harnesses for testing local client flows before polished UX.
- `game/data/regions/` owns region data files.
- `game/data/simulation/` owns explicit simulation tuning config.
- `game/tests/` owns Godot test scripts.
- `services/world_memory/` owns the prototype SQLite-backed durable memory API.
- `services/llm_service/` owns the prototype stateless Ollama-backed LLM API.
- `docs/specs/` owns canonical contracts once command/state/config shapes are defined.
- Scene/resource files must be edited through Godot, not manual text patches.

## Data model

Current data centers on region graphs and parties. Region graphs define nodes, edges, passages, waypoint chains, landmarks, and hidden coordinates. Parties are neutral field groups with composition data; composition feeds derived stats such as travel speed. Future trade, rumor, authority, patrol, and conflict state must remain simulation data under authoritative control.

Party knowledge in Godot is intentionally small runtime visibility state. Durable world memory, history, learned facts, rumors, and long-lived NPC/party memory are out of scope for Godot and should live in the separate WorldMemory service with SQLite storage and its own API.

Physical parties are authoritative simulation entities. Information about them lives separately: visibility snapshots expose physically nearby parties, while rumors and remembered sightings belong in WorldMemory.

AI agents may only make strategic decisions from their own WorldMemory context. A deterministic manager can inspect the physical entity it directly manages to submit legal commands, but it cannot use global `server.state` as omniscient knowledge. The current merchant food manager remains a scenario harness; `MerchantMemoryAI` is the first production-direction slice that chooses trade action from owner memory.

Managers direct entities through commands. A mayor, chief, caravan leader, patrol commander, or future AI role should produce commands such as `AssignPartyOrderCommand`; it should not mutate the managed entity directly.

Some parties can be directed by a superior actor without changing their direct manager. In v0, `wroclaw_supply_party_01` is managed by `quartermaster_wroclaw`, while `mayor_wroclaw` is an authorized issuer for high-level `procure_goods` orders. The later supply AI should execute those intents using its own WorldMemory and normal travel/transfer commands.

Long-term command hierarchy should be a generic authority chain, not a fixed set of city layers. A small village may collapse several responsibilities into one actor; a larger village may split supply work to a helper; a city such as Wroclaw may have several levels of authority and several supply parties; a ruler may sit above several cities. Direct superiors should be explicit actor relationships; exceptions should be explicit office/role permissions.

Authority is separate from communication. A superior actor being allowed to issue an order does not mean the order reaches a traveling party instantly. Current v0 only allows direct superior-issued supply orders while the party is physically at the target city node; future remote orders require explicit courier or communication mechanics.

Deterministic manager slices should remain small and testable. The first merchant food manager moves food by submitting `TransferGoodsCommand` and `TravelIntentCommand`, not by editing cargo, resources, or travel state directly.

The first mayor food manager declares location food needs through `DeclareLocationNeedCommand`. It emits observable need events for WorldMemory and future merchant decision logic; it does not directly summon merchants or mutate resources.

Mayor supply planning is separate from need declaration. The planner must check mayor/city WorldMemory for existing active supply intent before issuing a new `procure_goods` order, so repeated re-evaluation does not spam multiple parties for the same shortage. When it does act, it first declares a `mayor_supply_intent_declared` event through `DeclareSupplyIntentCommand`, then issues the physical supply party order. This gives the mayor/location an explicit operational memory entry instead of relying only on the subordinate party's order ledger. Larger settlements can pass an ordered list of candidate supply parties; the planner may skip unavailable parties, but it must still issue at most one supply intent/order per need pass.

Darklands-like local actions should be modeled as timed tasks, not instant time jumps. `AskLocalInformationCommand` starts an `ask_local_information` actor task for the party manager in v0; `SimulationServer.tick()` completes it later and emits the information event.

Subordinate reporting uses the same shape. `ReportBackCommand` validates physical presence, starts a `report_back` actor task, and emits `worldsim_memory_reported`; WorldMemory ingests that event as an explicit report transfer instead of giving managers hidden shared memory.

AI decisions must account for information age. Goods-source memory is not permanent truth: `MemoryFreshnessPolicy` marks source information actionable only while it is recent enough. Stale entries can guide inquiry, but not confident procurement.

Supply intent memory also ages. A months-old active order ledger is not allowed to block a mayor forever; after the configured active-intent window, the planner may issue a new order if the city still has a need.

Supply intent and order memory is append-only. Newer terminal entries such as completed procure orders close older active entries during planning, rather than mutating or deleting old WorldMemory rows.

Order lifecycle changes are explicit, not replacement by implication. `CancelPartyOrderCommand` can cancel an assigned or locally actionable order and emits `party_order_cancelled`. `ReplacePartyOrderCommand` replaces an order only at a local decision point. `InterruptTravelCommand` can stop active travel, but it leaves the party in explicit `interrupted` travel state until a future route-position recovery command resolves where the party goes next.

Parties may later evaluate secondary opportunity policies while pursuing a primary order. Example: a supply party leaving Wroclaw for Opole could carry surplus goods to sell there if cargo, budget, timing, and reserved primary goods allow it. These are not second active orders: they are bounded local checks at safe decision points and must not override the primary order without an explicit lifecycle command.

Task ownership should eventually be actor-based: one actor can run one task, and a party with several available companions can run several actor tasks in parallel. `PartyTaskState` is the current v0 party-lock approximation for actions where the whole party is effectively waiting on the executor.

Report-back is currently a WorldMemory transfer pattern: a subordinate party copies selected private memory to a superior actor or city owner. Later this should become a timed actor task or courier-mediated command.

Locations are also authoritative simulation entities. Their resources and manager ids are physical state; knowledge or rumors about those resources belong in WorldMemory.

Trade goods are defined by a single canonical catalog in `game/data/simulation/goods_catalog.json`. Location resource stores must use catalog `goods_id` values. The catalog is deliberately separate from future combat equipment and character gear.

Parties can carry physical cargo. Carrying capacity is derived from `PartyComposition` through `game/data/simulation/party_cargo.json`; wagons and pack animals are the main capacity sources in v0.

Location economy profiles live in `game/data/simulation/location_economy.json`. The authoritative simulation applies those profiles for full days crossed by `SimulationServer.tick(days)`, clamping consumption at zero and production at storage caps.

## APIs / contracts / specs

Canonical specs live under:

- `docs/specs/`

Do not create duplicate contract definitions without documenting why.

Current command specs:

- `docs/specs/commands/move_party.md`
- `docs/specs/commands/assign_party_order.md`
- `docs/specs/commands/cancel_party_order.md`
- `docs/specs/commands/replace_party_order.md`
- `docs/specs/commands/interrupt_travel.md`
- `docs/specs/commands/declare_supply_intent.md`
- `docs/specs/commands/ask_local_information.md`
- `docs/specs/commands/inspect_local_routes.md`
- `docs/specs/commands/travel_intent.md`
- `docs/specs/commands/transfer_goods.md`

Current event specs:

- `docs/specs/events/runtime_event_log.md`
- `docs/specs/events/world_memory_event_export_v0.md`
- `docs/specs/worldsim/observation_pipeline_v0.md`

Current save specs:

- `docs/specs/saves/simulation_save_v0.md`

Current state specs:

- `docs/specs/state/actor_task_state_v0.md`
- `docs/specs/state/managed_world_parties_v0.md`
- `docs/specs/state/location_state_v0.md`

Current economy specs:

- `docs/specs/economy/goods_catalog_v0.md`
- `docs/specs/economy/party_cargo_v0.md`
- `docs/specs/economy/location_economy_v0.md`
- `docs/specs/economy/merchant_autoplay_scenario_v0.md`
- `docs/specs/economy/mayor_supply_planner_v0.md`
- `docs/specs/economy/city_supply_party_v0.md`
- `docs/specs/economy/quartermaster_ai_v0.md`
- `docs/specs/economy/report_back_intent_v0.md`
- `docs/specs/economy/opportunity_policy_v0.md`

Current region specs:

- `docs/specs/regions/route_geometry_v0.md`

Additional command/state/network/save contracts should be documented under `docs/specs/` before or with implementation.

Client snapshots must not expose full server truth. Use `SimulationServer.get_client_snapshot(party_id)` for UI/client views and reserve `get_snapshot()` for tests/dev diagnostics.

## Runtime / deployment

Local development runs the Godot project under `game/`. Current checks use `tools/check.bat` on Windows or `tools/check.sh` on Unix-like shells. Godot headless checks should be run for modified GDScript files when Godot is available.

The current debug UI is built in script, not `.tscn`, so it can be tested headlessly. It is a client harness and must interact with the simulation through commands and snapshots, not direct state mutation.

Runtime events are generated by the authoritative simulation for local observability. They can later feed adapters, but persistence belongs outside Godot.

WorldMemory export uses a transport-free mapper plus `WorldMemoryDomainEventSink`. Runtime code should use `WorldMemoryQueuedHttpTransport` to queue POSTs to the local `services/world_memory` sidecar at `/domain-events/ingest` without blocking authoritative simulation ticks. Injected test/debug transports remain available for deterministic checks. Retry policy and service lifecycle management are not defined yet.

## Observability

No runtime observability system is defined yet. For now, tests and explicit command/state evidence are the primary verification tools.

## Failure modes

- Missing or malformed region data must fail explicitly.
- Invalid commands must be rejected by the authoritative simulation.
- Presentation map inconsistencies must not mutate simulation truth.
- LLM-generated text must not become authoritative truth unless deterministic simulation state validates it.
- Loader/test failures should point to the exact data or contract violation.
- Rejected party movement commands must not mutate party state.
- Client-visible known routes must come from party knowledge, not full graph neighbors.
- Inspecting local route options must update runtime party knowledge through the authoritative simulation, not directly through UI.

## Open architecture questions

- Broader command schema and validation rules beyond `MovePartyCommand`.
- Save-state format and migration policy for the reboot.
- Player-drawn parchment map journal state shape beyond the reserved `player_map_state` save field.
- Multiplayer transport and snapshot/event replication model.
- How to implement route geometry segments/waypoints in region data and use them for travel time.
- Local LLM prompt, response, and validation contracts.
- How terrain, weather, road type, fatigue, and skills modify party travel speed.
- API boundary between Godot runtime visibility state and the external WorldMemory SQLite service.
