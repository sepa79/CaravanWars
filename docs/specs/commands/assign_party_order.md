# Assign Party Order Command

## Purpose

`AssignPartyOrderCommand` lets an authorized actor assign a deterministic order to a physical party entity.

This is the first boundary for mayors, chiefs, caravan leaders, patrol commanders, and future AI/human managers to direct entities without owning simulation state directly.

A party always has one `manager_actor_id`. Some parties also have `authorized_issuer_actor_ids`, allowing a superior actor to issue high-level intent without replacing the party's direct manager. Example: Wroclaw's mayor can issue a food procurement intent to `wroclaw_supply_party_01`, but the party is still managed by `quartermaster_wroclaw`.

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
  "target_location_id": "",
  "goods_id": "",
  "amount": 0,
  "route_node_ids": []
}
```

`procure_goods` order example:

```json
{
  "party_id": "wroclaw_supply_party_01",
  "issued_by_actor_id": "mayor_wroclaw",
  "order_type": "procure_goods",
  "target_node_id": "",
  "target_location_id": "wroclaw_city",
  "goods_id": "food",
  "amount": 40,
  "route_node_ids": []
}
```

## Validation rules

The authoritative simulation rejects the command when:

- `party_id` does not exist,
- `issued_by_actor_id` is neither the party's `manager_actor_id` nor listed in `authorized_issuer_actor_ids`,
- the party already has an assigned or active order,
- `order_type` is unsupported,
- `target_node_id` does not exist for `travel_to`,
- `target_location_id` does not exist for `procure_goods`,
- `goods_id` does not exist in the goods catalog for `procure_goods`,
- `amount` is not greater than zero for `procure_goods`,
- an authorized issuer that is not the party's direct manager tries to issue a `procure_goods` order while the party is not physically at the target location node.

Rejected commands return `CommandResult.accepted=false` with an explicit `error_code`.

## Order model

Current order state lives on `PartyState.order`.

Current supported order types:

- `travel_to`
- `procure_goods`

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

For `procure_goods` in v0:

1. The server validates and stores the high-level intent.
2. The order is not executed by `SimulationServer.tick()` yet.
3. Future supply AI should read the order plus its own WorldMemory and submit normal travel/transfer commands.
4. The order must not let the mayor or supply chief scan global server state as knowledge.
5. A superior issuer does not have remote command telepathy. If the party is away, a future messenger/courier party must physically deliver the order.

## Future interruption model

Current v0 processing ignores active travel when processing stored orders. This is intentional until emergency order semantics exist.

Future order changes should be explicit commands:

- `cancel_order`
- `suspend_order`
- `replace_order`
- high-priority emergency orders such as `flee`, `defend`, `evade`, `pursue`, `regroup`, or `protect_cargo`

Every interruption should record issuer, reason, priority, previous order, and whether the previous order may resume. This matters for ambushes, pursuit, panic, loyalty, and chain-of-command disputes.

## Runtime events

- `party_order_assigned`
- `party_order_started`
- `party_order_completed`
- `party_order_failed`

## Test coverage

Covered by `game/tests/PartyOrdersTest.gd`:

- manager can assign a travel order,
- non-authorized assignment is rejected,
- order starts travel intent on tick,
- order completes after arrival,
- mayor can assign Wroclaw supply procurement intent,
- unrelated actor cannot assign Wroclaw supply procurement intent,
- save/load preserves assigned order state.
