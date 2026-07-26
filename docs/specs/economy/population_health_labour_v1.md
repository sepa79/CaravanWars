# Population, Health & Labour Dynamics v1

## Boundary

`PopulationDynamics` is composed by the canonical `WorldSimulationFoundation`.
It owns local settlement cohorts, health, nutrition, disease, labour allocation
and in-transit migration. Food remains physical stock in a Facility host.
Seasonal mutation uses ordinary WorldClock intents; Governor changes use
`allocate_labour` and `start_population_migration` commands with Governance.

## Cohorts and health

V1 uses configurable aggregate children, working-adult and elder cohorts. A
seasonal process applies explicit birth, maturation, aging and mortality
permille. It consumes a configured ration while protecting a reserve. Shortage
first changes nutrition, then health and labour. Starvation mortality and
unrest are independent values; fixture hunger configures no automatic unrest.

Disease risk is seasonal. A stable hash of settlement, year and season replaces
randomness. Disease has explicit duration and health cost followed by recovery.
Fixture values are test ranges, not final demographic or medical balance.

## Labour

Available labour derives from working-age population, health, nutrition and
seasonal availability. Allocations identify a target and agriculture,
industry, transport, military or care. Their sum cannot exceed the local pool;
pool reduction trims allocations in configured priority order. Facility stages
read only labour allocated to that exact Facility. Rye sowing and harvest have
narrow elevated requirements and block explicitly when allocation is short.

`GovernorPopulationController` sees only owner-scoped WorldMemory and configured
seasonal targets. WorldSimulation first adjudicates `population_observation`.
Authority does not grant knowledge.

## Migration

Migration removes working adults into a `traveling` record and schedules a
positive-delay arrival. Only arrival adds them at the destination. Commands
declare route and duration, are authority checked and idempotent, and roll back
departure if scheduling fails. The pure migration controller requires fresh
private origin/destination observations and acceptable remembered route risk.

This aggregate travel process is v1's minimum physical contract. Individual
households and refugee cargo are deferred. Route Security may adjudicate the
in-transit record without turning it into teleportation.

## Save and bounds

Snapshots retain cohorts, policies, health, allocations, processed commands,
processed events, pending ordinals and migrations. One seasonal successor per
settlement and one arrival per migration bound pending work. Terminal history
grows linearly under the documented WorldClock policy.
