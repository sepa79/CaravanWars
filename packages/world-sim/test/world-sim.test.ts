import assert from "node:assert/strict";
import { resolve } from "node:path";
import test from "node:test";

import {
  WorldSimulation,
  WorldSimulationConfigurationError,
  calculatePartyTravelSpeed,
  loadPartyTravelConfigFile,
  loadGoodsCatalogFile,
  loadLocationEconomyConfigFile,
  loadPartyCargoConfigFile,
  loadRegionGraphFile,
} from "../src/index.js";
import type {
  CommandResult,
  MovePartyCommand,
  PartySeed,
  TransferGoodsCommand,
  TransferGoodsResult,
} from "../src/index.js";

const SILESIA_PATH = resolve("data/regions/silesia.json");
const PARTY_TRAVEL_PATH = resolve("data/simulation/party_travel.json");

const PLAYER_PARTY: PartySeed = {
  id: "player_party",
  displayName: "Player caravan",
  managerActorId: "player_caravan_leader",
  nodeId: "wroclaw",
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

test("valid adjacent move follows authored geometry and arrives after deterministic ticks", () => {
  const simulation = createSimulation();
  const result = submitMove(simulation, {
    party_id: "player_party",
    from_node_id: "wroclaw",
    to_node_id: "opole",
  });

  assert.deepEqual(result, { accepted: true });
  simulation.advanceDays(25 / 31);
  const travelingParty = simulation.snapshot().parties[0];
  assert.equal(travelingParty?.status, "traveling");
  assert.deepEqual(travelingParty?.position, [52, 34]);
  assert.equal(travelingParty?.travel?.progressKm, 25);

  simulation.advanceDays(75 / 31);
  const arrivedParty = simulation.snapshot().parties[0];
  assert.equal(arrivedParty?.status, "idle");
  assert.equal(arrivedParty?.currentNodeId, "opole");
  assert.deepEqual(arrivedParty?.position, [66, 43]);
});

test("reverse travel follows the same authored route in reverse", () => {
  const simulation = createSimulation();
  assert.equal(submitMove(simulation, {
    party_id: "player_party",
    from_node_id: "wroclaw",
    to_node_id: "opole",
  }).accepted, true);
  simulation.advanceDays(100 / 31);
  assert.equal(submitMove(simulation, {
    party_id: "player_party",
    from_node_id: "opole",
    to_node_id: "wroclaw",
  }).accepted, true);

  simulation.advanceDays(18 / 31);
  assert.deepEqual(simulation.snapshot().parties[0]?.position, [63, 41]);
});

test("rejected movement commands do not mutate party state", () => {
  const cases = [
    {
      command: { party_id: "missing", from_node_id: "wroclaw", to_node_id: "opole" },
      errorCode: "PARTY_NOT_FOUND",
    },
    {
      command: { party_id: "player_party", from_node_id: "missing", to_node_id: "opole" },
      errorCode: "NODE_NOT_FOUND",
    },
    {
      command: { party_id: "player_party", from_node_id: "opole", to_node_id: "wroclaw" },
      errorCode: "ORIGIN_MISMATCH",
    },
    {
      command: { party_id: "player_party", from_node_id: "wroclaw", to_node_id: "olomouc" },
      errorCode: "ROUTE_NOT_FOUND",
    },
  ] as const;

  for (const testCase of cases) {
    const simulation = createSimulation();
    const before = simulation.snapshot();
    const result = submitMove(simulation, testCase.command);
    assert.equal(result.accepted, false);
    if (result.accepted) assert.fail("Expected rejected command.");
    assert.equal(result.errorCode, testCase.errorCode);
    assert.deepEqual(simulation.snapshot(), before);
  }
});

test("rejects a second movement command while a party is traveling", () => {
  const simulation = createSimulation();
  assert.equal(submitMove(simulation, {
    party_id: "player_party",
    from_node_id: "wroclaw",
    to_node_id: "opole",
  }).accepted, true);

  const result = submitMove(simulation, {
    party_id: "player_party",
    from_node_id: "wroclaw",
    to_node_id: "opole",
  });
  assert.equal(result.accepted, false);
  if (result.accepted) assert.fail("Expected rejected command.");
  assert.equal(result.errorCode, "PARTY_BUSY");
});

test("rejects an existing route that the party does not know", () => {
  const graph = loadRegionGraphFile(SILESIA_PATH);
  const config = loadPartyTravelConfigFile(PARTY_TRAVEL_PATH);
  const simulation = new WorldSimulation(
    graph,
    config,
    [{ ...PLAYER_PARTY, knownRouteIds: [] }],
    null,
  );

  const result = submitMove(simulation, {
    party_id: "player_party",
    from_node_id: "wroclaw",
    to_node_id: "opole",
  });
  assert.equal(result.accepted, false);
  if (result.accepted) assert.fail("Expected rejected command.");
  assert.equal(result.errorCode, "ROUTE_UNKNOWN");
});

test("party map snapshot includes only party-known graph facts", () => {
  const simulation = createSimulation();
  const partyMap = simulation.partyMapSnapshot("player_party");

  assert.equal(partyMap.mode, "party");
  assert.equal(partyMap.observerPartyId, "player_party");
  assert.deepEqual(partyMap.region.nodes.map((node) => node.id), ["wroclaw", "opole"]);
  assert.deepEqual(partyMap.region.edges.map((edge) => edge.id), ["wroclaw_opole"]);
  assert.deepEqual(partyMap.region.edges[0]?.routeWaypoints, []);
  assert.deepEqual(partyMap.region.landmarks, []);
  assert.deepEqual(partyMap.region.terrainAreas, []);
  assert.deepEqual(partyMap.snapshot.parties.map((party) => party.id), ["player_party"]);
});

test("starting known-route travel creates owner-specific observations and reveals only observed marks", () => {
  const simulation = createSimulation();
  assert.equal(submitMove(simulation, {
    party_id: "player_party",
    from_node_id: "wroclaw",
    to_node_id: "opole",
  }).accepted, true);

  const partyMap = simulation.partyMapSnapshot("player_party");
  assert.deepEqual(
    partyMap.region.edges[0]?.routeWaypoints.map((waypoint) => waypoint.id),
    [
      "wroclaw_opole_old_willow_ford",
      "wroclaw_opole_sleza_view",
      "wroclaw_opole_odra_bend",
    ],
  );
  assert.deepEqual(
    partyMap.region.landmarks.map((landmark) => landmark.id),
    ["sleza_massif", "old_willow_ford"],
  );
  assert.deepEqual(partyMap.region.terrainAreas, []);

  const events = simulation.snapshot().runtimeEvents;
  assert.equal(events.length, 3);
  assert.deepEqual(events[0], {
    eventType: "worldsim_route_waypoint_observed",
    elapsedDays: 0,
    ownerPartyId: "player_party",
    edgeId: "wroclaw_opole",
    originNodeId: "wroclaw",
    destinationNodeId: "opole",
    waypointId: "wroclaw_opole_old_willow_ford",
    waypointKind: "ford",
    distanceFromStartKm: 25,
    elevationM: 92,
    terrainAreaIds: ["odra_valley"],
    landmarkIds: ["old_willow_ford"],
    landmarkTags: ["odra", "ford", "crossing"],
  });
});

test("party map snapshot rejects an unknown observer instead of returning truth", () => {
  const simulation = createSimulation();
  assert.throws(() => simulation.partyMapSnapshot("missing"), /Party missing does not exist/);
});

test("composition uses the configured speed formula and minimum", () => {
  const config = loadPartyTravelConfigFile(PARTY_TRAVEL_PATH);
  assert.equal(calculatePartyTravelSpeed(PLAYER_PARTY.composition, config), 31);
  assert.equal(calculatePartyTravelSpeed({
    footCount: 2,
    horseCount: 0,
    wagonCount: 20,
    packAnimalCount: 0,
    guardCount: 0,
  }, config), 8);
});

test("rejects invalid party composition in the explicit scenario seed", () => {
  const graph = loadRegionGraphFile(SILESIA_PATH);
  const config = loadPartyTravelConfigFile(PARTY_TRAVEL_PATH);

  assert.throws(
    () => new WorldSimulation(graph, config, [{
      ...PLAYER_PARTY,
      composition: { ...PLAYER_PARTY.composition, wagonCount: -1 },
    }], null),
    WorldSimulationConfigurationError,
  );
});

test("transfer goods moves physical stock atomically through the command boundary", () => {
  const simulation = createEconomySimulation();
  const result = submitTransfer(simulation, {
    party_id: "player_party",
    location_id: "wroclaw_city",
    goods_id: "food",
    amount: 10,
    direction: "withdraw_from_location",
  });

  assert.deepEqual(result, { accepted: true });
  assert.equal(simulation.snapshot().parties[0]?.cargo.food, 10);
  assert.equal(simulation.snapshot().locations[0]?.resources.food, 30);
  assert.equal(simulation.snapshot().parties[0]?.cargoCapacityBulk, 37);
  assert.equal(simulation.snapshot().parties[0]?.cargoUsedBulk, 10);
  assert.equal(simulation.snapshot().runtimeEvents.at(-1)?.eventType, "goods_transferred");
});

test("rejected transfers preserve party cargo and location resources", () => {
  const simulation = createEconomySimulation();
  const before = simulation.snapshot();
  const result = submitTransfer(simulation, {
    party_id: "player_party",
    location_id: "opole_stronghold",
    goods_id: "food",
    amount: 1,
    direction: "withdraw_from_location",
  });

  assert.equal(result.accepted, false);
  if (result.accepted) assert.fail("Expected transfer rejection.");
  assert.equal(result.errorCode, "LOCATION_MISMATCH");
  assert.deepEqual(simulation.snapshot(), before);
});

test("deposit rejects a location storage-cap overflow without partial mutation", () => {
  const simulation = createEconomySimulation(150, { food: 1 });
  const before = simulation.snapshot();
  const result = submitTransfer(simulation, {
    party_id: "player_party",
    location_id: "wroclaw_city",
    goods_id: "food",
    amount: 1,
    direction: "deposit_to_location",
  });

  assert.equal(result.accepted, false);
  if (result.accepted) assert.fail("Expected storage-cap rejection.");
  assert.equal(result.errorCode, "LOCATION_STORAGE_EXCEEDED");
  assert.deepEqual(simulation.snapshot(), before);
});

test("location economy applies consumption before production only for crossed full days", () => {
  const simulation = createEconomySimulation();
  simulation.advanceDays(0.5);
  assert.equal(simulation.snapshot().locations[0]?.resources.food, 40);

  simulation.advanceDays(0.5);
  const wroclaw = simulation.snapshot().locations[0];
  assert.equal(wroclaw?.resources.food, 36);
  assert.equal(wroclaw?.resources.grain, 18);
  assert.equal(wroclaw?.resources.coin, 5);
  assert.equal(wroclaw?.resources.tools, 1);
  assert.equal(
    simulation.snapshot().runtimeEvents.filter((event) =>
      event.eventType === "location_economy_ticked").length,
    3,
  );
});

test("twenty-four explicit hourly advances cross exactly one economy day", () => {
  const simulation = createEconomySimulation();
  for (let hour = 0; hour < 24; hour += 1) simulation.advanceDays(1 / 24);

  assert.equal(simulation.snapshot().locations[0]?.resources.food, 36);
  assert.ok(Math.abs(simulation.snapshot().clock.elapsedDays - 1) < 1e-9);
});

function createSimulation(): WorldSimulation {
  return new WorldSimulation(
    loadRegionGraphFile(SILESIA_PATH),
    loadPartyTravelConfigFile(PARTY_TRAVEL_PATH),
    [PLAYER_PARTY],
    null,
  );
}

function createEconomySimulation(
  wroclawFood = 40,
  partyCargo: Readonly<Record<string, number>> = {},
): WorldSimulation {
  const goodsCatalog = loadGoodsCatalogFile(resolve("data/simulation/goods_catalog.json"));
  return new WorldSimulation(
    loadRegionGraphFile(SILESIA_PATH),
    loadPartyTravelConfigFile(PARTY_TRAVEL_PATH),
    [{ ...PLAYER_PARTY, cargo: partyCargo }],
    {
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
          resources: { food: wroclawFood, grain: 20, coin: 0, tools: 0, horses: 0 },
        },
        {
          id: "opole_stronghold",
          displayName: "Opole stronghold",
          managerActorId: "castellan_opole",
          nodeId: "opole",
          resources: { food: 0, coin: 0, horses: 0, iron: 0, tools: 0 },
        },
        {
          id: "nysa_monastery",
          displayName: "Nysa monastery",
          managerActorId: "abbot_nysa",
          nodeId: "nysa",
          resources: { food: 0, coin: 0, horses: 0, wax: 0 },
        },
      ],
    },
  );
}

function submitMove(
  simulation: WorldSimulation,
  command: MovePartyCommand,
): CommandResult {
  return simulation.submitCommand({ commandType: "move_party", command }).result;
}

function submitTransfer(
  simulation: WorldSimulation,
  command: TransferGoodsCommand,
): TransferGoodsResult {
  return simulation.submitCommand({ commandType: "transfer_goods", command }).result;
}
