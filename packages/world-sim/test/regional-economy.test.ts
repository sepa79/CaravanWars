import assert from "node:assert/strict";
import { resolve } from "node:path";
import test from "node:test";

import {
  AutonomousRegionalEconomyRunner,
  LogisticsTaskBoard,
  createAutonomousRegionalEconomyFixture,
  loadPartyTravelConfigFile,
  loadRegionGraphFile,
} from "../src/index.js";

const graph = loadRegionGraphFile(resolve("data/regions/silesia.json"));
const travel = loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json"));

test("logistics lifecycle is idempotent and rejects duplicate active needs", () => {
  const board = new LogisticsTaskBoard();
  const identity = { taskId: "task-1", ownerActorId: "governor", executorPartyId: "party", destinationEntityId: "facility", destinationNodeId: "node", goodsId: "food", amount: 4 };
  const created = board.create(identity, "transition-1", 1, "shortage");
  assert.equal(created.accepted, true);
  const replay = board.create(identity, "transition-1", 1, "shortage");
  assert.equal(replay.accepted && replay.idempotentReplay, true);
  const duplicate = { ...identity, taskId: "task-2" };
  assert.equal(board.create(duplicate, "transition-2", 1, "same shortage").accepted, false);
  assert.equal(board.transition("task-1", "accepted", "transition-3", 1, "received").accepted, true);
  assert.equal(board.transition("task-1", "in_progress", "transition-4", 1, "started").accepted, true);
  assert.equal(board.transition("task-1", "completed", "transition-5", 2, "delivered").accepted, true);
  assert.deepEqual(board.create(duplicate, "transition-2", 1, "same shortage"), board.create(duplicate, "transition-2", 1, "same shortage"));
  assert.equal(board.create(duplicate, "transition-2", 1, "same shortage").accepted, false);
  assert.equal(board.transition("task-1", "accepted", "transition-6", 3, "illegal").accepted, false);
  const failedIdentity = { ...identity, taskId: "task-failed", goodsId: "leather" };
  assert.equal(board.create(failedIdentity, "transition-7", 3, "industrial shortage").accepted, true);
  assert.equal(board.transition("task-failed", "accepted", "transition-8", 3, "received").accepted, true);
  assert.equal(board.transition("task-failed", "in_progress", "transition-9", 3, "started").accepted, true);
  assert.equal(board.transition("task-failed", "failed", "transition-10", 4, "capacity failure").accepted, true);
});

test("autonomous region runs multiple actors through production, shortage, trade, transport and recovery", () => {
  const fixture = createAutonomousRegionalEconomyFixture(graph, travel);
  const metrics = fixture.runner.runDays(30);
  assert.equal(metrics.elapsedDays > 30, true);
  assert.equal((metrics.productionByGoods.food ?? 0) > 0, true);
  assert.equal(metrics.consumptionAttempts >= 90, true);
  assert.equal(metrics.shortages > 0, true);
  assert.equal(metrics.trades > 0, true);
  assert.equal(metrics.transportDistanceKm > 0, true);
  assert.equal(metrics.completedFacilityCycles > 0, true);
  assert.equal(metrics.pendingClockEvents < 600, true);
  assert.equal(metrics.activeTasks <= 3, true);
  assert.equal(metrics.transportedCargo > 0, true);
  assert.equal(metrics.failedCommands > 0, true);
  const decisions = fixture.runner.snapshot().decisions;
  assert.equal(decisions.some((item) => item.actorId === "merchant_a_actor" && item.commandType !== null), true);
  assert.equal(decisions.some((item) => item.actorId === "merchant_b_actor" && item.commandType !== null), true);
});

test("regional command boundary rejects foreign authority without creating party memory", () => {
  const fixture = createAutonomousRegionalEconomyFixture(graph, travel);
  const result = fixture.world.submitCommand({ commandType: "assign_supply_task", command: {
    commandId: "foreign-assignment", issuerActorId: "merchant_a_actor", taskId: "foreign-task",
    executorPartyId: "opole_supply", facilityId: "opole_tannery", facilityHostId: "opole_host",
    destinationNodeId: "opole", goodsId: "food", amount: 6,
  }}).result;
  assert.equal(result.accepted, false);
  assert.equal(fixture.world.worldMemoryView("opole_supply", "party").entries.some((entry) => entry.payload.commandId === "foreign-assignment"), false);
  const valid = { commandId: "valid-assignment", issuerActorId: "opole_governor", taskId: "delivery-failure", executorPartyId: "opole_supply", facilityId: "opole_tannery", facilityHostId: "opole_host", destinationNodeId: "opole", goodsId: "food", amount: 6 };
  assert.equal(fixture.world.submitCommand({ commandType: "assign_supply_task", command: valid }).result.accepted, true);
  const beforeHost = fixture.world.facilityHostResource("opole_host", "food");
  const failedDelivery = fixture.world.submitCommand({ commandType: "deliver_supply_task", command: { commandId: "failed-delivery", issuerActorId: "opole_supply_actor", taskId: "delivery-failure", executorPartyId: "opole_supply", facilityId: "opole_tannery", facilityHostId: "opole_host", goodsId: "food", amount: 6 } }).result;
  assert.equal(failedDelivery.accepted, false);
  assert.equal(fixture.world.facilityHostResource("opole_host", "food"), beforeHost);
});

