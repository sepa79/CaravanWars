# Silesia Distance Audit

## Method

`distance_km` is route distance, not straight-line distance.

The first audit used modern road routing as a sanity baseline and rounded values to the nearest 5 km. These numbers are not final medieval itinerary research, but they are better for travel time than the earlier straight-line placeholders.

## Provisional Anchors

Some graph nodes are abstract and need physical anchors until the region graph gains route geometry:

- `odra_crossing`: Olawa / Odra crossing near Wroclaw.
- `sudety_pass`: Klodzko / Sudety pass anchor.
- `great_forest`: Kluczbork / Stobrawa forest anchor.

Changing one of these anchors should trigger a distance re-audit for connected edges.

## Updated Edges

| Edge | Old km | Audited km |
| --- | ---: | ---: |
| `prague_wroclaw` | 215 | 285 |
| `prague_olomouc` | 210 | 280 |
| `prague_raciborz` | 290 | 395 |
| `prague_legnica` | 230 | 255 |
| `wroclaw_opole` | 80 | 100 |
| `wroclaw_legnica` | 65 | 80 |
| `wroclaw_glogow` | 90 | 140 |
| `wroclaw_nysa` | 85 | 90 |
| `wroclaw_raciborz` | 150 | 165 |
| `opole_raciborz` | 60 | 80 |
| `opole_olomouc` | 145 | 245 |
| `raciborz_olomouc` | 100 | 120 |
| `raciborz_nysa` | 70 | 85 |
| `legnica_glogow` | 55 | 60 |
| `nysa_sudety_pass` | 65 | 55 |
| `sudety_pass_prague` | 140 | 195 |
| `odra_crossing_wroclaw` | 30 | 25 |
| `great_forest_opole` | 130 | 45 |

## Notes

Several old values were close to straight-line distances. That made long routes too fast and made some short regional routes inconsistent with each other.

`opole_olomouc`, `prague_raciborz`, and `wroclaw_glogow` changed the most. These routes should receive authored geometry before relying on them for encounter timing or map landmarks.
