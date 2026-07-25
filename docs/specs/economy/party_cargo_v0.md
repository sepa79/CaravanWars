# Party cargo v0

## Purpose

`Party Cargo v0` defines physical goods carried by parties and the deterministic carrying capacity derived from party composition.

This is not yet a trade command, market order, or equipment system. It only answers: what goods does a party carry, and can that party physically carry them?

## Owner / consumers

- Cargo state: `PartyState.cargo`
- Capacity config: `data/simulation/party_cargo.json`
- Capacity loader: `game/simulation/PartyCargoConfig.gd`
- Capacity calculator: `game/simulation/PartyStatsCalculator.gd`
- Save/load validator: `game/simulation/SimulationSaveCodec.gd`
- Tests: `game/tests/PartyCargoTest.gd`

## State shape

`PartyState.to_dictionary()` includes:

```json
{
  "cargo": {
    "food": 12,
    "coin": 30
  }
}
```

Cargo keys must be `goods_id` values from `Goods Catalog v0`. Cargo amounts are non-negative integers.

## Capacity config shape

```json
{
  "schema_version": 0,
  "foot_capacity_bulk": 0.25,
  "horse_capacity_bulk": 1.0,
  "pack_animal_capacity_bulk": 8.0,
  "wagon_capacity_bulk": 25.0
}
```

Capacity is measured in abstract `bulk`. Cargo used bulk is:

```text
sum(cargo[goods_id] * goods_catalog[goods_id].bulk_per_unit)
```

Capacity is:

```text
foot_count * foot_capacity_bulk
+ horse_count * horse_capacity_bulk
+ pack_animal_count * pack_animal_capacity_bulk
+ wagon_count * wagon_capacity_bulk
```

## Validation rules

- `schema_version` must be `0`.
- Capacity values must not be negative.
- Cargo goods ids must exist in `Goods Catalog v0`.
- Cargo amounts must not be negative.
- Loaded saves must reject party cargo that exceeds composition-derived capacity.

## Economy boundary

Party cargo is physical simulation state. Future transfer and trade commands must mutate it through the authoritative command model, not through direct manager edits.

`TransferGoodsCommand` is the first physical transfer command. It moves goods between party cargo and a managed location at the same node, without yet modeling price or social permission.

## Active TypeScript implementation

`WorldSimulation` owns cargo beside party movement state. It calculates
capacity from the canonical catalog and cargo config, rejects over-capacity
seeds and withdrawals, and exposes cargo through authoritative snapshots.

Trade Hub deposits and pickups use this same physical cargo state. The party
must be idle at the hub node; deposits require carried goods and pickups require
free cargo capacity. Goods become available at another hub only after the party
travels there through normal movement commands and deposits them locally.