test("regional physical pickup rejects limited cargo capacity without partial mutation", () => {
  const fixture = createAutonomousRegionalEconomyFixture(graph, travel);
  fixture.world.advanceDays(1);
  assert.equal(fixture.world.submitCommand({ commandType: "trade_hub_transfer_facility_goods", command: { commandId: "capacity-deposit", issuerActorId: "wroclaw_governor", accountEntityId: "wroclaw", hubId: "wroclaw_hub", direction: "deposit", goodsId: "food", amount: 6, facilityId: "wroclaw_farm", facilityHostId: "wroclaw_host" } }).result.accepted, true);
  assert.equal(fixture.world.submitCommand({ commandType: "place_trade_hub_order", command: { commandId: "capacity-sell", issuerActorId: "wroclaw_governor", accountEntityId: "wroclaw", hubId: "wroclaw_hub", orderId: "capacity-sell-order", side: "sell", goodsId: "food", quantity: 6, limitPrice: 2, expiresAtElapsedDays: null } }).result.accepted, true);
  assert.equal(fixture.world.submitCommand({ commandType: "place_trade_hub_order", command: { commandId: "capacity-buy", issuerActorId: "merchant_b_actor", accountEntityId: "merchant_b", hubId: "wroclaw_hub", orderId: "capacity-buy-order", side: "buy", goodsId: "food", quantity: 6, limitPrice: 2, expiresAtElapsedDays: null } }).result.accepted, true);
  fixture.world.advanceDays(0.001);
  const before = fixture.world.partySnapshot("merchant_b").cargo;
  const pickup = fixture.world.submitCommand({ commandType: "trade_hub_transfer_party_goods", command: { commandId: "capacity-pickup", issuerActorId: "merchant_b_actor", accountEntityId: "merchant_b", partyId: "merchant_b", hubId: "wroclaw_hub", direction: "withdraw", goodsId: "food", amount: 6 } }).result;
  assert.equal(pickup.accepted, false);
  assert.deepEqual(fixture.world.partySnapshot("merchant_b").cargo, before);
});

test("stale source knowledge abandons work explicitly and Governor reprioritizes industrial shortage", () => {
  const runner = createAutonomousRegionalEconomyFixture(graph, travel).runner;
  runner.runDays(60);
  const tasks = runner.diagnostics().tasks;
  assert.equal(tasks.some((task) => task.status === "abandoned" && task.transitions.at(-1)?.reason === "stale_source_information"), true);
  assert.equal(tasks.some((task) => task.destinationEntityId === "raciborz_workshop" && task.goodsId === "leather"), true);
});

test("save/resume and uninterrupted continuation produce identical deterministic reports", () => {
  const uninterrupted = createAutonomousRegionalEconomyFixture(graph, travel, 23);
  uninterrupted.runner.runDays(15);
  const checkpoint = JSON.parse(JSON.stringify(uninterrupted.runner.snapshot()));
  uninterrupted.runner.runDays(15);
  const resumed = AutonomousRegionalEconomyRunner.resume(graph, travel, uninterrupted.economySeed, checkpoint);
  resumed.runDays(15);
  assert.deepEqual(resumed.snapshot(), uninterrupted.runner.snapshot());
  assert.deepEqual(resumed.metrics(), uninterrupted.runner.metrics());
});

test("180-day headless run remains bounded and deterministic", () => {
  const left = createAutonomousRegionalEconomyFixture(graph, travel, 31).runner;
  const right = createAutonomousRegionalEconomyFixture(graph, travel, 31).runner;
  const leftMetrics = left.runDays(180);
  const rightMetrics = right.runDays(180);
  assert.deepEqual(leftMetrics, rightMetrics);
  assert.deepEqual(left.snapshot(), right.snapshot());
  assert.equal(leftMetrics.pendingClockEvents < 100, true);
  assert.equal(leftMetrics.activeTasks <= 3, true);
  assert.equal(left.diagnostics().settlements.reduce((sum, hub) => sum + hub.openOrders, 0) < 10, true);
});

test("party map never contains regional truth diagnostics or another party memory", () => {
  const runner = createAutonomousRegionalEconomyFixture(graph, travel).runner;
  runner.runDays(2);
  const partyJson = JSON.stringify(runner.partyMapSnapshot("merchant_a"));
  assert.equal(partyJson.includes("truthView"), false);
  assert.equal(partyJson.includes("recentDecisions"), false);
  assert.equal(partyJson.includes("merchant_b"), false);
  assert.equal(runner.diagnostics().truthView, true);
});
