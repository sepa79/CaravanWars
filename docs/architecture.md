# Architecture Overview

## Autoload Order
The project loads the following autoload scripts in order:
1. `ThemeLoader`
2. `DB`
3. `Sim`
4. `PlayerMgr`
5. `Orders`
6. `AiBridge`
7. `NetBridge`
8. `UiManager`
9. `WorldViewModel`
10. `LoopbackServer`
11. `GlobalNarrator`
12. `Server`

## Startup Sequence
1. Autoloads initialize. The `Server` autoload creates the `World`, connects signals, and sets up the offline multiplayer peer.
2. The main scene (`Main.tscn`) instantiates `Game`, `ClientHuman` (peer 2), and `ClientGuild` (peer 3).
3. Each `Client` joins its `peer_*` group and reports its name to the server.
4. Once both clients are present, the server starts its tick timer and begins the authoritative simulation loop.

## RPC Flow
- Clients send their names and gameplay commands to the server via `report_name` and `cmd` RPCs.
- The server validates commands, advances the simulation, and broadcasts snapshots, logs, and observations to each client.
- Clients update their UI state from snapshots and pass observations to their brains, which may issue further commands.
