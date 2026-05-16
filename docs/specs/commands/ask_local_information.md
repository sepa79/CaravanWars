# Ask Local Information Command

## Purpose

`AskLocalInformationCommand` is the first reusable intent procedure for asking a physically present location about local knowledge.

It exists so role AI, player intent, and future LLM/voice flows can use the same path for “ask here about food/source/road/etc.” instead of giving AI private shortcuts.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: quartermasters, merchants, player intent layer, future local dialogue/rumor flows, WorldMemory integration.

## Command shape

```json
{
  "party_id": "wroclaw_supply_party_01",
  "actor_id": "quartermaster_wroclaw",
  "location_id": "wroclaw_city",
  "query_type": "goods_source",
  "goods_id": "food"
}
```

## Validation rules

The server rejects the command when:

- `party_id` does not exist,
- `actor_id` is not the party manager in v0,
- `location_id` does not exist,
- party is not idle,
- the actor already has an active actor task,
- party is not physically at the location node,
- `query_type` is unsupported,
- `goods_id` does not exist for `goods_source`,
- the location has no local information for that query.

## Behavior v0

`goods_source` starts an actor task with a duration. The command does not return information immediately.

In v0 the only supported executor is the party manager and the task sets `requires_party_lock = true`. This preserves supply-party behavior while moving ownership toward the one-actor-one-task model.

Flow:

1. Command validates that the party is idle and physically at the location.
2. Server starts `ActorTaskState` with `task_type = ask_local_information`.
3. Server emits `party_task_started`.
4. `SimulationServer.tick(days)` advances task time.
5. When the task completes, the server emits `party_task_completed`.
6. For `goods_source`, the server emits `worldsim_local_information_received` with known source locations.
7. WorldMemory ingest stores owner-specific `local_information` for the asking party.

The command does not mutate cargo, resources, travel state, or durable party knowledge directly. Durable knowledge comes from exporting the completion event to WorldMemory.

## Task ownership direction

Current v0 stores the task in `PartyState.actor_tasks` and treats it as a party-level lock. This is a deliberate approximation for party managers.

Long-term, most city actions should be actor-owned:

- one actor can run one task at a time,
- a party can run several actor tasks in parallel when it has several available people,
- some tasks require a party lock and block everyone,
- travel, combat, major loading, and wagon repair are party-level,
- asking at city offices, market inquiry, hiring, or arranging lodging can be actor-level.

This matters for player parties with companions: the player can ask at one place while a companion visits the market and another looks for lodging. Supply party v0 can remain party-locked because its leader/quartermaster is effectively the required executor.

`QuartermasterAI v0` can use this procedure when it has a `procure_goods` order but no remembered source for the ordered goods.

## Not in v0

- price quotes,
- negotiation,
- deception,
- relationship checks,
- paid informants,
- text dialogue,
- LLM calls,
- source reliability beyond the event metadata.

## Test coverage

Covered by `game/tests/AskLocalInformationCommandTest.gd`.
