# ADR-001 - Project direction ledger

## Status

Accepted

## Context

CaravanWars Reboot is being built through small simulation slices. Many project decisions are intentionally architectural rather than visual: the game should become a living, server-authoritative world simulation before polished UX is added.

This ADR records the durable direction decisions so future agents do not have to reconstruct them from conversation history.

## Decisions

### Server-authoritative simulation

Singleplayer is a local authoritative server plus local client. Multiplayer, AI, debug UI, voice intent, and future human-controlled roles must use the same command and state model.

Canonical references:

- `docs/architecture/SERVER_AUTHORITATIVE_MODEL.md`
- `docs/ARCHITECTURE.md`

### Party, not caravan type

The main movable entity is a party: caravan, pilgrim group, bishop retinue, local lord with escort, patrol, bandit band, supply group, or similar field group. Composition defines practical capability: foot members, horses, wagons, pack animals, guards, cargo capacity, and speed.

Canonical references:

- `docs/specs/state/managed_world_parties_v0.md`
- `docs/specs/economy/party_cargo_v0.md`
- `docs/specs/commands/move_party.md`

### Physical world and information are separate

The physical layer is region graph, route geometry, locations, parties, cargo, resources, travel state, and future road segments. Information is separate and lives in WorldMemory as private actor, party, or location memory.

Danger is physical, not an abstract route stat. A road is dangerous because bandits, hostile retinues, wolves, damaged crossings, blocked bridges, or patrols are there, not because the edge has `risk = 7`.

Canonical references:

- `docs/architecture/WORLD_MEMORY_AND_RUMORS.md`
- `docs/architecture/AI_MEMORY_BOUNDARY.md`
- `docs/specs/regions/route_geometry_v0.md`

### AI memory boundary

AI agents do not have private Godot memory. MerchantAI, MayorAI, QuartermasterAI, future bandits, patrols, and LLM decision jobs may use only their own WorldMemory context plus legal command options.

Deterministic manager code may inspect the entity it directly manages to submit legal commands, but strategic choice must come from owner-specific memory, not a global server-state scan.

Canonical references:

- `docs/architecture/AI_MEMORY_BOUNDARY.md`
- `docs/specs/economy/merchant_memory_ai_v0.md`
- `docs/specs/economy/quartermaster_ai_v0.md`
- `docs/specs/economy/mayor_supply_planner_v0.md`

### WorldMemory is a game service

WorldMemory is part of the game architecture as a local SQLite-backed service with its own API. It is not a debug-only VM stack and should not be replaced by ad hoc Godot memory.

Godot exports authoritative domain events to WorldMemory through explicit event sinks/transports. There is no hidden fallback write.

Canonical references:

- `services/world_memory/README.md`
- `docs/specs/events/world_memory_event_export_v0.md`
- `docs/architecture/WORLD_MEMORY_AND_RUMORS.md`

### Manager hierarchy is generic

Entities are managed by actor roles. A small village may collapse mayor, quartermaster, negotiator, and caravan leader into one actor. A city can have several levels: mayor, quartermaster, guard commander, clerks, messengers, contracted outsiders, and party leaders. A ruler can sit above several settlements.

The long-term model is an explicit superior chain, not hard-coded city layers.

Canonical references:

- `docs/specs/state/managed_world_parties_v0.md`
- `docs/specs/economy/city_supply_party_v0.md`
- `docs/ARCHITECTURE.md`

### Authority is not telepathy

A superior being allowed to issue an order does not mean the order reaches a traveling party instantly. Direct mayor-issued supply orders currently require physical plausibility. Remote orders need a future courier, messenger, or explicit communication mechanism.

Reports also require physical communication: a subordinate reports memory to a superior through `ReportBackCommand`, then WorldMemory transfers entries with distortion and provenance.

Canonical references:

- `docs/specs/commands/assign_party_order.md`
- `docs/specs/commands/report_back.md`
- `docs/specs/economy/report_back_intent_v0.md`

### One primary order, bounded side opportunities

A party has one primary active order. Secondary opportunities can exist later as bounded local policies, not second active orders. Example: a supply party already traveling from Wroclaw to Opole may carry surplus goods to sell there only if cargo, budget, authority, timing, and primary-order reservations allow it.

Opportunity policies must be evaluated at safe decision points and must not redirect travel or override the primary order without an explicit lifecycle command.

Canonical references:

