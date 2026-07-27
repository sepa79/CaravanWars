import assert from "node:assert/strict";
import { resolve } from "node:path";
import test from "node:test";

import {
  MerchantMemoryAI,
  WorldSimulation,
  loadGoodsCatalogFile,
  loadLocationEconomyConfigFile,
  loadPartyCargoConfigFile,
  loadPartyTravelConfigFile,
  loadRegionGraphFile,
} from "../src/index.js";
import type { MerchantMemoryEntry, PartySeed, WorldEconomySeed } from "../src/index.js";

const SOURCE_MEMORY: MerchantMemoryEntry = {
  kind: "location_observation",
  ownerId: "merchant_party",
  nodeId: "opole",
  observedLocationId: "opole_stronghold",
  observedResources: { food: 40 },
};
const NEED_MEMORY: MerchantMemoryEntry = {
  kind: "need_ledger",
  ownerId: "merchant_party",
  goodsId: "food",
  locationId: "wroclaw_city",
  nodeId: "wroclaw",
  neededAmount: 10,
};

test("merchant AI moves food from remembered source to remembered need through normal commands", () => {
  const simulation = createMerchantSimulation(40);
  const ai = new MerchantMemoryAI();
  const memory = [SOURCE_MEMORY, NEED_MEMORY];

  const withdraw = ai.process(simulation, "merchant_party", memory);
  assert.equal(withdraw.action, "withdraw");
  assert.equal(withdraw.commandResult?.accepted, true);
  assert.equal(simulation.partySnapshot("merchant_party").cargo.food, 10);

  const travel = ai.process(simulation, "merchant_party", memory);
  assert.equal(travel.action, "travel");
  assert.equal(travel.commandResult?.accepted, true);
  simulation.advanceDays(6);
  assert.equal(simulation.partySnapshot("merchant_party").currentNodeId, "wroclaw");

  const deposit = ai.process(simulation, "merchant_party", memory);
  assert.equal(deposit.action, "deposit");
  assert.equal(deposit.commandResult?.accepted, true);
  assert.equal(simulation.partySnapshot("merchant_party").cargo.food, undefined);
  assert.equal(
    simulation.snapshot().locations.find((location) => location.id === "wroclaw_city")
      ?.resources.food,
    10,
  );
  assert.equal(
    simulation.snapshot().runtimeEvents.filter((event) => event.eventType === "goods_transferred").length,
    2,
  );
});

test("merchant AI ignores foreign memory and does not inspect remote truth", () => {
  const simulation = createMerchantSimulation(40);
  const before = simulation.snapshot();
  const ai = new MerchantMemoryAI();
  const foreignNeed: MerchantMemoryEntry = { ...NEED_MEMORY, ownerId: "other_party" };

  const decision = ai.process(simulation, "merchant_party", [SOURCE_MEMORY, foreignNeed]);
  assert.deepEqual(decision, {
    action: "none",
    reason: "food_need_memory_missing",
    submittedCommand: null,
    commandResult: null,
  });
  assert.deepEqual(simulation.snapshot(), before);
});

test("stale source memory produces an explicit rejected command without truth-based adjustment", () => {
  const simulation = createMerchantSimulation(5);
  const ai = new MerchantMemoryAI();

  const decision = ai.process(simulation, "merchant_party", [SOURCE_MEMORY, NEED_MEMORY]);
  assert.equal(decision.action, "withdraw");
  assert.equal(decision.commandResult?.accepted, false);
  if (decision.commandResult?.accepted !== false) assert.fail("Expected rejected transfer.");
  assert.equal(decision.commandResult.errorCode, "INSUFFICIENT_LOCATION_GOODS");
  assert.equal(simulation.partySnapshot("merchant_party").cargo.food, undefined);
});

function createMerchantSimulation(opoleFood: number): WorldSimulation {
  const goodsCatalog = loadGoodsCatalogFile(resolve("data/simulation/goods_catalog.json"));
  const party: PartySeed = {
    id: "merchant_party",
    displayName: "Miroslaw's caravan",
    managerActorId: "merchant_miroslaw",
    nodeId: "opole",
    composition: {
      footCount: 8,
      horseCount: 2,
      wagonCount: 1,
      packAnimalCount: 1,
      guardCount: 2,
    },
    knownRouteIds: ["wroclaw_opole"],
    cargo: {},
  };
  const economy: WorldEconomySeed = {
    goodsCatalog,
    partyCargoConfig: loadPartyCargoConfigFile(resolve("data/simulation/party_cargo.json")),
    locationEconomyConfig: loadLocationEconomyConfigFile(
      resolve("data/simulation/location_economy.json"),
      goodsCatalog,
    ),
    locations: [
      {
        id: "wroclaw_city",
        displayName: "Wroclaw city",
        managerActorId: "mayor_wroclaw",
        nodeId: "wroclaw",
        resources: { food: 0, grain: 0, coin: 0, tools: 0, horses: 0 },
      },
      {
        id: "opole_stronghold",
        displayName: "Opole stronghold",
        managerActorId: "castellan_opole",
        nodeId: "opole",
        resources: { food: opoleFood, coin: 0, horses: 0, iron: 0, tools: 0 },
      },
      {
        id: "nysa_monastery",
        displayName: "Nysa monastery",
        managerActorId: "abbot_nysa",
        nodeId: "nysa",
        resources: { food: 0, coin: 0, horses: 0, wax: 0 },
      },
    ],
  };
  return new WorldSimulation(
    loadRegionGraphFile(resolve("data/regions/silesia.json")),
    loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json")),
    [party],
    economy,
  );
}
