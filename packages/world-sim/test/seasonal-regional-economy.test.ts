import assert from "node:assert/strict";
import { resolve } from "node:path";
import test from "node:test";

import { SeasonalRegionalEconomyRunner, createSeasonalRegionalEconomyFixture, loadPartyTravelConfigFile, loadRegionGraphFile, runSeasonalBatch } from "../src/index.js";

const graph = loadRegionGraphFile(resolve("data/regions/silesia.json"));
const travel = loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json"));

test("seasonal Silesia fixture has ten local hubs, profiled Facilities and at least twelve competing merchants", () => {
  const fixture = createSeasonalRegionalEconomyFixture(graph, travel, 17, 12);
  const snapshot = fixture.runner.snapshot();
  assert.equal(snapshot.runner.world.simulationFoundation?.tradeHubs?.hubs.length, 10);
  assert.equal(snapshot.runner.world.simulationFoundation?.facilities.profileRuntime?.instances.length, 10);
  assert.equal(snapshot.runner.config.merchants.length, 12);
  assert.equal(snapshot.runner.world.parties.length, 22);
  assert.equal(snapshot.runner.world.parties.filter((party) => party.id.startsWith("seasonal_merchant_")).length, 12);
  assert.equal("simulationFoundation" in fixture.runner.partyMapSnapshot("seasonal_merchant_0"), false);
});

test("full year, save mid-cycle and deterministic continuation preserve bounded queues and non-negative stores", () => {
  const fixture = createSeasonalRegionalEconomyFixture(graph, travel, 19);
  fixture.runner.runDays(137);
  const saved = JSON.parse(JSON.stringify(fixture.runner.snapshot()));
  const resumed = SeasonalRegionalEconomyRunner.resume(graph, travel, fixture.economySeed, saved);
  const left = fixture.runner.runDays(223);
  const right = resumed.runDays(223);
  assert.deepEqual(right, left);
  assert.deepEqual(resumed.snapshot(), fixture.runner.snapshot());
  assert.equal(left.pendingQueue < 500, true);
  const hosts = resumed.snapshot().runner.world.simulationFoundation?.facilities.hosts ?? [];
  assert.equal(hosts.every((host) => Object.values(host.inventory).every((amount) => amount >= 0)), true);
  assert.equal(left.profileCompletions > 0, true);
  assert.equal(left.regional.trades > 0, true);
  assert.equal(left.regional.transportDistanceKm > 0, true);
  assert.equal(left.regional.failedCommands > 0, true);
  assert.equal((resumed.snapshot().runner.world.simulationFoundation?.events ?? []).some((event) => event.eventType === "FacilityProfileProcessCompleted" && event.stageId === "sowing"), true);
});

test("multi-seed batch is deterministic and retained history grows only linearly", () => {
  const create = (seed: number) => createSeasonalRegionalEconomyFixture(graph, travel, seed).runner;
  const first = runSeasonalBatch([3, 5], 1, create);
  const second = runSeasonalBatch([3, 5], 1, create);
  assert.deepEqual(second, first);
  for (const result of first) {
    assert.equal(result.reports.length, 1);
    assert.equal(result.reports[0]!.retainedHistory < 10_000, true);
    assert.equal(result.reports.every((report) => report.pendingQueue < 500), true);
  }
});

test("three-year stress run keeps pending work bounded while retained history is linear", () => {
  const runner = createSeasonalRegionalEconomyFixture(graph, travel, 23).runner;
  const reports = runner.runYears(3);
  assert.equal(reports.length, 3);
  assert.equal(reports.every((report) => report.pendingQueue === 20), true);
  assert.equal(reports[2]!.retainedHistory < reports[0]!.retainedHistory * 4, true);
  assert.equal(reports[2]!.regional.trades >= reports[0]!.regional.trades, true);
});
