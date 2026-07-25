import assert from "node:assert/strict";
import test from "node:test";
import { resolve } from "node:path";

import {
  Facilities,
  Governance,
  WorldClock,
  WorldSimulation,
  WorldSimulationFoundation,
  loadPartyTravelConfigFile,
  loadRegionGraphFile,
  resourceConsumptionIntent,
  resourceDeliveryIntent,
} from "../src/index.js";

test("production, shortage, delivery, retry, and workforce feedback preserve causal order", () => {
  const simulation = createScenario();
  simulation.advanceDays(0.5);

  const atHalfDay = simulation.snapshot();
  assert.deepEqual(atHalfDay.events.map((event) => [event.eventType, event.outcome]), [
    ["FacilityProductionTicked", "completed"],
    ["ResourceConsumptionAttempted", "shortage"],
    ["ResourceDeliveryAttempted", "delivered"],
    ["FacilityProductionBlocked", "blocked"],
  ]);
  const shortage = atHalfDay.events[1];
  assert.equal(shortage?.eventType === "ResourceConsumptionAttempted" && shortage.availableBefore, 2);
  assert.deepEqual(atHalfDay.facilities.hosts[0]?.inventory, { food: 5 });
  assert.deepEqual(atHalfDay.facilities.hosts[0]?.cohorts[0], {
    cohortId: "residents",
    population: 20,
    availableWorkforce: 7,
    unrest: 2,
  });
  const productionBlocked = atHalfDay.events[3];
  assert.equal(
    productionBlocked?.eventType === "FacilityProductionBlocked" && productionBlocked.reason,
    "insufficient_workforce",
  );

  simulation.advanceDays(0.25);
  const afterRetry = simulation.snapshot();
  const retry = afterRetry.events.at(-1);
  assert.equal(retry?.eventType, "ResourceConsumptionAttempted");
  assert.equal(retry?.eventType === "ResourceConsumptionAttempted" && retry.outcome, "consumed");
  assert.deepEqual(afterRetry.facilities.hosts[0]?.inventory, {});
  const attempts = afterRetry.events.filter((event) =>
    event.eventType === "ResourceConsumptionAttempted");
  assert.notEqual(attempts[0]?.scheduledEventId, attempts[1]?.scheduledEventId);
});

test("save/load retains pending intents, Facility state, cohorts, and deterministic continuation", () => {
  const uninterrupted = createScenario();
  uninterrupted.advanceDays(0.5);
  const restored = WorldSimulationFoundation.fromSnapshot(
    JSON.parse(JSON.stringify(uninterrupted.snapshot())) as ReturnType<WorldSimulationFoundation["snapshot"]>,
  );

  uninterrupted.advanceDays(0.25);
  restored.advanceDays(0.25);
  assert.deepEqual(restored.snapshot(), uninterrupted.snapshot());
});

test("canonical WorldSimulation owns the shared clock and dispatches scheduled domain work", () => {
  const clock = new WorldClock();
  const foundation = createScenario(clock);
  const world = new WorldSimulation(
    loadRegionGraphFile(resolve("data/regions/silesia.json")),
    loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json")),
    [],
    null,
    clock,
    foundation,
  );

  const unauthorized = world.submitCommand({
    commandType: "set_facility_operation",
    command: { issuerActorId: "outsider", facilityId: "farm", operation: "pause" },
  }).result;
  assert.equal(unauthorized.accepted, false);
  if (unauthorized.accepted) assert.fail("Expected rejected Facility operation.");
  assert.equal(unauthorized.errorCode, "NOT_AUTHORIZED");

  world.advanceDays(0.75);
  const snapshot = world.snapshot();
  assert.equal(snapshot.clock.elapsedDays, 0.75);
  assert.equal(snapshot.simulationFoundation?.events.at(-1)?.eventType, "ResourceConsumptionAttempted");
  assert.deepEqual(world.submitCommand({
    commandType: "set_facility_operation",
    command: { issuerActorId: "operations_manager", facilityId: "farm", operation: "pause" },
  }).result, { accepted: true, scheduledEventId: null });
  assert.equal(world.snapshot().simulationFoundation?.facilities.facilities[0]?.active, false);
  assert.throws(() => foundation.schedule(resourceDeliveryIntent("late-setup", 1, {
    hostId: "settlement_warehouse",
    resourceId: "food",
    amount: 1,
  })), /cannot be added after WorldSimulation starts/);

  world.reset();
  const reset = world.snapshot();
  assert.equal(reset.clock.elapsedDays, 0);
  assert.deepEqual(reset.simulationFoundation?.events, []);
  assert.equal(
    reset.clock.scheduledEvents.filter((record) => record.status === "pending").length,
    3,
  );
});

function createScenario(clock = new WorldClock()): WorldSimulationFoundation {
  const facilities = new Facilities([{
    facilityId: "farm",
    facilityType: "fixture_food_producer",
    hostId: "settlement_warehouse",
    ownerId: "settlement",
    governorActorId: "operations_manager",
    recipe: {
      inputs: {},
      energyInputs: {},
      maintenanceInputs: {},
      outputs: { food: 2 },
      workforceRequired: 8,
      cycleDays: 0.25,
      blockedRetryDays: null,
    },
    active: true,
    generation: 0,
    nextEventOrdinal: 0,
    pendingTickEventId: null,
    processedEventIds: [],
  }], [{
    hostId: "settlement_warehouse",
    inventory: {},
    storageCaps: { food: 20 },
    cohorts: [{
      cohortId: "residents",
      population: 20,
      availableWorkforce: 10,
      unrest: 0,
    }],
  }]);
  const simulation = new WorldSimulationFoundation({
    clock,
    facilities,
    governance: new Governance({
      managedEntities: [{
        entityId: "farm",
        ownerId: "settlement",
        governorActorId: "operations_manager",
      }],
      governors: [{
        actorId: "operations_manager",
        principalId: "settlement",
        superiorActorId: null,
        roles: ["configured_operations_role"],
        authorityScopes: ["facility:operate"],
        controller: "deterministic_policy",
      }],
      delegations: [],
    }),
    maxEventsPerAdvance: 20,
  });
  simulation.schedule(resourceConsumptionIntent("rations-1", 0.5, {
    hostId: "settlement_warehouse",
    resourceId: "food",
    amount: 5,
    cohortId: "residents",
    unrestIncrease: 2,
    workforceLoss: 3,
    retryDelayDays: 0.25,
  }));
  simulation.schedule(resourceDeliveryIntent("delivery-1", 0.5, {
    hostId: "settlement_warehouse",
    resourceId: "food",
    amount: 3,
  }));
  simulation.scheduleInitialFacilityTick("farm");
  return simulation;
}
