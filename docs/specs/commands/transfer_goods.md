# Transfer goods command

## Purpose

`TransferGoodsCommand` moves physical goods between a party cargo store and a managed location resource store at the same graph node.

It does not model price, barter, ownership, legality, or social permission yet. Those must be layered on top of this physical transfer command later.

## Owner / consumers

- Command class: `game/simulation/commands/TransferGoodsCommand.gd`
- Runtime handler: `SimulationServer.submit_transfer_goods(command)`
- Tests: `game/tests/TransferGoodsCommandTest.gd`

## Shape

```json
{
  "party_id": "player_party",
  "location_id": "wroclaw_city",
  "goods_id": "food",
  "amount": 3,
  "direction": "withdraw_from_location"
}
```

Valid `direction` values:

- `withdraw_from_location`: location resources decrease, party cargo increases.
- `deposit_to_location`: party cargo decreases, location resources increase.

## Validation rules

- `party_id` must reference an existing party.
- `location_id` must reference an existing location.
- `goods_id` must exist in `Goods Catalog v0`.
- `amount` must be greater than `0`.
- Party must be idle.
- Party and location must be at the same graph node.
- Withdraw requires enough goods in the location.
- Withdraw must not exceed composition-derived party cargo capacity.
- Deposit requires enough goods in party cargo.
- Rejected commands must not mutate party or location state.

## Events

Accepted transfers append a `goods_transferred` runtime event with:

- `party_id`
- `manager_actor_id`
- `location_id`
- `location_manager_actor_id`
- `node_id`
- `goods_id`
- `amount`
- `direction`
- resulting `party_cargo_amount`
- resulting `location_resource_amount`

This event may be exported to WorldMemory as an observation, but it is still not durable truth by itself.
