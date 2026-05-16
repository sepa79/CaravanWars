# Report Back Intent v0

## Purpose

`Report Back Intent v0` defines how a subordinate party or actor reports remembered information to a superior.

This is not a Godot command yet. The current implementation uses WorldMemory `memory-transfer` directly.

## Owner / consumers

- Owner: WorldMemory service.
- Consumers: supply parties, mayors, quartermasters, merchants, future courier and messenger systems.

## Behavior v0

When a supply party reports back:

1. Select entries from the party's private memory.
2. Copy them to the superior actor or city owner through `POST /memory-transfer`.
3. Preserve structured metadata.
4. Add transfer metadata such as `transfer_notes`, credibility, salience, freshness, distortion, hop count, and source chain.

Example:

```json
{
  "from_owner_id": "wroclaw_supply_party_01",
  "to_owner_id": "mayor_wroclaw",
  "to_owner_kind": "actor",
  "location_id": "wroclaw_city",
  "occurred_at": "day:6.250",
  "max_entries": 3,
  "trust": 0.9,
  "listener_interest_tags": ["food", "wroclaw_city"],
  "distortion_noise": 0.02,
  "notes": "Supply party report back"
}
```

## Future direction

Later, report-back should become a timed task or command:

- actor/party must be physically present or use a messenger,
- one actor runs one report task,
- sensitive details may be filtered by loyalty, fear, deception, or rank,
- written reports should preserve structured JSON better than tavern gossip.

## Test coverage

Covered by `services/world_memory/test_domain_ingest.py`.
