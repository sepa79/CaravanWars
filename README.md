# CaravanWars Reboot

CaravanWars is a server-authoritative caravan, trade, travel, rumor, and conflict simulation set in an early medieval, post-Roman inspired world.

The design target is closer to a singleplayer MUD-like world simulation than to a conventional party RPG. Multiplayer-compatible architecture remains useful, but multiplayer is optional and secondary to a trustworthy local simulation.

The reboot keeps the game premise intact:
- players control a caravan, company, patrol, bandit band, or similar field group,
- cities, caravans, patrols, authorities, AI, and future human-controlled roles interact through the same multiplayer-style command layer,
- singleplayer runs as a local authoritative server with a local client,
- world navigation is graph-driven, with parchment maps as imperfect player-facing artifacts.
- historical hierarchy, fear, social status, and unequal protection are core gameplay forces.

The first technical goal is not a pretty map. The first goal is a trustworthy world model:
- region graphs,
- hidden coordinates,
- landmark navigation,
- route waypoint chains,
- authoritative command handling,
- deterministic simulation steps.

## Current Scope

This repository starts with the first region graph seed for Silesia, a minimal Godot data layer that can load and validate that graph, and a first server-authoritative party travel slice. A party is a neutral field group, not just a caravan; composition such as horses and wagons affects derived travel speed.

The first local client harness is a script-built debug travel panel. It is intentionally plain: buttons submit real movement commands to the local authoritative simulation, and labels render server snapshots. This keeps the future voice/LLM/intent UX separate from simulation truth.

Client-visible routes now go through runtime party knowledge. Godot only keeps lightweight visibility state; durable WorldMemory is planned as a separate SQLite-backed service with its own API.

The debug travel panel can check local route options. Local route inspection is a real command: it asks the authoritative simulation to reveal adjacent graph routes into runtime party knowledge, then the UI rerenders from a client snapshot.

The simulation also emits a small runtime event log for travel start, arrival, and local route inspection. This is only an in-run observation stream for tests/debug UI; durable history belongs in the external WorldMemory service.

Selected runtime events can now be mapped to WorldMemory-shaped export payloads through an in-process event sink contract. This is not yet HTTP integration; it prepares the boundary without making Godot depend on service availability.

The first higher-level travel intent is now server-authoritative: a party can ask to travel to a known destination, and the simulation resolves a deterministic route through routes that party actually knows. This keeps future voice/LLM intent UX above the same command and state model as the debug UI.

The world now starts with multiple managed parties. A party is a physical simulation entity managed by a specific actor role such as a caravan leader, bandit chief, or merchant. Client snapshots reveal only physically visible nearby parties; information and rumors about distant parties belong in WorldMemory.

Managed parties can now receive manager-issued orders. `AssignPartyOrderCommand` lets the party's manager assign a deterministic `travel_to` order, which the authoritative simulation executes through the existing travel intent model.

Managed parties can also have authorized issuer actors for hierarchy. The first city supply party is managed by Wroclaw's quartermaster while Wroclaw's mayor can issue a validated `procure_goods` intent through the same party order command.

Party orders now have explicit lifecycle commands for cancellation, local replacement, and active travel interruption. Interrupted travel is durable state, not an automatic return to a city; future route-segment work should resolve how an interrupted party resumes, returns, camps, flees, or continues.

The first quartermaster AI can execute that supply intent from its own order ledger and WorldMemory observations, using the same travel and goods transfer commands as every other party.

The first mayor supply planner uses city/mayor memory to avoid issuing duplicate supply orders for the same need during repeated re-evaluation.

The world also has first managed locations. Cities, strongholds, and monasteries are physical entities attached to graph nodes, with manager actors and small resource stores. Client snapshots expose only the location at the party's current node.

Trade goods now have a first canonical catalog. Location resource stores reference goods ids from `game/data/simulation/goods_catalog.json`; this is a trade/resource contract, not the future combat equipment system.

Parties now have physical cargo and composition-derived carrying capacity. Wagons and pack animals provide most of the carrying capacity in v0; overloaded cargo is rejected when loading authoritative saves.

The first goods transfer command now moves physical goods between an idle party and a managed location at the same node. It is not yet a price, barter, ownership, or permission model.

The first merchant autoplay scenario now runs a deterministic food-moving manager through existing commands. It checks that travel, cargo, transfer, and location economy can operate together without direct state mutation.

Locations now have first deterministic economy profiles. On full simulation days, the authoritative server applies configured production, consumption, and storage caps to managed location resources.

New game bootstrap and save/load now have a first canonical snapshot contract. `Simulation Save v0` stores current day, region graph id, parties, runtime event log, and a reserved `player_map_state` field for the future player-drawn parchment map journal.

NPC and party memory is modeled as private durable memory, not a global rumor board. Important actors exchange copied, distorted memory entries during background meeting ticks; LLMs only occasionally re-render text for important decisions or player-facing output. See `docs/architecture/WORLD_MEMORY_AND_RUMORS.md`.

## Local Services

Prototype sidecar services live under `services/`:

- `services/world_memory` - SQLite-backed actor, party, event, and memory service. It runs locally on port `8011`; see `services/world_memory/README.md`.
- `services/llm_service` - stateless Ollama-backed LLM worker for rumor rendering, NPC decisions, reports, and intent parsing. It runs locally on port `8013`; see `services/llm_service/README.md`.

These are development services for now. Final packaging should hide Python environments and service startup behind the game launcher or bundled executables.
