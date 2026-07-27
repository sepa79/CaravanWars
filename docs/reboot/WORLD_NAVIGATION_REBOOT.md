# CaravanWars Reboot - World and Navigation Notes

## Core Direction

- Early medieval, roughly 700-800 AD inspired.
- Historical and post-Roman atmosphere.
- No magic.
- Travel, trade, rumors, orientation, and landmarks matter.
- Social hierarchy, fear, unequal protection, and local power matter.
- The game is primarily a singleplayer MUD-like simulation; multiplayer compatibility is architectural, not the core promise.

## World Structure

The world is not represented as one giant map.

Instead:
- regions exist as separate parchment maps,
- each region is its own graph,
- the player navigates using routes, landmarks, and directions.

Maps are stylized, inaccurate, non-scaled, and narrative-oriented. They are not the source of truth.

## Hidden World Geometry

Under the hood the game uses:
- world coordinates,
- graph nodes,
- road waypoints,
- landmarks,
- travel paths.

The player never sees exact coordinates.

## Main Graph

The graph represents civilization, trade routes, villages, forts, monasteries, crossings, and known roads.

Roads are not straight lines. Roads contain intermediate nodes, turns, bridges, landmarks, inns, forests, and crossings.

Authored route geometry uses ordered polylines/waypoints under each logical
edge. Canonical hourly movement ticks traverse that geometry without turning
every bend into a strategic graph node.

Road orders store a destination, not a path. On every reached graph node the
authoritative simulation chooses the next known edge from the actor's current
private navigation graph. Changing the destination mid-edge preserves the
exact physical coordinate; the next tick may continue or reverse. Time advance
never moves Parties outside ordinary WorldClock events.

## Maps

Maps are visual aids, orientation tools, and artifacts of the world.

They are not GPS, exact geometry, or tactical overlays.

The player uses landmarks, rivers, mountains, roads, and local descriptions.

Example: "Follow the river upstream two camps. Turn left at the willow tree."

## Fog Of War

The player character already knows nearby regions. This is not an amnesia or blank-map discovery game.

Fog of war represents:
- lack of reliable information,
- lack of practical travel knowledge,
- unknown routes,
- missing regional maps.

## Off-Graph Travel

The player can leave roads and leave the known graph.

Examples:
- taking shortcuts,
- fleeing,
- exploring,
- hunting,
- getting lost.

Then the player navigates using landmarks, sun, rivers, terrain, and local memory.

The player may reconnect to the graph when reaching a known road, finding a landmark, meeting travelers, or reaching civilization.

## Runtime Graph Expansion

The graph may expand dynamically during gameplay.

Examples:
- discovered paths,
- hidden camps,
- buried stashes,
- shortcuts,
- player-created landmarks.

The graph becomes both a map of known civilization and a memory of journeys.

## Landmark Navigation

Large landmarks are critical:
- Sleza,
- mountains,
- rivers,
- ruins,
- major forests.

The player travels toward visible landmarks, not toward UI markers.

## Technical Direction

Recommended architecture:
- region graph files,
- hidden world coordinates,
- road waypoint chains,
- parchment map assets,
- lightweight out-of-sight simulation,
- runtime landmark graph extensions.

No open world is required. No giant seamless terrain is required.

## World Tone

See `docs/design/HISTORICAL_WORLD_TONE.md`.

The world should feel socially alien from a 2026 point of view. Rank, wealth, armed followers, patronage, gender, religion, local law, and reputation shape what people dare to say, what violence costs, and who is treated as disposable.
