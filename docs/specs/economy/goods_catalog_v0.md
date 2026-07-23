# Goods catalog v0

## Purpose

`Goods Catalog v0` is the canonical list of trade goods that may appear in authoritative simulation resource stores.

It is not a combat equipment catalog. Weapons, armor, character gear, and item stats will use a separate contract later.

## Owner / consumers

- Canonical data: `data/simulation/goods_catalog.json`
- Loader/validator: `game/simulation/GoodsCatalog.gd`
- Initial consumer: `LocationState.resources`
- Economy consumer: `game/simulation/LocationEconomyConfig.gd`
- Tests: `game/tests/GoodsCatalogTest.gd`

## Schema / shape

```json
{
  "schema_version": 0,
  "goods": [
    {
      "goods_id": "food",
      "display_name": "Food",
      "category": "staple",
      "bulk_per_unit": 1.0,
      "base_value": 2,
      "perishable": true,
      "tags": ["consumable", "ration"]
    }
  ]
}
```

Fields:

- `goods_id`: stable simulation identifier.
- `display_name`: developer-readable label for current tooling.
- `category`: coarse grouping for future production/consumption rules.
- `bulk_per_unit`: abstract carrying bulk used by future transport capacity logic.
- `base_value`: deterministic baseline value, not a live market price.
- `perishable`: whether the good can later decay or spoil.
- `tags`: non-authoritative classification hints for deterministic rules.

## Compatibility notes

No migration compatibility is required during the reboot. Breaking catalog changes must update tests and docs in the same slice.

## Validation rules

- `schema_version` must be `0`.
- `goods` must be an array.
- `goods_id` values must be non-empty and unique.
- `display_name` and `category` must be non-empty.
- `bulk_per_unit` must be greater than `0`.
- `base_value` must not be negative.
- `perishable` must be a boolean.
- `tags` must be an array.
- Location resource dictionaries must reference known `goods_id` values and non-negative quantities.

## Economy boundary

This catalog does not make roads risky, locations magical, or markets random. It only names physical goods.

Future economy behavior should be deterministic and bounded:

- locations produce, consume, and store goods;
- parties physically carry goods between locations;
- managers issue commands based on local state and remembered information;
- WorldMemory stores what actors know or believe about shortages, surpluses, trades, and sightings.
