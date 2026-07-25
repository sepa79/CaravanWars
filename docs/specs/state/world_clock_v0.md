# World Clock v0

## Purpose

`World Clock v0` owns deterministic simulation time and the lifecycle of
serializable scheduled intents. It is reusable and does not own gameplay
decisions.

## Owner / consumers

- Owner: `packages/world-sim`.
- Consumers: authoritative simulation ticks, tests, local server hosts, and
  save/snapshot codecs.
- Non-consumers: presentation code mutating elapsed time directly.

## State

```json
{
  "elapsedDays": 1.25,
  "nextSchedulingSequence": 4,
  "scheduledEvents": [
    {
      "intent": {
        "eventId": "farm:g0:tick:1",
        "kind": "FacilityProductionTickDue",
        "dueElapsedDays": 1.5,
        "targetComponent": "facilities",
        "targetEntityId": "farm",
        "payload": { "generation": 0 }
      },
      "schedulingSequence": 3,
      "status": "pending",
      "failureMessage": null
    }
  ]
}
```

`elapsedDays` is finite and non-negative. The initial clock starts at zero
unless an explicit initial value or validated snapshot is supplied.

## Advance contract

The clock advances only through an explicit finite positive day increment.
Zero, negative, infinite, and `NaN` increments fail without changing time. The
core clock never reads wall time, timezone, or frame delta.

Each advance that dispatches scheduled work supplies an explicit positive
`maxEvents` budget. Exhausting it fails visibly at the due time and leaves the
next intent pending, preventing an unbounded same-time loop.

## Scheduled intents

A scheduled intent contains:

- a globally stable event id,
- a typed event kind,
- an absolute due simulation time,
- a target component and entity id,
- a serializable payload,
- an internal immutable scheduling sequence.

The clock owns ordering, cancellation, lifecycle, and determining what is due.
It stores data, never callbacks, and does not interpret domain kinds. WorldSim
dispatches each due intent to its owning component.

Ordering is ascending `dueElapsedDays`, then ascending scheduling sequence. No
priority or phase is inferred from event kind. Newly scheduled work due within
the current advance participates in that same order. Therefore a `ConsumeDue`
scheduled before an equal-time `ArrivalDue` observes pre-arrival state.

Recurring components return a new intent. A retry has a new event id and an
explicit positive delay; it never mutates or re-runs the original record.

Components that require several intents to commit one domain command use the
clock's atomic batch scheduling operation. The full batch is validated for ids,
times, and sequence capacity before any record is inserted, preventing partial
queue mutation.

## Lifecycle, cancellation, and idempotency

Records have `pending`, `cancelled`, `completed`, or `failed` status. Dispatch
failure is explicit and stores a failure message; there is no implicit retry.
Only pending work can be cancelled. Domain invalidation, such as a stale
Facility generation, remains the owning component's responsibility.

An event id may be scheduled only once, including after completion,
cancellation, failure, or save/load. Snapshots retain all lifecycle records and
the next scheduling sequence, providing deterministic continuation and an
idempotency boundary.

## Compatibility notes

Calendar names, seasons, hours, and wall-clock save timestamps are outside v0.
They must build on elapsed simulation time rather than introduce a second
clock.

V0 deliberately retains terminal event records to preserve event-id
idempotency. Compaction/checkpoint policy and a more efficient queue index are
deferred until workload measurements justify them; hosts must treat snapshot
growth as an observable capacity concern rather than silently dropping records.

## Canonical implementation

`packages/world-sim/src/world-clock.ts` owns the runtime types, validation,
queue, and `WorldClock.fromSnapshot` save/load boundary.
