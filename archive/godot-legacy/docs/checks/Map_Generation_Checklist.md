Map Generation Checklist

Refer to `/docs/map` for the authoritative map behaviour and data definitions.

- Same seed:
    - Generate a map twice with the same seed.
    - The resulting nodes, edges and rivers are identical, including IDs.
- Different seed:
    - Generate maps with different seeds.
    - Each map still passes validations: road network connected, no dangling edges, river crossings use bridge or ford nodes.
    - Direct roads removed only when detour ≤ margin.
