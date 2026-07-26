# Facilities v0

Facility recipes must declare a shortage policy for every required input,
energy input, and maintenance input. The policy semantics and recovery episode
rules are canonical in `shortage_consequences_v0.md`; a goods id itself never
implies unrest or another social effect.

## Purpose

A Facility is a concrete managed capability attached to a physical entity or
place. Facilities transform state deterministically and remain reusable across
settings: a farm, smithy, oxygen plant, reactor, warehouse, or habitat module
uses the same lifecycle contract with different configuration.

## Identity and governance

Each Facility has a stable id, type/config reference, physical host,
`owner_id`, and optional `governor_actor_id`. Several Facilities may share one
owner or governor. Ownership does not bypass command authority.

## Production scheduling

An active Facility schedules a serializable `FacilityProductionTickDue`
intent with World Clock. When it becomes due, WorldSim dispatches it to the
Facilities component. The Facility then:

1. validates that the intent matches its current generation and state,
2. reads only its declared local inputs and dependencies,
3. applies one deterministic cycle atomically,
4. emits `FacilityProductionTicked` or an explicit blocked/failed event,
5. returns an optional next `FacilityProductionTickDue` intent.

The Facility controls its cadence, but only World Clock owns simulation time
and queue ordering. Queued intents contain data, never executable callbacks.

## Lifecycle safety

- Start or resume schedules exactly one current-generation production intent.
- Pause, disable, destroy, or reconfigure invalidates the prior generation so
  stale queued intents cannot apply production.
- Handling the same event id twice must not apply the cycle twice.
- Missing inputs, storage capacity, workforce, power, maintenance, or other
  requirements produce explicit outcomes without partial mutation.
- A blocked cycle may schedule a new attempt after an explicit positive retry
  interval. Later arrivals do not retroactively change the blocked outcome.
- The next tick is scheduled from the authoritative cycle boundary, not wall
  time or client frame time.
- Saves include Facility state plus pending scheduled intents.

Facility state includes its generation, next event ordinal, current pending
tick id, and processed event ids. Host state owns bounded resource inventory and
cohort aggregates. Population and work queues are represented as cohorts; v0
does not schedule one event per inhabitant.

## Outcomes

Successful cycles emit `FacilityProductionTicked`. Atomic blocked cycles emit
`FacilityProductionBlocked` with one of `missing_inputs`, `missing_energy`,
`missing_maintenance`, `insufficient_workforce`, or `output_storage_full`.
Inactive, stale-generation, and duplicate intents emit an explicit ignored
outcome and cannot apply production. A configured blocked retry uses a positive
delay and a newly allocated event id.

Resource consumption in the integration fixture is also atomic. A shortage
does not consume partial stock; configured cohort effects may increase unrest
and reduce available workforce, which subsequent Facility cycles read as local
managed state.

A Facility host may transfer produced goods to a Trade Hub only when that host
is explicitly connected to the concrete hub instance. The authoritative
transfer checks Governance and available host stock before atomically removing
the goods from the host and depositing them into the hub account.

## Canonical implementation

The canonical runtime contract is `packages/world-sim/src/facilities.ts`.
`packages/world-sim/src/simulation-foundation.ts` is the thin WorldSim
dispatcher for Facility ticks and the artificial delivery/consumption fixture.

## Balance boundary

Goods, recipes, cycle durations, capacities, efficiencies, upkeep, workforce,
and development curves are configuration. The engine contract must work with
small artificial fixtures before long-running balance simulations establish
setting-specific values.
