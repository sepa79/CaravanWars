# KM Alexander / No Bad Maps Asset Intake

Raw downloaded files live in `_downloads/`; expanded working copies live in `_extracted/`.
Both directories are ignored by git because they are source asset intake, not curated game assets.

## Downloaded Packs

| Pack | Local ZIPs | Source | License note |
| --- | --- | --- | --- |
| Ogilby Road Atlas Brushes | `ogilby-road-atlas-brushes-2.0.zip`, `ogilby-road-atlas-brushes-2.0-png-pack.zip`, `ogilby-illustrator-road-brushes.zip` | https://kmalexander.com/2019/10/15/ogilby-a-free-17th-century-road-atlas-brush-set-for-fantasy-maps/ | Readme says CC0. |
| de Fer Settlement Brushes | `de-fer-settlement-brushes-2.0.zip`, `de-fer-settlement-brushes-2.0-png-pack.zip` | https://kmalexander.com/2021/09/22/de-fer-settlement-a-free-18th-century-brush-set-for-fantasy-maps/ | Readme says CC0. |
| Vischer Cartography Brushes | `vischer-cartography-brushes-2.0.zip`, `vischer-cartography-brushes-2.0-png-pack.zip` | https://kmalexander.com/2019/12/16/vischer-a-free-17th-century-cartography-brush-set-for-fantasy-maps/ | Readme says CC0. |
| Lumbia Cartography Brushes | `lumbia-cartography-brushes-2.0.zip`, `lumbia-cartography-brushes-2.0-png-pack.zip` | https://kmalexander.com/2018/12/13/lumbia-a-free-sketchy-cartography-brush-set-for-fantasy-maps/ | Readme says CC0. Recheck upstream before shipping final game assets. |

Chronological index:
https://kmalexander.com/free-stuff/fantasy-map-brushes/fantasy-map-brushes-chronological/

## Current Intake Contents

Ignoring macOS archive metadata, the expanded intake currently contains:

- 2477 PNG files
- 4 ABR brush files
- 1 AI file
- 8 TXT readmes
- 1 RTF readme

## Curation Plan

Do not load the whole intake into Godot. Curate small production sets into separate game asset directories, for example:

`prototypes/sketch_map/assets/map_symbol_sets/`

Suggested first pass:

- roads: Ogilby road segments and mile/route marks
- settlements: de Fer village/town/church/inn symbols
- terrain: Vischer hills, forests, riverside marks, bridges if useful
- sketch/noise layer: Lumbia symbols if they match the current parchment style

For dynamic map rendering, prefer normalized transparent PNGs first. SVG tracing can come later for symbols that need recoloring, outline animation, or high zoom.

The renderer should support multiple symbol sets with the same semantic keys. This lets the player's own map use one hand-drawn style while bought, stolen, or gifted maps use different visual hands.
