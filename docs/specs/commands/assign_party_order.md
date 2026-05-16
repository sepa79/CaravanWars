# Assign Party Order Command

## Purpose

`AssignPartyOrderCommand` lets a manager actor assign a deterministic order to a physical party entity.

This is the first boundary for mayors, chiefs, caravan leaders, patrol commanders, and future AI/human managers to direct entities without owning simulation state directly.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: player intent layer, deterministic manager code, future AI managers, future LLM-assisted manager decisions.

## Command shape

```json
{
  "party_id": "merchant_party_01",
  "issued_by_actor_id": "merchant_miroslaw",
  "order_type": "travel_to",
  "target_node_id": "raciborz",
  "route_node_ids": []
}
```

## Validation rules

The authoritative simulation rejects the command when:

- `party_id` does not exist,
- `issued_by_actor_id` is not the party's `manager_actor_id`,
- the party already has an assigned or active order,
- `order_type` is unsupported,
- `target_node_id` does not exist.

Rejected commands return `CommandResult.accepted=false` with an explicit `error_code`.

## Order model

Current order state lives on `PartyState.order`.

Current supported order type:

- `travel_to`

Current statuses:

- `none`
- `assigned`
- `active`
- `completed`
- `failed`

## Execution

Simulation ticks process assigned orders.

For `travel_to`:

1. If the party is idle and not already at target, the server submits the existing `TravelIntentCommand`.
2. If travel intent is accepted, order status becomes `active`.
3. If travel intent is rejected, order status becomes `failed`.
4. When the party reaches the target node, order status becomes `completed`.

The order system must not introduce a parallel movement model.

## Runtime events

- `party_order_assigned`
- `party_order_started`
- `party_order_completed`
- `party_order_failed`

## Test coverage

Covered by `game/tests/PartyOrdersTest.gd`:

- manager can assign a travel order,
- non-manager assignment is rejected,
- order starts travel intent on tick,
- order completes after arrival,
- save/load preserves assigned order state.
