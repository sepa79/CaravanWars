# CaravanWars

CaravanWars is a server-authoritative simulation of caravans, trade, travel,
rumors, settlements, and conflict in an early-medieval, post-Roman inspired
world.

The active implementation targets Node.js 22+, strict TypeScript, a
browser-first Canvas client, and a thin Electron desktop shell. Singleplayer
uses the same commands and state model as multiplayer: the local process hosts
the authoritative server and the client talks to it through the normal game
boundary.

## Architecture baseline

- `packages/world-sim` owns authoritative world state and command handling.
- Player caravans, bandit bands, patrols, city authorities, AI agents, and
  future human-controlled roles use the same command interface.
- Authored region data is physical 2D truth. Graph roads are faster geometry,
  not all space or shared knowledge; actor maps project private navigation
  knowledge and uncertainty from WorldMemory.
- Facilities, World Clock, Trade Hubs, and WorldMemory are separate reusable
  components with explicit contracts.
- RouteSecurity keeps local edge risk and task/encounter lifecycle while
  WorldSimulation remains the only owner of physical Parties, cargo and losses.
- The active simulation foundation includes the serializable scheduled-event
  queue, generic scoped governance, and deterministic atomic Facility cycles.
- A Trade Hub is an instance connected to specific Facilities; it is not a
  shared virtual inventory across locations.
- Trade Hub v0 provides location-bound deposits, escrowed limit orders,
  deterministic partial matching, cancellation, and World Clock expiry through
  the canonical command boundary.
- WorldMemory v0 stores deterministic private observations with provenance,
  two simulation timestamps, explicit aging, idempotent ingest, and JSON replay;
  the TradeHub MerchantAI consumes only its owner view and local affordances.
- Shortage effects are configured on needs and recipes, never globally on a
  goods id; GovernorAI responds from private memory through ordinary commands.
- Autonomous Regional Economy v1 has a seasonal extension across ten Silesia
  nodes with explicit Facility profiles, durable animal cohorts, twelve or
  more merchants, and deterministic 1–10 year/batch runs.
- Population, Health & Labour Dynamics v1 closes the harvest-food-health-work
  loop with age cohorts, disease/recovery, rationing, Governor labour policy
  and delayed physical migration.

See `docs/ARCHITECTURE.md`, `docs/adr/ADR-001-project-direction.md`, and
`docs/adr/ADR-002-node-electron-migration.md`.

## Repository layout

- `data/regions` - canonical authored region graphs.
- `packages/world-sim` - active TypeScript simulation foundation.
- `docs` - active architecture, decisions, and contracts.
- `archive/godot-legacy` - the original Godot implementation.
- `archive/godot-reboot` - the later Godot reboot and map prototype.

The archives preserve implementation evidence and history, but active code
must not import from them.

## Development

```bash
npm ci
npm run typecheck
npm test
npm run sim:regional -- --days 30 --seed 17
npm run sim:seasonal -- --years 2 --seeds 3,5,17 --merchants 12
```

Run the development-only browser Truth Map on the Devbox:

```bash
npm run dev:truth-map
```

Open `http://192.168.88.21:4173` from the home LAN or through the configured
WireGuard route. The development harness defaults to an actor-filtered Party
Map and offers an explicit Truth Map selector. Its merchant control runs a
small physical food-delivery loop through the normal command boundary.

Development is hosted on the Devbox. No Godot installation is required for the
active implementation.
