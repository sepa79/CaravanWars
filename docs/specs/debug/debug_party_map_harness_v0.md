# Debug Party Map Harness v0

## Purpose

`Debug Party Map Harness v0` defines the development-only map view in the script-built debug travel panel.

The goal is to compare authoritative world truth with what a selected party can currently know, without making the player map or renderer authoritative.

## Owner / consumers

- Owner: development-only debug clients (`apps/truth-map` for the active Node
  implementation; `game/debug/` for archived Godot evidence).
- Consumers: developers, AI agents, headless debug UI tests.
- Non-consumers: normal player UI, simulation command validation, save contracts.

## Modes

### Party Map

`Party Map` is the default debug mode.

It renders the selected party's visible/known view:

- selected via the debug party selector,
- filtered through `SimulationServer.get_client_snapshot(party_id)` for known nodes and known routes,
- enriched with selected-party `worldsim_route_waypoint_observed` runtime events for observed route landmarks.

The debug adapter may use the authoritative graph only for development layout coordinates, but it must filter rendered marks through party-visible data. This is not the future player map journal contract.

### Truth Map

`Truth Map` is an explicit development mode.

It renders all authored region graph nodes, edges, route geometry, and landmarks. It may read the full authoritative graph. UI labels must make the mode visible so screenshots and test failures do not confuse truth with party knowledge.

## Validation rules

- Debug UI must clearly expose the selected party id.
- Debug UI must clearly expose `Party Map` vs `Truth Map`.
- Normal travel commands must still go through authoritative commands.
- `Party Map` must not render all truth nodes by default.
- `Truth Map` must remain under `game/debug/` or another clearly development-only boundary.

## Active Node migration status

`apps/truth-map` implements the explicit `Truth Map` mode first. It consumes
authoritative graph data and party snapshots through the development-only HTTP
boundary documented in `docs/specs/debug/browser_truth_map_api_v0.md`.

The Node client defaults to `Party Map` and obtains an actor-filtered snapshot
from `packages/world-sim`; it never receives hidden graph facts for this mode.
`Truth Map` remains an explicit selector option and uses the separate full
debug state response.

## Test coverage

Covered by `game/tests/DebugTravelPanelTest.gd`:

- the debug panel exposes party and map mode selectors,
- default party map shows known Wroclaw/Opole but hides unknown Raciborz,
- truth map shows Raciborz and authored route edges,
- route waypoint observations add observed landmarks to the selected party map.
