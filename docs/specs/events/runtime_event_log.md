# Runtime Event Log

## Purpose

The runtime event log records observable simulation events during a local run. It is used for debugging, tests, debug UI, and future adapters that may forward selected events to external systems.

This is not durable WorldMemory. Persistence, long-term memory, and historical world knowledge belong in the separate SQLite-backed WorldMemory service and its API.

## Event shape

```json
{
  "event_type": "party_travel_started",
  "party_id": "player_party",
  "summary": "Party player_party started travel from wroclaw to opole.",
  "day": 0.0,
  "details": {
    "from_node_id": "wroclaw",
    "to_node_id": "opole"
  }
}
```

## Current event types

- `party_travel_started`
- `party_arrived`
- `party_travel_interrupted`
- `party_local_routes_inspected`
- `party_travel_intent_started`
- `party_travel_intent_completed`
- `party_travel_intent_failed`
- `party_order_assigned`
- `party_order_started`
- `party_order_completed`
- `party_order_failed`
- `party_order_cancelled`
- `party_order_replaced`
- `party_order_interrupted`
- `location_economy_ticked`
- `location_need_declared`
- `mayor_supply_intent_declared`
- `party_task_started`
- `party_task_completed`
- `party_task_failed`
- `goods_transferred`
- `worldsim_local_information_received`
- `worldsim_memory_reported`

## Rules

- Events observe authoritative state changes; they do not drive simulation state.
- Events must be emitted by the authoritative simulation, not directly by UI.
- Rejected commands are not recorded in this log yet; debug UI may still show last command result locally.
- Event details should use explicit ids and values from current config/state.

## Test coverage

Covered by:

- `game/tests/PartyTravelCommandTest.gd`
- `game/tests/TravelIntentCommandTest.gd`
- `game/tests/PartyOrdersTest.gd`
- `game/tests/LocationEconomyTest.gd`
- `game/tests/TransferGoodsCommandTest.gd`
- `game/tests/PartyKnowledgeSnapshotTest.gd`
- `game/tests/DebugTravelPanelTest.gd`
