# Mayor Supply Planner v0

## Purpose

`Mayor Supply Planner v0` prevents the mayor from spamming supply orders for the same need.

It does not model contracts, production chains, pricing, or market search. It only turns an existing remembered need into one supply order when no active supply intent already exists.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: mayor managers, city supply parties, WorldMemory decision context, tests.

## Inputs

`MayorSupplyPlanner.process(server, location_id, supply_party_id, memory_entries)` receives:

- the authoritative server,
- the managed city location,
- the candidate supply party,
- memory entries for the mayor/city context.

The planner may inspect the physical state of the location and candidate supply party, but it must use `memory_entries` for strategic context such as declared needs and already issued orders.

## Required memory

The planner needs a `need_ledger` entry for the city and goods id.

It refuses to issue a new order when memory already has an active:

- `order_ledger`, or
- `mayor_supply_intent`

for the same `target_location_id/location_id + goods_id`.

Statuses `cancelled`, `completed`, and `failed` do not block a new order. Missing status is treated as active.

## Behavior

When there is an actionable need and no active duplicate intent, v0:

1. Checks that the candidate supply party exists.
2. Checks that the party has no active order.
3. Checks that the party is physically at the city node.
4. Submits `AssignPartyOrderCommand` with `order_type = procure_goods`.

No remote command fallback exists. If the party is away, the planner returns `no_present_supply_party`.

## Not in v0

- contracts,
- production chains,
- price search,
- selecting among many supply parties,
- retry and stale-order policy,
- courier delivery of remote orders,
- LLM calls.

## Test coverage

Covered by `game/tests/MayorSupplyPlannerTest.gd`.
