# Generic Governance v0

## Purpose

Governance v0 defines reusable ownership, direct management, superior chains,
and command authority for CaravanWars and future simulations such as
MarsKolony. It does not encode setting-specific ranks.

## Core relationships

Managed entities may expose:

```json
{
  "owner_id": "wroclaw_city",
  "governor_actor_id": "wroclaw_quartermaster"
}
```

Governors may expose:

```json
{
  "actor_id": "wroclaw_quartermaster",
  "principal_id": "wroclaw_city",
  "superior_actor_id": "wroclaw_mayor",
  "roles": ["logistics"],
  "authority_scopes": ["facility:granary", "party:supply"]
}
```

`owner_id` and `governor_actor_id` may match but have different semantics.
Owners may be non-actor principals and do not need a superior. A governor's
superior is optional, so the authority graph may have explicit roots.

## Required invariants

- Every operational command identifies the actor or controller issuing it.
- WorldSim validates authority at the normal command boundary.
- Direct governors may inspect only the current physical state of entities
  they manage for operational decisions.
- Strategic knowledge comes from the governor's WorldMemory context, not a
  scan of authoritative global state.
- Superior relationships do not imply shared memory or instant communication.
- Authority exceptions, delegation, and substitution are explicit and
  time-bounded where applicable.
- A Facility may run previously configured automatic cycles without an active
  governor, but new policy decisions require an authorized governor.
- Authority graphs must reject cycles unless a future collective-governance
  contract explicitly defines their meaning.

## Reuse

Mayor, quartermaster, caravan leader, guild master, colony governor, chief
engineer, department AI, and player are roles or controller implementations
over this contract. They are not separate simulation authority systems.

## Authority evaluation

Authority is evaluated for an issuer actor, managed entity, required scope, and
authoritative elapsed time. Evaluation checks the direct governor, its explicit
superior chain, and active explicit delegations. A delegation cannot grant a
scope its delegator does not possess. Validity uses a half-open interval:
`valid_from <= now < valid_until`; a null end is unbounded.

Roles remain descriptive configuration and grant no scope by themselves.
Controller type (`human`, `deterministic_policy`, or `ai`) also grants no
authority. The result proves permission only; it neither delivers a message nor
supplies observations or memory.

The canonical runtime contract is `packages/world-sim/src/governance.ts`.
Facility pause/resume proves its use at the normal authoritative command
boundary in `WorldSimulation.submitCommand`.

Trade Hub v0 uses the same evaluator with `trade:transfer`, `trade:order`, and
`trade:cancel` scopes. These scopes authorize a submitted command only; they do
not grant remote delivery, shared memory, or knowledge of another hub's state.

## Out of scope for v0

- elections, inheritance, and political legitimacy,
- detailed employment contracts,
- collective voting and quorum rules,
- setting-specific titles,
- remote communication transports.
