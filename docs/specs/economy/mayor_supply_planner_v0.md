# Mayor Supply Planner v1

## Purpose

`Mayor Supply Planner v1` prevents the mayor from spamming supply orders for the same need while accounting for memory age.

It does not model contracts, production chains, pricing, or market search. It only turns an existing remembered need into one explicit mayor supply intent and one supply party order when no active supply intent already exists.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: mayor managers, city supply parties, WorldMemory decision context, tests.

## Inputs

`MayorSupplyPlanner.process(server, location_id, supply_party_id, memory_entries)` receives:

- the authoritative server,
- the managed city location,
- the candidate supply party,
- memory entries for the mayor/city context.

`MayorSupplyPlanner.process_candidates(server, location_id, supply_party_ids, memory_entries)` receives the same context plus an ordered candidate list. The list order is deterministic planner policy: the first available party is selected.

The planner may inspect the physical state of the location and candidate supply party, but it must use `memory_entries` for strategic context such as declared needs and already issued orders.

## Required memory

The planner needs a `need_ledger` entry for the city and goods id.

It refuses to issue a new order when memory already has an active:

- `order_ledger`, or
- `mayor_supply_intent`

for the same `target_location_id/location_id + goods_id`.

Statuses `cancelled`, `completed`, and `failed` do not block a new order. Missing status is treated as active.

Active supply intents only block while their memory is recent enough. `MemoryFreshnessPolicy` treats supply intents older than 45 simulation days as no longer active for planning. This prevents stale ledgers from blocking a city forever.

WorldMemory is append-only for this flow. A newer terminal `order_ledger` or `mayor_supply_intent` entry with `status = completed`, `failed`, or `cancelled` closes older active entries for the same `party_id/supply_party_id + location + goods` during planning. The planner does not require old memory entries to be deleted or updated in place.

The planner can also read source reports from mayor memory:

- `heard_report`
- `local_information`
- `location_observation`

Goods-source reports are actionable for 14 simulation days. Fresh reports are returned in the planner result as `source_report_status = fresh` with `known_source_locations`. Stale source reports return `source_report_status = stale` and are not passed as actionable source lists. The mayor may still issue a broad procure order; the quartermaster must refresh source knowledge before acting on old reports.

## Behavior

When there is an actionable need and no active duplicate intent, single-party `process(...)`:

1. Checks that the candidate supply party exists.
2. Checks that the party has no active order.
3. Checks that the party is physically at the city node.
4. Submits `DeclareSupplyIntentCommand` for an explicit `mayor_supply_intent_declared` event.
5. Submits `AssignPartyOrderCommand` with `order_type = procure_goods`.

No remote command fallback exists. If the party is away, the planner returns `no_present_supply_party`.

For multi-party `process_candidates(...)`, the planner checks active supply intent first through the same memory rules. It also checks the provided candidate parties for an already active matching `procure_goods` order, because those parties are explicit city assets handed to the planner, not a global world scan. Missing, already ordered, or physically absent parties are reported in `skipped_parties`. The first available candidate receives the intent/order. If no candidate is available, the planner returns `no_available_supply_party`. It must not issue more than one supply intent for the same need in one pass.

The intent declaration is operational memory for the mayor/location. WorldMemory ingests it as `mayor_supply_intent`; later planner passes can use that memory to avoid duplicate orders even if they do not see the party order ledger first.

## Not in v0

- contracts,
- production chains,
- price search,
- selecting among many supply parties,
- retry and stale-order policy,
- advanced retry policy,
- courier delivery of remote orders,
- LLM calls.

## Test coverage

Covered by:

- `game/tests/MayorSupplyPlannerTest.gd`
- `tools/run_mayor_supply_planner_world_memory_integration.ps1`
- `tools/run_supply_loop_world_memory_integration.ps1`
