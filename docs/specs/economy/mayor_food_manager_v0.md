# Mayor food manager v0

## Purpose

`Mayor food manager v0` is the first deterministic location manager slice. It lets a location authority declare a local food need through the authoritative simulation instead of mutating resources or directly steering merchants.

## Owner / consumers

- Manager: `game/simulation/managers/MayorFoodManager.gd`
- Command: `DeclareLocationNeedCommand`
- Scenario test: `game/tests/MayorFoodManagerTest.gd`
- Consumers: WorldMemory, future merchant decision logic, debug tools.

## Manager rule

The v0 manager only handles `food`.

On each processing step:

- if the location is missing, do nothing;
- if local food is at or above the floor, do nothing;
- if local food is below the floor, submit `DeclareLocationNeedCommand`;
- the command must be issued by the location manager actor.

Defaults:

```text
food floor: 30
desired food: 80
```

The manager does not create goods, reserve goods, set prices, summon merchants, or mutate resources directly.

## Runtime event

Accepted commands emit:

```text
location_need_declared
```

Required details:

- `location_id`
- `manager_actor_id`
- `node_id`
- `goods_id`
- `current_amount`
- `desired_amount`
- `needed_amount`
- `reason`

`WorldMemoryEventMapper` exports this event. WorldMemory stores it as a location-owned `need_ledger` memory entry.

## LLM planning hook

Mayor v0 is deterministic. Later LLM-assisted mayor decisions may choose priorities, urgency, diplomatic framing, or trade policy from the mayor actor's own WorldMemory context. The LLM must not mutate location resources or bypass `DeclareLocationNeedCommand`.

## Compatibility notes

No compatibility is required during the reboot.
