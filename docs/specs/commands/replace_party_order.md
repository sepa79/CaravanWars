# Replace Party Order Command

## Purpose

`ReplacePartyOrderCommand` lets an authorized actor replace a party's current assigned order with a new order at a local decision point.

It is not an active road interruption command. If the party is already traveling, use `InterruptTravelCommand` first.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: player intent layer, deterministic manager code, future AI managers, future LLM-assisted manager decisions.

## Command shape

```json
{
  "party_id": "merchant_party_01",
  "issued_by_actor_id": "merchant_miroslaw",
  "reason": "better_market_information",
  "order_type": "travel_to",
  "target_node_id": "opole",
  "target_location_id": "",
  "goods_id": "",
  "amount": 0,
  "route_node_ids": []
}
```

## Validation rules

The authoritative simulation rejects the command when:

- `party_id` does not exist,
- `issued_by_actor_id` is neither the party's `manager_actor_id` nor listed in `authorized_issuer_actor_ids`,
- `reason` is empty,
- the party has no assigned or active order,
- the party is not at a local decision point (`travel_state` must be `idle`),
- the replacement order payload would be rejected by `AssignPartyOrderCommand`.

Rejected commands return `CommandResult.accepted=false` with an explicit `error_code`.

## Execution

When accepted:

1. The previous order is captured in the result and event metadata.
2. The new order is applied as `assigned`.
3. The simulation emits `party_order_replaced`.

The command does not move the party, mutate cargo, mutate resources, or create hidden recovery behavior.

## Test coverage

Covered by `game/tests/PartyOrdersTest.gd`:

- manager can replace an assigned order,
- replacement while traveling is rejected until travel is interrupted.
