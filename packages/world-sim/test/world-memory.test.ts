import assert from "node:assert/strict";
import test from "node:test";

import { WorldMemory, WorldMemoryValidationError } from "../src/index.js";
import type { WorldMemoryIngest } from "../src/index.js";

test("WorldMemory assigns deterministic ids, preserves provenance, and scopes owner views", () => {
  const memory = new WorldMemory();
  const first = memory.ingest(observation("obs-a", "merchant-a", 1, 1));
  const second = memory.ingest(observation("obs-b", "merchant-b", 1, 1));
  memory.ingest({ ...observation("actor-same-id", "merchant-a", 1, 1), ownerKind: "actor" });
  assert.equal(first.accepted && first.entry.entryId, "memory:0");
  assert.equal(second.accepted && second.entry.entryId, "memory:1");

  const ownerA = memory.ownerView("merchant-a", "party", 2);
  assert.equal(ownerA.entries.length, 1);
  assert.equal(ownerA.entries[0]?.provenance.sourceId, "local-look-a");
  assert.equal(memory.ownerView("merchant-b", "party", 2).entries.length, 1);
  assert.equal(memory.ownerView("unknown", "party", 2).entries.length, 0);
});

test("WorldMemory exposes explicit aging without deleting or rewriting observations", () => {
  const memory = new WorldMemory();
  memory.ingest(observation("aging", "merchant", 2, 2, 3));
  assert.equal(memory.ownerView("merchant", "party", 4.9).entries[0]?.freshness, "fresh");
  const stale = memory.ownerView("merchant", "party", 5);
  assert.equal(stale.entries[0]?.freshness, "stale");
  assert.equal(stale.entries[0]?.ageDays, 3);
  assert.equal(stale.entries[0]?.observedAtElapsedDays, 2);
});

test("WorldMemory hides an observation until its explicit known-at time", () => {
  const memory = new WorldMemory();
  memory.ingest(observation("delayed-report", "merchant", 1, 3));
  assert.equal(memory.ownerView("merchant", "party", 2).entries.length, 0);
  assert.equal(memory.ownerView("merchant", "party", 3).entries.length, 1);
});

test("WorldMemory ingest is idempotent and conflicting reuse cannot mutate state", () => {
  const memory = new WorldMemory();
  const input = observation("same", "merchant", 0, 0);
  const first = memory.ingest(input);
  const replay = memory.ingest(structuredClone(input));
  const beforeConflict = memory.snapshot();
  const conflict = memory.ingest({ ...input, kind: "different" });

  assert.equal(first.accepted, true);
  assert.equal(replay.accepted && replay.idempotentReplay, true);
  assert.equal(conflict.accepted, false);
  if (conflict.accepted) assert.fail("Expected ingest conflict.");
  assert.equal(conflict.errorCode, "INGEST_ID_CONFLICT");
  assert.deepEqual(memory.snapshot(), beforeConflict);
});

test("WorldMemory JSON save/load gives identical deterministic continuation", () => {
  const original = new WorldMemory();
  original.ingest(observation("first", "merchant", 0, 0));
  const restored = new WorldMemory(JSON.parse(JSON.stringify(original.snapshot())));
  const next = observation("second", "merchant", 1, 1);
  original.ingest(next);
  restored.ingest(next);
  assert.deepEqual(restored.snapshot(), original.snapshot());
  assert.deepEqual(restored.ownerView("merchant", "party", 7), original.ownerView("merchant", "party", 7));
});

test("WorldMemory batch ingest rejects a conflict without partially appending entries", () => {
  const memory = new WorldMemory();
  memory.ingest(observation("existing", "merchant", 0, 0));
  const before = memory.snapshot();
  const result = memory.ingestAll([
    observation("new", "merchant", 1, 1),
    { ...observation("existing", "merchant", 0, 0), kind: "conflicting-kind" },
  ]);
  assert.equal(result.accepted, false);
  assert.deepEqual(memory.snapshot(), before);
});

test("WorldMemory rejects knowledge timestamps that precede observation", () => {
  assert.throws(
    () => new WorldMemory().ingest(observation("bad-time", "merchant", 2, 1)),
    WorldMemoryValidationError,
  );
});

function observation(
  ingestId: string,
  ownerId: string,
  observedAtElapsedDays: number,
  knownAtElapsedDays: number,
  staleAfterDays = 5,
): WorldMemoryIngest {
  return {
    ingestId,
    ownerId,
    ownerKind: "party",
    kind: "trade_hub_observation",
    observedAtElapsedDays,
    knownAtElapsedDays,
    staleAfterDays,
    provenance: {
      sourceType: "direct_observation",
      sourceId: `local-look-${ingestId.at(-1)}`,
      sourceOwnerId: ownerId,
      nodeId: "wroclaw",
    },
    payload: { hubId: "hub-a", market: [] },
  };
}
