# City Supply Party v0

## Purpose

`City Supply Party v0` defines the first explicit city-owned field party. It exists so a managed location can act through people instead of through direct resource teleportation.

The v0 slice is intentionally small: the mayor can issue a validated food procurement intent to a supply party. Execution by supply AI is a later slice.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: mayor managers, supply chief or quartermaster managers, future AI decision jobs, WorldMemory integration.

## Initial seed

New game creates `wroclaw_supply_party_01`:

- `party_type`: `city_supply_party`
- `manager_actor_id`: `quartermaster_wroclaw`
- `authorized_issuer_actor_ids`: `["mayor_wroclaw"]`
- starting node: `wroclaw`
- cargo: coin only in v0
- composition includes wagons and pack animals sized to carry an initial food procurement order,
- known local route: `odra_crossing` to `wroclaw`, plus the route toward `opole`

## Order flow

The mayor submits `AssignPartyOrderCommand` with:

- `order_type`: `procure_goods`
- `target_location_id`: the city location to supply
- `goods_id`: the requested goods id
- `amount`: requested quantity

The server validates the target location, goods catalog id, positive amount, and issuer authorization. Accepted orders are stored on `PartyState.order` and emit `party_order_assigned`.

The v0 direct mayor order is only valid while the supply party is physically at the target city node. If the party is away, the mayor needs a future courier/messenger party or another physical communication path to deliver the order. No remote fallback exists.

When exported to WorldMemory, `party_order_assigned` becomes order ledger memory for:

- the recipient party,
- the issuing actor,
- the direct manager actor when different from issuer,
- the target location when present.

## Memory model

The supply party and mayor do not share hidden Godot memory. They can exchange knowledge through WorldMemory transfers:

- mayor to supply party: orders, needs, known shortages, known sources,
- supply party to mayor: journey observations, purchases, failed attempts, dangers,
- mayor to others: forwarded reports or rumors, later filtered by loyalty and trust.

Structured metadata is the source of truth for reports and decisions. Text is a presentation/debug rendering and can be generated later by LLM.

## Authority chain

The hierarchy should stay generic. Most important actors can have a superior actor, like a linked list of responsibility:

```text
ruler -> mayor -> quartermaster -> supply party leader
```

The exact number of layers can vary by polity, city, faction, household, or military unit. A village headman can be the quartermaster and caravan leader at once. A bigger village may have one supply helper. A city such as Wroclaw may have several authority levels and several supply parties. The simulation should not hard-code one fixed city hierarchy.

For v0, `authorized_issuer_actor_ids` is enough to express one concrete seed chain: Wroclaw mayor can issue high-level orders to a quartermaster-managed party. This is one valid chain, not the only valid chain.

Future authority checks should use role, office, loyalty, trust, distance, and communication state rather than assuming direct access to every subordinate at all times.

## Future order interruption

`procure_goods` is a normal priority order. Future emergency orders such as flee, defend, evade, pursue, regroup, or protect cargo must be able to suspend, replace, or cancel it.

Interrupts should still be commands with explicit issuer, reason, priority, and audit trail. They must not mutate party travel state silently.

## Not in v0

- autonomous execution of `procure_goods`,
- courier or messenger delivery of remote orders,
- prices, barter, ownership permissions, or wages,
- loyalty filtering,
- rumor distortion implementation for structured reports,
- LLM decision calls.

## Test coverage

Covered by:

- `game/tests/ManagedWorldPartiesTest.gd`
- `game/tests/PartyOrdersTest.gd`
