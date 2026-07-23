# Map Asset Sets

The map renderer should not treat map symbols as one universal art pack.
Caravan Wars needs several interchangeable symbol sets with the same semantic keys.

## Gameplay Use

The player's own travel map should look like one person's rough notes: uneven, partial, practical, and updated while moving.

Bought or found maps can use different hands:

- cheap tavern map: crude symbols, bad scale, sparse landmarks
- merchant route map: better roads, inns, ferries, toll points, market towns
- monastery/church map: churches, abbeys, shrines, old Roman roads, safe lodging
- military or noble map: crossings, forts, watch posts, ambush-prone terrain
- local peasant knowledge: paths, fords, mills, fields, forests, missing official detail

This gives maps mechanical identity without turning them into modern GPS.

## Technical Shape

Use one semantic symbol vocabulary, then resolve it through a selected style set:

```text
settlement.village
settlement.town
settlement.fortified
poi.inn
poi.mill
poi.church
poi.bridge
poi.ford
terrain.forest
terrain.hill
terrain.marsh
road.main
road.local
road.uncertain
```

Suggested asset layout:

```text
prototypes/sketch_map/assets/map_symbol_sets/
  player_rough/
    manifest.json
    settlement/village_01.png
    poi/inn_01.png
  merchant_route/
    manifest.json
  monastery_hand/
    manifest.json
  noble_survey/
    manifest.json
  local_rustic/
    manifest.json
```

Each `manifest.json` should map semantic keys to one or more image variants.
The renderer picks a deterministic variant from map seed plus object id, so symbols stay stable after reload.

## Starting Source Packs

- `player_rough`: Lumbia Sketchy Cartography, with some procedural jitter retained.
- `merchant_route`: Ogilby Road Atlas, especially roads, inns, route marks, crossings.
- `monastery_hand`: de Fer and Vischer religious settlements, churches, abbeys, crosses.
- `noble_survey`: Vischer settlements and landforms, cleaner and more authoritative.
- `local_rustic`: de Fer settlements plus simplified terrain/field symbols.

## Important Rule

Map style is presentation, not truth.
A bought map can be beautifully drawn and still wrong.
A rough player note can be ugly and still more accurate because it came from direct travel.

## Player Map Editing Rule

The player map should usually be additive: draw new observations, do not redraw old marks.
If a copied settlement, road, or landmark is wrong but still useful, it stays where the player wrote it.
Travel can upgrade confidence and medium, but should not casually move the mark.

Redrawing is reserved for explicit correction modes or strong anchors:

- bridges and fords anchoring river fragments,
- very large placement errors that make the map unreadable,
- deliberate player action to scrape/wipe and redraw.

This keeps the map human and useful as a route notebook instead of turning it into GPS correction.
