# Report Back Command

## Purpose

`ReportBackCommand` lets a physically present actor report party-owned WorldMemory to another physically present actor through the authoritative simulation.

It replaces direct gameplay use of `POST /memory-transfer` for the mayor/quartermaster supply loop.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: quartermasters, mayors, supply parties, future couriers, WorldMemory integration.

## Command shape

```json
{
  "party_id": "wroclaw_supply_party_01",
  "actor_id": "quartermaster_wroclaw",
  "recipient_actor_id": "mayor_wroclaw",
  "recipient_owner_kind": "actor",
  "location_id": "wroclaw_city",
  "max_entries": 3,
  "trust": 0.9,
  "distortion_noise": 0.02,
  "listener_interest_tags": ["food", "wroclaw_city"],
  "notes": "Supply party report back"
}
```

## Validation rules

The server rejects the command when:

- the party does not exist,
- the location does not exist,
- the actor is not the party manager in v0,
- the party is not idle,
- the actor already has an active actor task,
- `max_entries` is not positive,
- the party is not physically at the location node,
- the recipient actor is not physically present at that node.

In v0, recipient presence means one of:

- the recipient is the manager actor of a location at that node,
- the recipient is the manager actor of an idle party at that node.

## Behavior v0

The command starts `ActorTaskState` with `task_type = report_back` and `requires_party_lock = true`.

When the task completes, the server emits:

- `party_task_completed`,
- `worldsim_memory_reported`.

WorldMemory ingests `worldsim_memory_reported` by running the same transfer logic as `POST /memory-transfer`, but with `delivery_kind = report`. Created entries are `heard_report`, not `heard_rumor`.

The report source owner is the reporting party. The report recipient owner is `recipient_actor_id`.

## Not in v0

- remote reports,
- couriers or messengers,
- choosing individual memory entry ids in Godot,
- loyalty or deception filters,
- written-report preservation rules,
- LLM summarization.

## Test coverage

Covered by:

- `game/tests/ReportBackCommandTest.gd`
- `services/world_memory/test_domain_ingest.py`
