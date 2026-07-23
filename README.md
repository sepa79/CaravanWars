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
- The region graph is physical truth. Parchment maps are actor-specific
  presentation and memory artifacts.
- Facilities, World Clock, Trade Hubs, and WorldMemory are separate reusable
  components with explicit contracts.
- A Trade Hub is an instance connected to specific Facilities; it is not a
  shared virtual inventory across locations.

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
```

Development is hosted on the Devbox. No Godot installation is required for the
active implementation.
