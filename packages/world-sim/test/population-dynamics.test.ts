import assert from "node:assert/strict";
import { resolve } from "node:path";
import test from "node:test";

import { Facilities, Governance, PopulationDynamics, WorldClock, WorldSimulationFoundation, createSeasonalRegionalEconomyFixture, loadPartyTravelConfigFile, loadRegionGraphFile } from "../src/index.js";
import type { PopulationPolicy, PopulationSeasonEvent } from "../src/index.js";

const BASE_POLICY: PopulationPolicy = {
  foodGoodsId: "food", foodUnitsPerPersonPerSeasonPermille: 100, rationingPermille: 1000, reserveTargetUnits: 0,
  nutritionLossOnShortagePermille: 200, nutritionRecoveryPermille: 100, healthLossFromMalnutritionPermille: 100, healthRecoveryPermille: 50,
  unrestDeltaOnFoodShortage: 0, baselineBirthsPerAdultYearPermille: 100, baselineDeathsPerYearPermille: 20, malnutritionDeathsPerYearPermille: 100,
  maturationPerYearPermille: 100, agingPerYearPermille: 50, seasonalDiseaseRiskPermille: { winter: 1000, spring: 0, summer: 0, autumn: 0 },
  diseaseHealthLossPermille: 100, diseaseDurationSeasons: 1, seasonalLabourAvailabilityPermille: { winter: 500, spring: 900, summer: 1000, autumn: 900 },
  labourPriority: ["agriculture", "care", "transport", "industry", "military"],
};

function createFoundation(food: number, policy = BASE_POLICY) {
  const clock = new WorldClock();
  const facilities = new Facilities([], [{ hostId: "a_host", inventory: { food }, storageCaps: { food: 1000 }, cohorts: [{ cohortId: "residents", population: 100, availableWorkforce: 50, unrest: 0 }] }, { hostId: "b_host", inventory: { food: 100 }, storageCaps: { food: 1000 }, cohorts: [{ cohortId: "residents", population: 40, availableWorkforce: 20, unrest: 0 }] }]);
  const population = new PopulationDynamics({ settlements: [settlement("a", "a_host", policy, { children: 30, workingAdults: 60, elders: 10 }), settlement("b", "b_host", { ...policy, seasonalDiseaseRiskPermille: { winter: 0, spring: 0, summer: 0, autumn: 0 } }, { children: 10, workingAdults: 25, elders: 5 })], migrations: [] });
  const governance = new Governance({ managedEntities: [{ entityId: "a", ownerId: "a", governorActorId: "a_governor" }, { entityId: "b", ownerId: "b", governorActorId: "b_governor" }], governors: [{ actorId: "a_governor", principalId: "a", superiorActorId: null, roles: ["governor"], authorityScopes: ["population:allocate", "population:migrate"], controller: "deterministic_policy" }, { actorId: "b_governor", principalId: "b", superiorActorId: null, roles: ["governor"], authorityScopes: ["population:allocate", "population:migrate"], controller: "deterministic_policy" }], delegations: [] });
  const foundation = new WorldSimulationFoundation({ clock, facilities, governance, population, maxEventsPerAdvance: 1000 });
  foundation.scheduleInitialPopulationProcesses();
  return foundation;
}

test("food shortage degrades nutrition/health and causes configured mortality without automatic unrest", () => {
  const foundation = createFoundation(0);
  foundation.advanceDays(360);
  const settlement = foundation.populationSnapshot()!.settlements.find((item) => item.settlementId === "a")!;
  const events = foundation.snapshot().events.filter((event): event is PopulationSeasonEvent => event.eventType === "PopulationSeasonAdvanced" && event.settlementId === "a");
  assert.equal(settlement.unrest, 0);
  assert.equal(settlement.nutritionPermille < 900, true);
  assert.equal(settlement.healthPermille < 900, true);
  assert.equal(events.some((event) => event.diseaseState === "active"), true);
  assert.equal(events.some((event) => event.diseaseState === "recovering" || event.diseaseState === "none"), true);
  assert.equal(events.reduce((sum, event) => sum + event.deaths, 0) > 0, true);
});

test("labour allocations are authority checked, idempotent, bounded and priority-trimmed after illness", () => {
  const foundation = createFoundation(100);
  const command = { commandId: "allocate-1", issuerActorId: "a_governor", settlementId: "a", allocations: [{ allocationId: "harvest", targetEntityId: "farm", sector: "agriculture" as const, workers: 20 }, { allocationId: "industry", targetEntityId: "mill", sector: "industry" as const, workers: 4 }] };
  assert.equal(foundation.executeAllocateLabour(command).accepted, true);
  assert.equal(foundation.executeAllocateLabour(command).idempotentReplay, true);
  assert.equal(foundation.executeAllocateLabour({ ...command, commandId: "foreign", issuerActorId: "b_governor" }).accepted, false);
  assert.equal(foundation.executeAllocateLabour({ ...command, commandId: "too-many", allocations: [{ allocationId: "all", targetEntityId: "farm", sector: "agriculture", workers: 999 }] }).accepted, false);
  const partyConflict = foundation.executeAllocateLabour({ ...command, commandId: "party-conflict" }, 5);
  assert.equal(partyConflict.accepted, false);
  assert.equal(!partyConflict.accepted && partyConflict.errorCode, "INSUFFICIENT_LABOUR");
  foundation.advanceDays(90);
  assert.equal(foundation.populationSnapshot()!.settlements.find((item) => item.settlementId === "a")!.allocations.reduce((sum, item) => sum + item.workers, 0) <= 24, true);
});

