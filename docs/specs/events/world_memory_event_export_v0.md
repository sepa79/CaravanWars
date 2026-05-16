# WorldMemory Event Export v0

## Purpose

`WorldMemory Event Export v0` defines how selected authoritative runtime events are mapped into payloads that can be sent to the local WorldMemory service.

The mapper stays transport-free. The domain event sink owns dispatch to an explicit transport so tests can use an in-process fake transport while local runs can use the HTTP transport.

## Owner / consumers

- Owner: authoritative simulation.
- Producers: runtime simulation events.
- Consumers: WorldMemory domain event sink, WorldMemory HTTP transport, scheduler, tests, debug tooling.

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
- `party_task_started`
- `party_task_completed`
- `party_task_failed`
- `goods_transferred`
- `location_economy_ticked`
- `location_need_declared`
- `worldsim_location_observed`
- `worldsim_party_observed`
- `worldsim_local_information_received`
- `worldsim_memory_reported`

Unknown event types return an empty payload. This is intentional: export must be explicit, not a silent dump of all runtime details.

## Metadata rules

- Include `party_id` and `occurred_day`.
- Include `manager_actor_id` when present in event details.
- Include explicit ids from event details such as `node_id`, `from_node_id`, `to_node_id`, `destination_node_id`, and `edge_id`.
- Include order metadata such as `issued_by_actor_id`, `order_type`, `target_location_id`, `goods_id`, and `amount`.
- Include `target_node_id` for location-targeted orders when the authoritative simulation resolved it during validation.
- Include task metadata such as `task_type`, `query_type`, `duration_days`, and `failure_code`.
- Include report metadata such as `from_owner_id`, `to_owner_id`, `to_owner_kind`, `max_entries`, `trust`, `distortion_noise`, `listener_interest_tags`, and `notes`.
- Include bounded counts such as `discovered_edge_count`.
- Do not export the full region graph.
- Do not export full party knowledge.
- Do not write durable WorldMemory directly from the mapper.

## Event sinks

`SimulationServer` supports in-process event sinks. Sinks receive authoritative events after the runtime event log is appended.

Current sinks:

- runtime event log, owned directly by `SimulationServer`,
- test sink for assertions,
- `WorldMemoryDomainEventSink`, which maps exportable events and submits them to a configured transport.

Current transports:

- `WorldMemoryHttpTransport`: sends `POST /domain-events/ingest` to the local WorldMemory service.
- `WorldMemoryQueuedHttpTransport`: queues payloads and sends them through non-blocking `HTTPClient` processing.
- `TestWorldMemoryDomainTransport`: stores payloads in memory for tests.
- `WorldMemoryJsonlTransport`: writes JSONL payloads for offline/debug harnesses.

`WorldMemoryDomainEventSink` must be configured with a transport. Missing transport, missing transport method, non-2xx HTTP status, connection failure, and test transport failures are recorded in `failed_exports` and pushed as Godot errors by default. Tests may disable Godot error emission while still asserting `failed_exports`. There is no hidden fallback write.

Runtime gameplay should prefer `WorldMemoryQueuedHttpTransport` over direct synchronous HTTP. `send_domain_event()` must return quickly and only queue work; callers then pump `process_queue()` from a scheduler, service node, or test loop. Transport failures remain visible through `failed_results`.

`WorldMemoryHttpTransport` defaults to:

```text
host: 127.0.0.1
port: 8011
path: /domain-events/ingest
tls: false
```

The default target matches the local sidecar documented under `services/world_memory/`.

## Test coverage

Covered by `game/tests/WorldMemoryEventExportTest.gd`:

- event sink receives authoritative events,
- arrival maps to a WorldMemory-shaped world event,
- local route inspection exports bounded metadata and not full graph/knowledge,
- domain event sink sends mapped payloads through an injected transport,
- domain event sink records explicit transport failures,
- unknown event types are ignored explicitly.

Covered by optional `tools/run_merchant_world_memory_integration.ps1`:

- merchant autoplay exports domain event payloads from Godot,
- queued Godot HTTP transport ingests those payloads through `/domain-events/ingest`,
- WorldMemory creates merchant and location memory entries for the scenario.

WorldMemory domain ingest currently creates per-owner memory entries for:

- `goods_transferred`
- `location_economy_ticked`
- `location_need_declared`
- `worldsim_location_observed`
- `worldsim_party_observed`
- `worldsim_local_information_received`
- `worldsim_memory_reported`
- `party_travel_started`
- `party_arrived`
- `party_order_assigned`
