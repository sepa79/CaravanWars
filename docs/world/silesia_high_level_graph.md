# CaravanWars - High-Level Silesia Graph

This is the initial strategic graph used to seed the first region.

The graph represents:
- major settlements,
- major routes,
- landmark regions,
- strategic crossings.

Distances are approximate and intended for gameplay scale, not geographic precision.

## Major Nodes

| ID | Type | Notes |
|---|---|---|
| Prague | major_city | Main southern trade hub |
| Wroclaw | major_city | Main northern trade hub |
| Olomouc | major_city | Moravian trade center |
| Opole | regional_stronghold | River trade |
| Raciborz | regional_stronghold | Southern route |
| Legnica | regional_stronghold | Western military route |
| Glogow | regional_stronghold | Northern crossing |
| Nysa | monastery | Religious/trade location |
| Sudety Pass | mountain_pass | Strategic mountain crossing |
| Odra Crossing | river_crossing | Major river crossing |
| Great Forest | wilderness | Dangerous forest region |

## High-Level Connections

| From | To | Distance (km) |
|---|---|---|
| Prague | Wroclaw | 215 |
| Prague | Olomouc | 210 |
| Prague | Raciborz | 290 |
| Prague | Legnica | 230 |
| Wroclaw | Opole | 80 |
| Wroclaw | Legnica | 65 |
| Wroclaw | Glogow | 90 |
| Wroclaw | Nysa | 85 |
| Wroclaw | Raciborz | 150 |
| Opole | Raciborz | 60 |
| Opole | Olomouc | 145 |
| Raciborz | Olomouc | 100 |
| Raciborz | Nysa | 70 |
| Legnica | Glogow | 55 |
| Nysa | Sudety Pass | 65 |
| Sudety Pass | Prague | 140 |
| Odra Crossing | Wroclaw | 30 |
| Great Forest | Opole | 130 |

## Important Design Notes

- The map is not geographically precise.
- The parchment map is not the source of truth.
- The graph is the source of truth.
- Roads will later become waypoint chains.
- Runtime graph expansion is supported.
- Landmark navigation is core gameplay.

