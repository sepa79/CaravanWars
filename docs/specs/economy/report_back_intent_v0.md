# Report Back Intent v0

## Purpose

`Report Back Intent v0` defines how a subordinate party or actor reports remembered information to a superior.

Gameplay now uses `ReportBackCommand` in Godot. The WorldMemory service still owns the actual memory-copy semantics through the same transfer logic used by `POST /memory-transfer`.

## Owner / consumers

- Owner: WorldMemory service.
- Consumers: supply parties, mayors, quartermasters, merchants, future courier and messenger systems.

## Behavior v0

When a supply party reports back:

1. `ReportBackCommand` validates physical presence and starts a timed actor task.
2. The task emits `worldsim_memory_reported`.
3. WorldMemory ingests the event and transfers entries from the party's private memory to the superior actor.
4. Structured metadata is preserved.
5. Transfer metadata such as `transfer_notes`, credibility, salience, freshness, distortion, hop count, source chain, and `delivery_kind = report` is added.

Example:

```json
{
  "party_id": "wroclaw_supply_party_01",
  "actor_id": "quartermaster_wroclaw",
  "recipient_actor_id": "mayor_wroclaw",
  "recipient_owner_kind": "actor",
  "location_id": "wroclaw_city",
  "max_entries": 3,
  "trust": 0.9,
  "listener_interest_tags": ["food", "wroclaw_city"],
  "distortion_noise": 0.02,
  "notes": "Supply party report back"
}
```

## Future direction

Later report-back should support:

- remote reports through messenger parties,
- one actor runs one report task,
- sensitive details may be filtered by loyalty, fear, deception, or rank,
- written reports should preserve structured JSON better than tavern gossip.

## Test coverage

Covered by:

- `game/tests/ReportBackCommandTest.gd`
- `services/world_memory/test_domain_ingest.py`
