# Location economy v0

## Purpose

`Location Economy v0` gives managed physical locations a deterministic daily resource metabolism.

This is not a market model, price model, trade AI, or rumor system. It only updates location resource stores from explicit production, consumption, and storage cap profiles.

## Owner / consumers

- Canonical data: `data/simulation/location_economy.json`
- Loader/validator: `game/simulation/LocationEconomyConfig.gd`
- Runtime owner: `SimulationServer.tick(days)`
- Tests: `game/tests/LocationEconomyTest.gd`

## Schema / shape

```json
{
  "schema_version": 0,
  "profiles": [
    {
      "location_id": "wroclaw_city",
      "production_per_day": {
        "coin": 5
      },
      "consumption_per_day": {
        "food": 4
      },
      "storage_caps": {
        "food": 150,
        "coin": 400
      }
    }
  ]
}
```

Fields:

- `location_id`: physical location id from authoritative state.
- `production_per_day`: goods added for each full simulation day.
- `consumption_per_day`: goods removed for each full simulation day.
- `storage_caps`: maximum stored quantity by goods id.

## Runtime rules

- Economy processing runs inside the authoritative simulation tick.
- Only full days crossed by `SimulationServer.tick(days)` are processed.
- Consumption is applied before production.
- Consumption clamps at `0`.
- Production clamps to the configured storage cap.
- Profiles must use goods from `Goods Catalog v0`.
- Every produced or consumed goods id must have a storage cap.
- Locations without profiles are invalid for the current new-game seed.

## Events

When a location changes resources, the simulation appends:

```json
{
  "event_type": "location_economy_ticked",
  "party_id": "",
  "details": {
    "location_id": "wroclaw_city",
    "manager_actor_id": "mayor_wroclaw",
    "elapsed_full_days": 1,
    "resource_changes": {
      "food": -4,
      "coin": 5
    }
  }
}
```

This event is runtime observability only. Durable knowledge about shortages, surpluses, and trade opportunities belongs in WorldMemory.

## Compatibility notes

No migration compatibility is required during the reboot. Breaking profile changes must update tests and docs in the same slice.

## Economy boundary

The economy remains physical and deterministic:

- locations store goods;
- production and consumption change those stores;
- future parties will physically move goods;
- managers will react through commands;
- WorldMemory will store who knows or believes that a location has shortage or surplus.
