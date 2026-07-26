import assert from "node:assert/strict";
import test from "node:test";
import { Facilities, GovernorAIController, type FacilityRecipe, type WorldMemoryOwnerView } from "../src/index.js";

const RECIPE: FacilityRecipe = { inputs: { leather: 2 }, energyInputs: {}, maintenanceInputs: {}, outputs: { coats: 2 }, workforceRequired: 1, cycleDays: 1, blockedRetryDays: null, shortagePolicies: [{ resourceId: "leather", consequences: [{ type: "block" }, { type: "retry", delayDays: 0.5 }, { type: "none" }] }] };

test("recipe-owned leather shortage blocks industry without changing cohort unrest", () => {
  const facilities = fixture(RECIPE);
  const result = facilities.handleProductionTick(facilities.initialTickIntent("workshop", 0)!, 1);
  assert.equal(result.event.eventType, "FacilityProductionBlocked");
  assert.equal(facilities.snapshot().hosts[0]?.cohorts[0]?.unrest, 0);
  assert.equal(result.nextIntent?.dueElapsedDays, 1.5);
});

test("an explicit missing-tools policy degrades throughput without a social effect", () => {
  const facilities = fixture({ ...RECIPE, inputs: {}, maintenanceInputs: { tools: 1 }, outputs: { coats: 4 }, shortagePolicies: [{ resourceId: "tools", consequences: [{ type: "reduced_output", outputPermille: 500 }, { type: "none" }] }] });
  const result = facilities.handleProductionTick(facilities.initialTickIntent("workshop", 0)!, 1);
  assert.equal(result.event.eventType, "FacilityProductionDegraded");
  assert.deepEqual(result.event.eventType === "FacilityProductionDegraded" && result.event.produced, { coats: 2 });
  assert.equal(facilities.snapshot().hosts[0]?.cohorts[0]?.unrest, 0);
});

test("configured cohort consequence applies once per episode and can apply after recovery", () => {
  const facilities = fixture(RECIPE);
  const effect = { cohortId: "workers", consequences: [{ type: "block" }, { type: "retry", delayDays: 0.25 }, { type: "cohort_delta", cohortId: "workers", conditionId: "hunger", conditionDelta: 1, unrestDelta: 2, workforceDelta: -1, application: "once_per_episode" }] } as const;
  facilities.consumeForCohort("host", "food", 1, effect);
  facilities.consumeForCohort("host", "food", 1, effect);
  assert.equal(facilities.snapshot().hosts[0]?.cohorts[0]?.unrest, 2);
  assert.equal(facilities.deposit("host", "food", 1), true);
  assert.equal(facilities.consumeForCohort("host", "food", 1, effect).outcome, "consumed");
  facilities.consumeForCohort("host", "food", 1, effect);
  assert.equal(facilities.snapshot().hosts[0]?.cohorts[0]?.unrest, 4);
});

test("GovernorController uses fresh private memory and legal affordances only", () => {
  const controller = new GovernorAIController();
  const memory: WorldMemoryOwnerView = { ownerId: "governor", ownerKind: "actor", asOfElapsedDays: 2, entries: [entry(0, "leather", ["block", "none"], "fresh"), entry(1, "food", ["cohort_delta", "retry"], "fresh")] };
  const decision = controller.decide(memory, [{ facilityId: "workshop", facilityHostId: "host", destinationNodeId: "town", executorPartyIds: ["quartermaster"] }], { consequenceWeights: { cohort_delta: 10, block: 2, retry: 1, none: 0 } });
  assert.equal(decision.action === "assign_supply_task" && decision.command.goodsId, "food");
  assert.equal(controller.decide({ ...memory, entries: memory.entries.map((item) => ({ ...item, freshness: "stale" })) }, [], { consequenceWeights: {} }).action, "none");
  assert.equal(controller.decide(memory, [], { consequenceWeights: { cohort_delta: 10 } }).action, "none");
});

function fixture(recipe: FacilityRecipe): Facilities {
  return new Facilities([{ facilityId: "workshop", facilityType: "fixture", hostId: "host", ownerId: "town", governorActorId: "governor", recipe, active: true, generation: 0, nextEventOrdinal: 0, pendingTickEventId: null, processedEventIds: [] }], [{ hostId: "host", inventory: {}, storageCaps: { leather: 10, tools: 10, coats: 10, food: 10 }, cohorts: [{ cohortId: "workers", population: 10, availableWorkforce: 8, unrest: 0 }] }]);
}

function entry(sequence: number, goodsId: string, consequenceTypes: string[], freshness: "fresh" | "stale") {
  return { entryId: `memory:${sequence}`, ingestId: `ingest:${sequence}`, sequence, ownerId: "governor", ownerKind: "actor" as const, kind: "shortage_observation", observedAtElapsedDays: 1, knownAtElapsedDays: 1, staleAfterDays: 2, provenance: { sourceType: "direct_observation" as const, sourceId: `event:${sequence}`, sourceOwnerId: "town", nodeId: "town" }, payload: { facilityId: "workshop", goodsId, amount: 1, consequenceTypes }, ageDays: 1, freshness };
}
