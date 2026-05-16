# Sketch Map Lab

Isolated Godot prototype for the player-made parchment map.
It currently uses the curated `de_fer_player_rough` symbol set from the KM Alexander / No Bad Maps intake.

This does not use the main CaravanWars simulation yet. It is a sandbox for proving the UX and renderer:

- incomplete map built while travelling,
- stable positional error per discovered place,
- separate layers for travelled, seen, and heard information,
- dotted uncertain routes for rumors,
- only local river fragments near known crossings,
- hand-drawn PNG icons with procedural fallbacks,
- generated bought regional maps with visible quality and their own positional error,
- pan, zoom, and clickable map marks.

## Run

Open this folder as a Godot project:

```text
prototypes/sketch_map
```

or run:

```powershell
godot --path C:\Users\Sepa\Downloads\CaravanWarsReboot\prototypes\sketch_map
```

## Prototype Boundaries

This lab intentionally does not touch:

- `game/world`,
- `game/simulation`,
- command models,
- travel logic,
- WorldMemory.

Later integration should move the stable parts into `game/map/` and feed them from simulation snapshots plus WorldMemory map notes.

## Technical Idea

The true graph has hidden coordinates. The player map stores map coordinates with stable noise:

```text
true graph position
-> map position
-> stable error based on node/source/player seed
```

Sources affect accuracy:

```text
visited: solid ink, low error
seen: light ink, medium error
heard: dotted ink, high error
```

The runtime renderer should stay deterministic and clickable. LLMs may later write map notes, but should not own map layout.

## Symbol Sets

The active set is declared in `scripts/SketchMapCanvas.gd` and loaded from:

```text
assets/map_symbol_sets/de_fer_player_rough/manifest.json
```

The manifest maps game-level symbol kinds such as `inn`, `village`, `town`, `ford`, `bridge`, `mill`, `camp`, and `hill` to small curated PNG files. This keeps the renderer ready for alternate bought/found map styles later.
