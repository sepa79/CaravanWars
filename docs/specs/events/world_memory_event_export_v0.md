# WorldMemory Event Export v0

## Purpose

`WorldMemory Event Export v0` defines how selected authoritative runtime events are mapped into payloads that can later be sent to the external WorldMemory service.

This is not an HTTP integration. It is a stable export contract and mapper so Godot can stay server-authoritative and testable before transport, retries, queues, and service lifecycle are added.

## Owner / consumers

- Owner: authoritative simulation.
- Producers: runtime simulation events.
- Consumers: future WorldMemory HTTP adapter, scheduler, tests, debug tooling.

## Export payload shape

```json
{
  "export_kind": "world_event",
  "world_event": {
    "id": "party_arrived:player_party:3.000",
    "event_type": "party_arrived",
    "text": "Party player_party arrived at opole.",
    "location_id": "opole",
    "occurred_at": "day:3.000",
    "importance": 0.7,
    "reliability": 1.0,
    "tags": ["simulation", "party_arrived", "player_party", "opole"],
    "metadata": {
      "party_id": "player_party",
      "manager_actor_id": "player_caravan_leader",
      "occurred_day": 3.0,
      "node_id": "opole"
    }
  }
}
```

The inner `world_event` is shaped to match the current `services/world_memory` `WorldEventIn` schema.

## Exported event types

The v0 mapper exports only:

- `party_travel_started`
- `party_arrived`
- `party_local_routes_inspected`
- `party_travel_intent_started`
- `party_travel_intent_completed`
- `party_travel_intent_failed`
- `party_order_assigned`
- `party_order_started`
- `party_order_completed`
- `party_order_failed`

Unknown event types return an empty payload. This is intentional: export must be explicit, not a silent dump of all runtime details.

## Metadata rules

- Include `party_id` and `occurred_day`.
- Include `manager_actor_id` when present in event details.
- Include explicit ids from event details such as `node_id`, `from_node_id`, `to_node_id`, `destination_node_id`, and `edge_id`.
- Include bounded counts such as `discovered_edge_count`.
- Do not export the full region graph.
- Do not export full party knowledge.
- Do not write durable WorldMemory directly from the mapper.

## Event sinks

`SimulationServer` supports in-process event sinks. Sinks receive authoritative events after the runtime event log is appended.

Current sinks:

- runtime event log, owned directly by `SimulationServer`,
- test sink for assertions.

Future sinks may include:

- WorldMemory HTTP adapter,
- file/debug adapter,
- queued scheduler adapter.

Transport failures must be visible and bounded when real adapters are added. Do not add hidden fallback writes.

## Test coverage

Covered by `game/tests/WorldMemoryEventExportTest.gd`:

- event sink receives authoritative events,
- arrival maps to a WorldMemory-shaped world event,
- local route inspection exports bounded metadata and not full graph/knowledge,
- unknown event types are ignored explicitly.
