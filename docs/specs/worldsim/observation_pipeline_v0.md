# WorldSim observation pipeline v0

## Purpose

`WorldSim observation pipeline v0` defines how physical local observations become durable WorldMemory entries.

AI agents should not scan the authoritative world state as knowledge. They should receive memory that was produced by observation, rumor transfer, direct command results, or explicit manager events.

## Owner / consumers

- Owner: authoritative simulation / WorldSim.
- Producer: `WorldSimObservationService`.
- Consumers: WorldMemory event export, future MerchantAI, MayorAI, LLM decision orchestration.

## V0 behavior

`WorldSimObservationService.observe_local_context(server, observer_party_id)`:

- accepts one observer party id;
- observes locations at the observer party's current node;
- observes idle parties at the same node through `SimulationServer.get_visible_parties_for_party`;
- emits runtime events through the authoritative simulation;
- does not write WorldMemory directly.

V0 observation score:

```text
base 1
+ up to 2 from guard_count
+ 1 if horse_count > 0
```

This is a placeholder until character stats exist. Later versions should use actor perception, alertness, fatigue, weather, terrain, social access, disguise, stealth, crowding, light, and stress.

## Events

`worldsim_location_observed` metadata:

- `owner_id`
- `owner_kind`
- `observer_party_id`
- `node_id`
- `observed_location_id`
- `observed_location_type`
- `observed_manager_actor_id`
- `observation_score`
- `observed_resources`, only when the observation score is high enough.

`worldsim_party_observed` metadata:

- `owner_id`
- `owner_kind`
- `observer_party_id`
- `node_id`
- `observed_party_id`
- `observed_party_type`
- `observed_manager_actor_id`
- `observation_score`

## WorldMemory mapping

WorldMemory ingest creates entries owned by `owner_id`:

- `worldsim_location_observed` -> `location_observation`
- `worldsim_party_observed` -> `party_observation`
- `worldsim_route_waypoint_observed` -> `route_observation`

The entry metadata source is `worldsim_observation`.

## LLM planning hook

LLM decision jobs should receive observation memory entries from WorldMemory. They should not receive raw `server.state` snapshots except for immediate legal-action affordances that the actor can actually use.