test("migration is a physical delayed process, conserves people, and save mid-travel replays", () => {
  const foundation = createFoundation(100);
  const before = foundation.populationSnapshot()!.settlements.reduce((sum, item) => sum + item.cohorts.children + item.cohorts.workingAdults + item.cohorts.elders, 0);
  const result = foundation.executeStartMigration({ commandId: "migration-command", issuerActorId: "a_governor", migrationId: "migration-1", originSettlementId: "a", destinationSettlementId: "b", routeId: "a_b", people: 5, travelDays: 20 });
  assert.equal(result.accepted, true);
  assert.equal(foundation.populationSnapshot()!.migrations[0]?.status, "traveling");
  const saved = JSON.parse(JSON.stringify(foundation.snapshot()));
  const resumed = WorldSimulationFoundation.fromSnapshot(saved);
  foundation.advanceDays(20); resumed.advanceDays(20);
  assert.deepEqual(resumed.snapshot(), foundation.snapshot());
  const after = foundation.populationSnapshot()!.settlements.reduce((sum, item) => sum + item.cohorts.children + item.cohorts.workingAdults + item.cohorts.elders, 0);
  assert.equal(after, before);
  assert.equal(foundation.populationSnapshot()!.migrations[0]?.status, "arrived");
});

test("migration scheduling failure rolls back and replays the same failure", () => {
  const foundation = createFoundation(100);
  foundation.schedule({ eventId: "migration:conflict:arrival", kind: "fixture", dueElapsedDays: 20, targetComponent: "fixture", targetEntityId: "fixture", payload: {} });
  const command = { commandId: "conflict-command", issuerActorId: "a_governor", migrationId: "conflict", originSettlementId: "a", destinationSettlementId: "b", routeId: "a_b", people: 5, travelDays: 20 };
  const before = foundation.populationSnapshot();
  const result = foundation.executeStartMigration(command);
  assert.equal(result.accepted, false);
  assert.equal(!result.accepted && result.errorCode, "SCHEDULING_FAILED");
  assert.deepEqual(foundation.populationSnapshot()!.settlements, before!.settlements.map((item) => item.settlementId === "a" ? { ...item, processedCommandIds: foundation.populationSnapshot()!.settlements.find((current) => current.settlementId === "a")!.processedCommandIds } : item));
  const replay = foundation.executeStartMigration(command);
  assert.equal(replay.idempotentReplay, true);
  assert.equal(!replay.accepted && replay.errorCode, "SCHEDULING_FAILED");
});

test("seasonal regional Governor allocates labour from private observations and scarce harvest labour affects output", () => {
  const graph = loadRegionGraphFile(resolve("data/regions/silesia.json"));
  const travel = loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json"));
  const fixture = createSeasonalRegionalEconomyFixture(graph, travel, 17);
  fixture.runner.runDays(360);
  const snapshot = fixture.runner.snapshot().runner.world;
  assert.equal(snapshot.worldMemory.entries.some((entry) => entry.kind === "population_observation" && entry.ownerId === "wroclaw_governor"), true);
  assert.equal(snapshot.simulationFoundation?.population?.settlements.every((item) => item.allocations.length > 0), true);
  assert.equal(snapshot.simulationFoundation?.events.some((event) => event.eventType === "FacilityProfileProcessBlocked" && event.reason === "insufficient_workforce"), true);
  assert.equal("population" in fixture.runner.partyMapSnapshot("seasonal_merchant_0"), false);
  const invalidRoute = fixture.world.submitCommand({ commandType: "start_population_migration", command: { commandId: "bad-route", issuerActorId: "wroclaw_governor", migrationId: "bad-route", originSettlementId: "wroclaw", destinationSettlementId: "opole", routeId: "prague_olomouc", people: 1, travelDays: 5 } }).result;
  assert.equal(invalidRoute.accepted, false);
});

function settlement(settlementId: string, hostId: string, policy: PopulationPolicy, cohorts: { children: number; workingAdults: number; elders: number }) {
  return { settlementId, nodeId: settlementId, hostId, ownerId: settlementId, governorActorId: `${settlementId}_governor`, cohorts, healthPermille: 900, nutritionPermille: 900, unrest: 0, diseaseState: "none" as const, diseaseSeasonsRemaining: 0, allocations: [], policy, nextEventOrdinal: 0, pendingSeasonEventId: null, processedEventIds: [], processedCommandIds: [] };
}
