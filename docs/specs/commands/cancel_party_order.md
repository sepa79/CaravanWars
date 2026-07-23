# Cancel Party Order Command

## Purpose

`CancelPartyOrderCommand` lets an authorized actor explicitly cancel a party order without creating a hidden replacement or fallback path.

This is the first order lifecycle control. Active travel interruption is handled by `InterruptTravelCommand`, not by cancellation.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: player intent layer, deterministic manager code, future AI managers, future LLM-assisted manager decisions.

## Command shape

```json
{
  "party_id": "merchant_party_01",
  "issued_by_actor_id": "merchant_miroslaw",
  "reason": "changed_trade_plan"
}
```

## Validation rules

The authoritative simulation rejects the command when:

- `party_id` does not exist,
- `issued_by_actor_id` is neither the party's `manager_actor_id` nor listed in `authorized_issuer_actor_ids`,
- `reason` is empty,
- the party has no assigned or active order,
- the party is already traveling.

The last rule is deliberate. Cancelling is for local decision points; moving parties must be interrupted first.

## Execution

When accepted:

1. The party order status becomes `cancelled`.
2. The order remains on the party as terminal audit state.
3. The party can receive a new order because terminal orders are treated as idle for assignment.
4. The simulation emits `party_order_cancelled`.

The command does not mutate cargo, location resources, party knowledge, or WorldMemory directly.

## Future interruption model

Emergency order changes should be separate explicit commands, such as:

- `replace_order`
- `interrupt_travel`
- `flee`
- `defend`
- `evade`
- `protect_cargo`

These commands must define what happens to travel progress, current road segment, cargo, escorts, combat state, and whether the previous order may resume.

## Test coverage

Covered by `game/tests/PartyOrdersTest.gd`:

- manager can cancel an assigned order,
- cancelled order allows a new order,
- cancelling active travel is rejected until interruption semantics exist.
