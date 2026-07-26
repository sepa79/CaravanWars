import assert from "node:assert/strict";
import test from "node:test";

import { Facilities, FacilityProfileRuntime, PREINDUSTRIAL_FACILITY_PROFILES_V1, WorldClock, WorldSimulationFoundation, Governance, calendarAt } from "../src/index.js";

function foundation(seedGrain = 20, hay = 60) {
  const clock = new WorldClock();
  const facilities = new Facilities([{ facilityId: "farm", facilityType: "profiled", hostId: "farm_host", ownerId: "owner", governorActorId: null, recipe: { inputs: {}, energyInputs: {}, maintenanceInputs: {}, outputs: {}, workforceRequired: 0, cycleDays: 1, blockedRetryDays: null, shortagePolicies: [] }, active: false, generation: 0, nextEventOrdinal: 0, pendingTickEventId: null, processedEventIds: [] }], [{ hostId: "farm_host", inventory: { seed_grain: seedGrain, hay }, storageCaps: { seed_grain: 500, gross_grain: 500, edible_grain: 500, straw: 500, hay: 500 }, cohorts: [] }], { definitions: PREINDUSTRIAL_FACILITY_PROFILES_V1, instances: [{ facilityId: "farm", hostId: "farm_host", profileId: "cereal_rye_farm_v1", visualSkinId: "any_skin", processStages: {}, nextEventOrdinal: 0, processedEventIds: [], animalCohorts: [], winterFeedRequired: 0 }] });
  const result = new WorldSimulationFoundation({ clock, facilities, governance: new Governance({ managedEntities: [], governors: [], delegations: [] }), maxEventsPerAdvance: 1000 });
  result.scheduleInitialFacilityProfileProcesses();
  return result;
}

test("calendar is deterministic and profileId behavior ignores visualSkinId", () => {
  assert.deepEqual(calendarAt(0), { elapsedDay: 0, year: 1, dayOfYear: 0, season: "winter" });
  assert.equal(calendarAt(90).season, "spring");
  assert.equal(calendarAt(360).year, 2);
  const first = foundation(); first.advanceDays(360);
  const snapshot = first.snapshot();
  assert.equal(snapshot.facilities.profileRuntime?.instances[0]?.visualSkinId, "any_skin");
  assert.equal(snapshot.events.some((event) => event.eventType === "FacilityProfileProcessCompleted"), true);
});

test("profile initialization cannot duplicate an active process chain", () => {
  const runtime = foundation();
  assert.deepEqual(runtime.scheduleInitialFacilityProfileProcesses(), []);
  runtime.advanceDays(720);
  assert.equal(runtime.snapshot().clock.scheduledEvents.filter((record) => record.status === "pending").length, 1);
});

test("bad harvest/no seed blocks sowing without negative inventory and save mid-cycle replays", () => {
  const blocked = foundation(0); blocked.advanceDays(120);
  assert.equal(blocked.snapshot().events.some((event) => event.eventType === "FacilityProfileProcessBlocked" && event.reason === "missing_inputs"), true);
  assert.equal(blocked.snapshot().facilities.hosts[0]?.inventory.seed_grain ?? 0, 0);

  const original = foundation(); original.advanceDays(150);
  const resumed = WorldSimulationFoundation.fromSnapshot(JSON.parse(JSON.stringify(original.snapshot())));
  original.advanceDays(500); resumed.advanceDays(500);
  assert.deepEqual(resumed.snapshot(), original.snapshot());
});

test("winter husbandry is feed-limited and recovers only after physical hay delivery", () => {
  const clock = new WorldClock();
  const facilities = new Facilities([{ facilityId: "cattle", facilityType: "profiled", hostId: "cattle_host", ownerId: "owner", governorActorId: null, recipe: { inputs: {}, energyInputs: {}, maintenanceInputs: {}, outputs: {}, workforceRequired: 0, cycleDays: 1, blockedRetryDays: null, shortagePolicies: [] }, active: false, generation: 0, nextEventOrdinal: 0, pendingTickEventId: null, processedEventIds: [] }], [{ hostId: "cattle_host", inventory: {}, storageCaps: { hay: 100, manure: 100, milk: 100, traction: 100 }, cohorts: [] }], { definitions: PREINDUSTRIAL_FACILITY_PROFILES_V1, instances: [{ facilityId: "cattle", hostId: "cattle_host", profileId: "cattle_husbandry_v1", visualSkinId: "cattle_skin", processStages: {}, nextEventOrdinal: 0, processedEventIds: [], winterFeedRequired: 20, animalCohorts: [{ cohortId: "cows", speciesId: "cattle", lifeStage: "adult", count: 2, ageDays: 800, breedingSharePermille: 400, milkToYoungSharePermille: 400, tractionSharePermille: 200 }] }] });
  const runtime = new WorldSimulationFoundation({ clock, facilities, governance: new Governance({ managedEntities: [], governors: [], delegations: [] }), maxEventsPerAdvance: 1000 });
  runtime.scheduleInitialFacilityProfileProcesses();
  runtime.advanceDays(90);
  assert.equal(runtime.snapshot().events.at(-1)?.eventType, "FacilityProfileProcessBlocked");
  assert.equal(runtime.depositToFacilityHost("cattle_host", "hay", 30), true);
  runtime.advanceDays(360);
  assert.equal(runtime.snapshot().events.some((event) => event.eventType === "FacilityProfileProcessCompleted" && event.facilityId === "cattle"), true);
  assert.equal(runtime.facilityHostResource("cattle_host", "hay"), 10);
});

test("historical fixture ranges and animal winter feed are explicit configuration", () => {
  const rye = PREINDUSTRIAL_FACILITY_PROFILES_V1.find((profile) => profile.profileId === "cereal_rye_farm_v1")!;
  assert.deepEqual([rye.evidence.yieldToSeed?.minimum, rye.evidence.yieldToSeed?.maximum], [2, 4]);
  assert.deepEqual([rye.evidence.harvestProcessingLossPermille?.minimum, rye.evidence.harvestProcessingLossPermille?.maximum], [60, 180]);
  const cattle = PREINDUSTRIAL_FACILITY_PROFILES_V1.find((profile) => profile.profileId === "cattle_husbandry_v1")!;
  assert.equal(cattle.evidence.milkPerCowSeason?.confidence, "low");
  assert.equal(PREINDUSTRIAL_FACILITY_PROFILES_V1.some((profile) => profile.profileId === "granary_spoilage_v1"), true);
  assert.throws(() => new FacilityProfileRuntime({ definitions: [cattle], instances: [{ facilityId: "invalid", hostId: "host", profileId: cattle.profileId, visualSkinId: "skin", processStages: {}, nextEventOrdinal: 0, processedEventIds: [], winterFeedRequired: 1, animalCohorts: [{ cohortId: "overallocated", speciesId: "cattle", lifeStage: "adult", count: 1, ageDays: 1, breedingSharePermille: 600, milkToYoungSharePermille: 300, tractionSharePermille: 200 }] }] }), /cannot exceed/);
});
