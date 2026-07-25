import assert from "node:assert/strict";
import test from "node:test";

import { Facilities } from "../src/index.js";
import type { FacilityHostSeed, FacilityRecipe, FacilitySeed } from "../src/index.js";

const HOST: FacilityHostSeed = {
  hostId: "worksite",
  inventory: { ore: 2, power: 1, tools: 1 },
  storageCaps: { ore: 10, power: 10, tools: 10, metal: 10 },
  cohorts: [{ cohortId: "workers", population: 10, availableWorkforce: 5, unrest: 0 }],
};

const RECIPE: FacilityRecipe = {
  inputs: { ore: 2 },
  energyInputs: { power: 1 },
  maintenanceInputs: { tools: 1 },
  outputs: { metal: 1 },
  workforceRequired: 5,
  cycleDays: 1,
  blockedRetryDays: 0.5,
};

test("Facility applies a successful cycle atomically and schedules its own next tick", () => {
  const facilities = createFacilities();
  const intent = facilities.initialTickIntent("smelter", 0)!;
  const result = facilities.handleProductionTick(intent, 1);

  assert.equal(result.event.outcome, "completed");
  assert.equal(result.nextIntent?.dueElapsedDays, 2);
  assert.notEqual(result.nextIntent?.eventId, intent.eventId);
  assert.deepEqual(facilities.snapshot().hosts[0]?.inventory, { metal: 1 });
});

test("blocked requirements do not partially mutate inventory and retry uses a new id", () => {
  for (const [mutation, reason] of [
    [(host: FacilityHostSeed) => ({ ...host, inventory: { ...host.inventory, ore: 1 } }), "missing_inputs"],
    [(host: FacilityHostSeed) => ({ ...host, inventory: { ...host.inventory, power: 0 } }), "missing_energy"],
    [(host: FacilityHostSeed) => ({ ...host, inventory: { ...host.inventory, tools: 0 } }), "missing_maintenance"],
    [(host: FacilityHostSeed) => ({ ...host, cohorts: [{ ...host.cohorts[0]!, availableWorkforce: 4 }] }), "insufficient_workforce"],
    [(host: FacilityHostSeed) => ({ ...host, inventory: { ...host.inventory, metal: 10 } }), "output_storage_full"],
  ] as const) {
    const host = mutation(HOST);
    const facilities = createFacilities(host);
    const before = facilities.snapshot().hosts[0];
    const intent = facilities.initialTickIntent("smelter", 0)!;
    const result = facilities.handleProductionTick(intent, 1);
    assert.equal(result.event.outcome, "blocked");
    if (result.event.outcome !== "blocked") assert.fail("Expected blocked Facility.");
    assert.equal(result.event.reason, reason);
    assert.notEqual(result.nextIntent?.eventId, intent.eventId);
    assert.deepEqual(facilities.snapshot().hosts[0], before);
  }
});

test("pause invalidates queued generations and duplicate handling is idempotent", () => {
  const facilities = createFacilities();
  const intent = facilities.initialTickIntent("smelter", 0)!;
  facilities.pause("smelter");
  const stale = facilities.handleProductionTick(intent, 1);
  const duplicate = facilities.handleProductionTick(intent, 1);

  assert.equal(stale.event.outcome, "ignored");
  assert.equal(stale.event.outcome === "ignored" && stale.event.reason, "stale_generation");
  assert.equal(duplicate.event.outcome === "ignored" && duplicate.event.reason, "duplicate");
  assert.deepEqual(facilities.snapshot().hosts[0]?.inventory, HOST.inventory);
});

function createFacilities(host: FacilityHostSeed = HOST): Facilities {
  const seed: FacilitySeed = {
    facilityId: "smelter",
    facilityType: "fixture_smelter",
    hostId: host.hostId,
    ownerId: "works_owner",
    governorActorId: "works_manager",
    recipe: RECIPE,
    active: true,
    generation: 0,
    nextEventOrdinal: 0,
    pendingTickEventId: null,
    processedEventIds: [],
  };
  return new Facilities([seed], [host]);
}
