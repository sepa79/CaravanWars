# Declare Supply Intent Command

## Purpose

`DeclareSupplyIntentCommand` records a mayor/location operational decision before a physical supply party receives a concrete order.

The command exists so the mayor's own WorldMemory can remember "I already sent or intend to send supply for this need" without reading subordinate memory directly.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: mayor planners, WorldMemory domain ingest, tests, future courier/order delivery flows.

## Command shape

```json
{
  "location_id": "wroclaw_city",
  "issued_by_actor_id": "mayor_wroclaw",
  "supply_party_id": "wroclaw_supply_party_01",
  "goods_id": "food",
  "amount": 40,
  "reason": "food_below_floor"
}
```

## Validation rules

The authoritative simulation rejects the command when:

- `location_id` does not exist,
- `supply_party_id` does not exist,
- `goods_id` does not exist in the goods catalog,
- `amount` is not greater than zero,
- `issued_by_actor_id` is not the location manager,
- `issued_by_actor_id` cannot direct the supply party.

Rejected commands return `CommandResult.accepted=false` with an explicit `error_code`.

## Runtime event

Accepted commands emit:

```text
mayor_supply_intent_declared
```

The event metadata includes:

- `location_id`
- `issued_by_actor_id`
- `manager_actor_id`
- `supply_party_id`
- `supply_party_manager_actor_id`
- `goods_id`
- `amount`
- `status = active`
- `reason`

WorldMemory ingests this event as `mayor_supply_intent` entries for the mayor actor and target location.

## Non-goals

- It does not assign, cancel, or complete a party order.
- It does not deliver orders remotely.
- It does not create contracts or production-chain commitments.
- It does not bypass `AssignPartyOrderCommand`.
