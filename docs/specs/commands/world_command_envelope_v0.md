# World Command Envelope v0

## Purpose

`World Command Envelope v0` is the single submission interface used by human,
AI, debug, local-singleplayer, and future remote controllers. It dispatches a
canonical command payload without granting the caller direct state mutation.

## Shape

```json
{
  "commandType": "move_party",
  "command": {
    "party_id": "player_party",
    "from_node_id": "wroclaw",
    "to_node_id": "opole"
  }
}
```

V0 `commandType` values are `move_party`, `transfer_goods`,
`set_facility_operation`, `trade_hub_transfer_party_goods`,
`trade_hub_transfer_facility_goods`, `place_trade_hub_order`, and
`cancel_trade_hub_order`. The result repeats `commandType` and contains that
command's canonical result. There is no heuristic command detection, payload
conversion, or fallback handler.

The generic Facility operation payload is:

```json
{
  "commandType": "set_facility_operation",
  "command": {
    "issuerActorId": "operations_manager",
    "facilityId": "farm",
    "operation": "pause"
  }
}
```

`operation` is `pause` or `resume`. WorldSim checks the issuer against the
Facility's generic Governance record and the `facility:operate` scope. Missing
foundation configuration and denied authority are explicit rejections. Roles,
ownership, AI controller type, and superior status do not bypass this check.

## Owner / consumers

- Owner and validator: `packages/world-sim`.
- Consumers: browser host adapters, deterministic AI, local singleplayer, and
  future network transports.

Transport endpoints may accept a bare canonical payload when their route
already fixes the command type, but they must wrap it in this envelope before
submitting it to `WorldSimulation`.

Trade Hub commands carry canonical command ids. A semantically identical retry
returns the stored result without applying another mutation; reusing an id for
a different payload is an explicit conflict. The older travel,
location-transfer, and Facility-operation commands remain an in-process v0
boundary and must not be retried automatically until their own canonical
idempotency contract is added.
