# Organic Village Generation

This document outlines the planned algorithm for producing more natural village placement and road networks around cities.

## 1. Village placement
- Use weighted Poisson-disk sampling within a ring `Rmin`–`Rmax` with peak density near `Rpeak`.
- Apply density multipliers near existing infrastructure:
  - ×2 within 250 m of any road.
  - ×3 within 400 m of a bridge.
  - ×1.2 on the same riverbank as the city.

## 2. Village clusters
- For each city choose 1–2 hub villages located on the main outward road (preferably Roman).
- Place remaining villages within 1 km of the nearest hub, targeting 4–8 villages per hub.

## 3. Road connections
- Connect each village to the nearest existing road and to 1–2 nearest villages in its cluster.
- Build a minimum spanning tree from these connections and add 20 % random loops for local circuits (0.6–1.2 km).
- All new segments use the standard `road` class.

## 4. Rivers and bridges
- When a planned connection crosses a river:
  - If the nearest bridge is >1.2 km away and ≥2 villages require a crossing, insert a new bridge at the intersection and split the road.
  - Otherwise, redirect the road to the nearest existing bridge.
  - Do not create new bridges within 250 m of a fort.

## 5. Forts and borders
- Split any new road that crosses a kingdom boundary and insert a pair of forts on both sides.

## 6. Rural geometry
- Shape village roads with gentle arcs: add an intermediate point every 120–180 m with 10–30 m jitter and limit straight segments to 250–300 m.
- Prefer T/Y junctions (60–120°) and merge nodes closer than 30 m.
- Add 1–2 short spurs (30–80 m) near each village to represent local paths.

## 7. Demand pruning
- Count how many villages use each segment on the shortest path to hub/city/bridge.
- Remove segments used by a single village unless they shorten the path to a bridge by ≥30 %.
- Tag segments serving ≥60 % of cluster traffic as `main_local`.

## 8. Network cleanup
- Enforce a minimum spacing of 100 m between nearly parallel roads; connect and remove redundant segments.
- Merge segments shorter than 40 m with their neighbours.

