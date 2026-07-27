import assert from "node:assert/strict";
import test from "node:test";

import {
  WorldClock,
  WorldClockAdvanceError,
  WorldClockEventBudgetExceededError,
  WorldClockValidationError,
} from "../src/index.js";
import type { ScheduledEventIntent } from "../src/index.js";

test("advances deterministic simulation time in explicit day increments", () => {
  const clock = new WorldClock();
  clock.advanceDays(0.25);
  clock.advanceDays(1);

  assert.deepEqual(clock.snapshot(), {
    elapsedDays: 1.25,
    nextSchedulingSequence: 0,
    scheduledEvents: [],
  });
});

test("rejects invalid clock advances instead of silently ignoring them", () => {
  const clock = new WorldClock();

  assert.throws(() => clock.advanceDays(0), WorldClockAdvanceError);
  assert.throws(() => clock.advanceDays(Number.NaN), WorldClockAdvanceError);
  assert.equal(clock.snapshot().elapsedDays, 0);
});

test("integer drift canonicalization never moves an already-ahead clock backwards", () => {
  const clock = new WorldClock(1 + 5e-10);
  const before = clock.elapsedDays;
  clock.advanceDays(1e-10);
  assert.equal(clock.elapsedDays > before, true);
});

test("dispatches by due time and stable scheduling sequence without kind priorities", () => {
  const clock = new WorldClock();
  const observed: string[] = [];
  clock.schedule(intent("consume", "ConsumeDue", 1));
  clock.schedule(intent("arrival", "ArrivalDue", 1));
  clock.schedule(intent("earlier", "AnythingDue", 0.5));

  clock.advanceDays(1, {
    maxEvents: 10,
    dispatch: (due) => { observed.push(due.eventId); },
  });

  assert.deepEqual(observed, ["earlier", "consume", "arrival"]);
});

test("processes newly scheduled same-advance work and bounds same-time loops", () => {
  const clock = new WorldClock();
  clock.schedule(intent("loop-0", "Loop", 1));

  assert.throws(() => clock.advanceDays(2, {
    maxEvents: 3,
    dispatch: (due) => [intent(`${due.eventId}-next`, "Loop", due.dueElapsedDays)],
  }), WorldClockEventBudgetExceededError);
  assert.equal(clock.elapsedDays, 1);
  assert.equal(clock.snapshot().scheduledEvents.filter((item) => item.status === "completed").length, 3);
  assert.equal(clock.snapshot().scheduledEvents.filter((item) => item.status === "pending").length, 1);
});

test("persists queue lifecycle, cancellation, and event-id idempotency across save/load", () => {
  const clock = new WorldClock();
  clock.schedule(intent("cancelled", "Work", 1));
  clock.schedule(intent("pending", "Work", 2));
  assert.equal(clock.cancel("cancelled"), true);
  assert.equal(clock.cancel("cancelled"), false);
  assert.throws(() => clock.schedule(intent("pending", "Work", 3)), WorldClockValidationError);

  const restored = WorldClock.fromSnapshot(JSON.parse(JSON.stringify(clock.snapshot())) as ReturnType<WorldClock["snapshot"]>);
  const observed: string[] = [];
  restored.advanceDays(2, { maxEvents: 2, dispatch: (due) => { observed.push(due.eventId); } });

  assert.deepEqual(observed, ["pending"]);
  assert.equal(restored.snapshot().scheduledEvents[0]?.status, "cancelled");
  assert.equal(restored.snapshot().scheduledEvents[1]?.status, "completed");
});

test("records an explicit failed lifecycle state when dispatch rejects an intent", () => {
  const clock = new WorldClock();
  clock.schedule(intent("bad", "Unknown", 1));
  assert.throws(() => clock.advanceDays(1, {
    maxEvents: 1,
    dispatch: () => { throw new Error("no handler"); },
  }), /no handler/);
  assert.deepEqual(clock.snapshot().scheduledEvents[0]?.status, "failed");
  assert.deepEqual(clock.snapshot().scheduledEvents[0]?.failureMessage, "no handler");
});

test("rejects values that structured clone can copy but JSON saves cannot serialize", () => {
  const clock = new WorldClock();
  assert.throws(() => clock.schedule({
    ...intent("date", "Work", 1),
    payload: new Date() as never,
  }), /plain serializable object/);
  const cyclic: { self?: unknown } = {};
  cyclic.self = cyclic;
  assert.throws(() => clock.schedule({
    ...intent("cyclic", "Work", 1),
    payload: cyclic as never,
  }), /must not be cyclic/);
});

test("batch scheduling is atomic when any event id conflicts", () => {
  const clock = new WorldClock();
  clock.schedule(intent("known", "Work", 1));
  const before = clock.snapshot();
  assert.throws(() => clock.scheduleAll([
    intent("new", "Work", 1),
    intent("known", "Work", 1),
  ]), WorldClockValidationError);
  assert.deepEqual(clock.snapshot(), before);
});

function intent(eventId: string, kind: string, dueElapsedDays: number): ScheduledEventIntent {
  return {
    eventId,
    kind,
    dueElapsedDays,
    targetComponent: "test",
    targetEntityId: "fixture",
    payload: {},
  };
}
