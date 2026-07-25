# Specs / Contracts

> Migration note: these files remain behavioral contracts and conformance
> targets while the TypeScript implementation is built. References to Godot
> classes describe archived implementation evidence, not active module
> boundaries. New TypeScript code must depend on canonical data/contracts, not
> on `archive/` paths.

This directory is the canonical home for project specs and contracts.

Use it for:

- simulation command contracts,
- runtime event contracts,
- authoritative state snapshot/event contracts,
- save-state file formats,
- region graph file formats,
- config schemas,
- network replication contracts,
- CLI/tool contracts.

## Rules

- One canonical spec per contract.
- Implementation follows the spec, not the other way around.
- Contract changes must be reviewed.
- Breaking changes must be explicit.
- If generated code is used, document source spec and generation command.
- Do not keep duplicate schemas/DTOs/parsers for the same contract without documenting why.

## Suggested structure

```text
docs/specs/
  README.md
  commands/
  economy/
  events/
  state/
  regions/
  config/
  network/
  saves/
```

## Contract template

```markdown
# Contract name

## Purpose

TODO

## Owner / consumers

TODO

## Schema / shape

TODO

## Compatibility notes

TODO

## Examples

TODO

## Validation rules

TODO
```

## Current canonical references

- Party movement command: `docs/specs/commands/move_party.md`
- World command envelope v0: `docs/specs/commands/world_command_envelope_v0.md`
- Assign party order command: `docs/specs/commands/assign_party_order.md`
- Cancel party order command: `docs/specs/commands/cancel_party_order.md`
- Replace party order command: `docs/specs/commands/replace_party_order.md`
- Interrupt travel command: `docs/specs/commands/interrupt_travel.md`
- Declare supply intent command: `docs/specs/commands/declare_supply_intent.md`
- Ask local information command: `docs/specs/commands/ask_local_information.md`
- Report back command: `docs/specs/commands/report_back.md`
- Inspect local routes command: `docs/specs/commands/inspect_local_routes.md`
- Travel intent command: `docs/specs/commands/travel_intent.md`
- Transfer goods command: `docs/specs/commands/transfer_goods.md`
- Runtime event log: `docs/specs/events/runtime_event_log.md`
- WorldMemory event export v0: `docs/specs/events/world_memory_event_export_v0.md`
- Simulation save v0: `docs/specs/saves/simulation_save_v0.md`
- Actor task state v0: `docs/specs/state/actor_task_state_v0.md`
- Managed world parties v0: `docs/specs/state/managed_world_parties_v0.md`
- Location state v0: `docs/specs/state/location_state_v0.md`
- Generic governance v0: `docs/specs/state/governance_v0.md`
- Goods catalog v0: `docs/specs/economy/goods_catalog_v0.md`
- Party cargo v0: `docs/specs/economy/party_cargo_v0.md`
- Location economy v0: `docs/specs/economy/location_economy_v0.md`
- Facilities v0: `docs/specs/economy/facilities_v0.md`
- Trade Hub v0: `docs/specs/economy/trade_hub_v0.md`
- Merchant autoplay scenario v0: `docs/specs/economy/merchant_autoplay_scenario_v0.md`
- Merchant memory AI v0: `docs/specs/economy/merchant_memory_ai_v0.md`
- Mayor food manager v0: `docs/specs/economy/mayor_food_manager_v0.md`
- Mayor supply planner v0: `docs/specs/economy/mayor_supply_planner_v0.md`
- City supply party v0: `docs/specs/economy/city_supply_party_v0.md`
- Quartermaster AI v0: `docs/specs/economy/quartermaster_ai_v0.md`
- Report back intent v0: `docs/specs/economy/report_back_intent_v0.md`
- Opportunity policy v0: `docs/specs/economy/opportunity_policy_v0.md`
- Debug party map harness v0: `docs/specs/debug/debug_party_map_harness_v0.md`
- Browser Truth Map API v0: `docs/specs/debug/browser_truth_map_api_v0.md`
- World Clock v0: `docs/specs/state/world_clock_v0.md`
- Party Map snapshot v0: `docs/specs/state/party_map_snapshot_v0.md`
- World physical layers v0: `docs/specs/regions/world_physical_layers_v0.md`
- Planned route geometry v0: `docs/specs/regions/route_geometry_v0.md`
- Route observation integration v0: `docs/specs/worldsim/route_observation_integration_v0.md`
- WorldSim observation pipeline v0: `docs/specs/worldsim/observation_pipeline_v0.md`
- Region graph seed data: `data/regions/silesia.json`
- Region graph loader/model code: `game/world/`
- Party travel config: `data/simulation/party_travel.json`
- Server-authoritative architecture: `docs/architecture/SERVER_AUTHORITATIVE_MODEL.md`
- World navigation reboot: `docs/reboot/WORLD_NAVIGATION_REBOOT.md`
