# Interrupt Travel Command

## Purpose

`InterruptTravelCommand` lets an authorized actor explicitly stop a party's active travel.

This is the first safe interruption slice. It records that the party is no longer progressing along the route, but it does not yet solve road-position recovery, ambush handling, pursuit, or rejoining the graph.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: player intent layer, deterministic manager code, future AI managers, combat/encounter systems.

## Command shape

```json
{
  "party_id": "merchant_party_01",
  "issued_by_actor_id": "merchant_miroslaw",
  "reason": "ambush_spotted"
}
```

## Validation rules

The authoritative simulation rejects the command when:

- `party_id` does not exist,
- `issued_by_actor_id` is neither the party's `manager_actor_id` nor listed in `authorized_issuer_actor_ids`,
- `reason` is empty,
- the party is not currently traveling.

## Execution

When accepted:

1. The party travel state becomes `interrupted`.
2. Current origin, destination, route plan, distance, and progress remain on the party state.
3. The party no longer advances during `SimulationServer.tick()`.
4. The party is not treated as idle and cannot trade, report locally, receive normal replacement orders, or appear as physically present at the last node.
5. If the party had a non-terminal order, that order becomes `interrupted`.
6. The simulation emits `party_travel_interrupted` and, when applicable, `party_order_interrupted`.

The command intentionally does not choose a new node. Current route state has no road-segment position, so any automatic "nearest node" behavior would be fake precision.

## Follow-up requirement

Recovery from `interrupted` needs a future route-position model, probably after route edges gain segments/waypoints. Future commands may include:

- `resume_interrupted_travel`
- `return_to_origin`
- `continue_to_destination`
- `flee_from_encounter`
- `camp_on_route`

## Test coverage

Covered by `game/tests/PartyOrdersTest.gd` and `game/tests/SimulationSaveCodecTest.gd`:

- manager can interrupt active order travel,
- interrupted travel stops ticking,
- interrupted travel state is save/load durable.
