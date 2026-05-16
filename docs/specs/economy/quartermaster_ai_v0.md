# Quartermaster AI v0

## Purpose

`Quartermaster AI v0` is the first supply executor for a city-owned supply party.

It does not decide city policy. The mayor issues a high-level `procure_goods` order; the quartermaster executes that order through normal authoritative commands.

The mayor's direct order is not remote telepathy. In v0, superior-issued supply orders require the supply party to be physically at the target city node. Later remote orders should be delivered by messenger/courier parties or another explicit communication mechanism.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: city supply parties, future mayor managers, WorldMemory decision context, tests.

## Inputs

`QuartermasterAI.process(server, party_id, memory_entries)` receives:

- the authoritative server,
- the managed party id,
- memory entries fetched for that party from WorldMemory.

The AI may inspect the physical state of its own managed party and its current order. Strategic knowledge must come from `memory_entries`, not from scanning global server state.

## Required memory

For `procure_goods`, the AI needs:

- an `order_ledger` matching the party, target location, order type, and goods id,
- `target_node_id` on that order ledger or another memory entry that maps the target location to a node,
- at least one `location_observation` for a source location with observed stock of the ordered goods.

## Behavior

When idle and assigned/active on `procure_goods`, v0 can:

- ask the current local location for goods-source information when no source memory exists,
- travel to the best remembered source,
- withdraw ordered goods from that source when physically present,
- return to the target node,
- deposit carried goods at the target location,
- mark the order completed after deposit.

All movement and transfer actions use existing authoritative commands. The AI does not mutate cargo, resources, travel state, or location resources directly.

`ask_local_information` is not instant. QuartermasterAI starts the task, then later re-evaluates after simulation time advances and WorldMemory contains a resulting `local_information` entry.

## Not in v0

- pricing or barter,
- partial multi-trip fulfillment,
- choosing between multiple risks or prices,
- loyalty and chain-of-command disputes,
- LLM calls,
- emergency interruption semantics.

## Test coverage

Covered by `game/tests/QuartermasterAITest.gd`.