- `docs/specs/economy/opportunity_policy_v0.md`
- `docs/specs/commands/replace_party_order.md`
- `docs/specs/commands/interrupt_travel.md`

### Orders have explicit lifecycle

Order changes are explicit commands. Cancellation, replacement, and travel interruption are not silent mutation or implicit fallback behavior.

Interrupted travel is durable state. The current route model does not know precise road position, so interruption must not pretend the party arrived at the last node. Recovery needs future route-position semantics.

Canonical references:

- `docs/specs/commands/cancel_party_order.md`
- `docs/specs/commands/replace_party_order.md`
- `docs/specs/commands/interrupt_travel.md`
- `docs/specs/commands/assign_party_order.md`

### Local tasks take time

Darklands-like local actions such as asking for information are timed tasks, not instant server time jumps. One actor runs one task; a party with multiple available companions may eventually run multiple actor tasks in parallel.

Canonical references:

- `docs/specs/commands/ask_local_information.md`
- `docs/specs/state/actor_task_state_v0.md`

### Economy should be living, bounded, and explainable

The economy should feel realistic enough to generate believable movement, shortages, and trade, but it must remain bounded and testable. Locations produce and consume goods deterministically; parties move physical cargo through commands; knowledge of shortages and opportunities spreads through WorldMemory.

Do not create omniscient market AI. Merchants and city agents should act on memory, observations, reports, local inquiries, and orders.

Canonical references:

- `docs/specs/economy/goods_catalog_v0.md`
- `docs/specs/economy/location_economy_v0.md`
- `docs/specs/economy/merchant_memory_ai_v0.md`
- `docs/specs/economy/quartermaster_ai_v0.md`
- `docs/specs/economy/mayor_supply_planner_v0.md`

### Route edges need physical geometry

Logical graph edges remain the navigation contract, but roads should gain ordered route segments or waypoints. This supports travel time, interrupted travel recovery, road encounters, visibility, elevation, player-drawn map detail, and parties meeting on the road.

Nodes and route waypoints should eventually support elevation for line-of-sight and visibility.

Canonical references:

- `docs/specs/regions/route_geometry_v0.md`
- `docs/reboot/WORLD_NAVIGATION_REBOOT.md`

### Player maps are drawn notes, not GPS

Parchment maps are presentation artifacts. The region graph is truth.

The player should have a map that is drawn through travel and observation: partial, hand-made, imperfect, and useful. It can show nearby observed places, bridges, fords, landmarks, road fragments, and notes without revealing the full graph.

The map should usually be additive. Old wrong marks can remain faded or scraped only through explicit correction modes or strong anchors. A mostly monochrome hand-drawn look is preferred for the player's own rough map; do not assume modern colored map semantics.

Canonical references:

- `docs/design/MAP_ASSET_SETS.md`
- `docs/reboot/WORLD_NAVIGATION_REBOOT.md`
- `docs/specs/saves/simulation_save_v0.md`

### LLM and voice are intent/presentation layers

Voice, microphone UX, and LLM parsing should produce player-character or NPC intent proposals. They do not own simulation truth. Accepted proposals become normal commands, and rendered text can be shaped by character stats and memory context.

LLM rendering is occasional and mostly for player-facing text, important decisions, rumors, or reports. It should not be called for every memory hop or every simulation tick.

Canonical references:

- `docs/architecture/LOCAL_LLM_ROLE.md`
- `docs/architecture/LLM_SERVICE.md`
- `docs/architecture/WORLD_MEMORY_AND_RUMORS.md`

## Consequences

- New gameplay features should introduce or reuse authoritative commands.
- Specs remain the single source of truth for command, event, save, state, and config contracts.
- Simulation tests should prove behavior through commands and state, not direct mutation.
- Future UX can be advanced, voice-driven, or LLM-assisted without forking gameplay logic.
- Route geometry is a likely prerequisite for robust encounter, interruption recovery, and richer player-map slices.

## Alternatives considered

- Caravan-specific simulation type: rejected because the world needs pilgrim groups, retinues, patrols, bandits, supply parties, and future human-controlled roles.
- Abstract route risk scores: rejected because danger should come from physical world entities.
- Global rumor board: rejected because memory should be per actor, party, and location.
- Omniscient AI managers: rejected because AI decisions must be explainable through owned memory.
- Instant remote orders: rejected because authority and communication are separate.
