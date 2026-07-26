# Route Security, Bandits & Escorts v1

Status: active contract.

## Boundary

`RouteSecurity` is composed into the canonical `WorldSimulationFoundation`.
A route record refers to an authored region-graph edge and never creates
topology. Bandits, patrols and escorts are ordinary physical Parties. Movement,
cargo and casualties remain WorldSimulation truth. Commands use
`WorldCommandEnvelope`; encounters use ordinary WorldClock intents ordered only
by due time and stable scheduling sequence.

## State, tasks and labour

Each route stores configured local risk, traffic value, incident counts,
successful ambushes and patrol strength. Security Parties have owner,
Governor/controller identity, role, supplies, condition and morale. Patrol and
escort tasks follow `created -> accepted -> in_progress ->
completed|failed|abandoned`. Invalid transitions, insufficient explicitly
allocated military labour and duplicate active executor/route tasks fail
without mutation. Completed patrols lower local risk. Security influences
trade through physical delay or loss, never a direct price modifier.

## Encounters

`plan_route_encounter` requires Governance scope `security:encounter`, a
positive delay, a registered bandit attacker and every participant physically
travelling on the declared edge. `RouteEncounterDue` resolves from composition,
condition, morale, escorts, patrol strength and a stable hash of configured
seed plus encounter id. It never reads wall time or `Math.random`. Cargo
transfer, casualties and delay are prevalidated and applied atomically by
WorldSimulation; rejection invalidates the encounter without partial effects.
Processed command/event ids make replay exactly-once. Save/load preserves a
pending encounter and identical continuation.

## Knowledge

Route truth is not an AI affordance. WorldSimulation adjudicates direct local
observation only for a Party on the edge or at an endpoint and writes scoped
WorldMemory with provenance and configured aging. Incident reports require a
participating physical Party at an incident-route endpoint and an authorized
handoff to the local authority office. v1 models that office handoff as an
immediate command at the endpoint; courier travel beyond the endpoint is
deferred and there is no remote report API. Rumours use the
existing delayed provenance-bearing memory contract. Route controllers consume
only fresh owner views; unknown or stale risk/traffic means no route choice.
Party Map exposes no security truth. Only the labelled TRUTH/DEBUG diagnostics
may display authoritative risk and security tasks.

## v1 deferrals

Risk, morale, strength, losses and supplies are explicit fixture values, not
balance. Full tactical combat, terrain tactics, prisoners, persistent wounds,
protection payments and strategic AI are deferred. History can grow linearly;
pending events and active tasks are bounded by exactly-once and duplicate
guards.
