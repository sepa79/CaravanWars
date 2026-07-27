import assert from "node:assert/strict";
import { resolve } from "node:path";
import test from "node:test";

import { Facilities, Governance, WorldClock, WorldMemory, WorldSimulation, WorldSimulationFoundation, buildNavigationKnowledgeGraph, detectionSucceeds, deterministicSearchPath, distance, distanceToPolyline, loadGoodsCatalogFile, loadPartyCargoConfigFile, loadPartyTravelConfigFile, loadRegionGraphFile, pointAlongPolyline, pointInUncertainty, polylineDistance, spatialSpeedKmPerDay } from "../src/index.js";

const graph = loadRegionGraphFile(resolve("data/regions/silesia.json"));
const travel = loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json"));
const goodsCatalog = loadGoodsCatalogFile(resolve("data/simulation/goods_catalog.json"));
const economy = { goodsCatalog, partyCargoConfig: loadPartyCargoConfigFile(resolve("data/simulation/party_cargo.json")), locationEconomyConfig: { profiles: [], profilesByLocationId: new Map() }, locations: [] };

function fixture(memory = new WorldMemory()) {
  const clock = new WorldClock();
  const facilities = new Facilities([{ facilityId: "bandit_base_store", facilityType: "hideout", hostId: "bandit_base_host", ownerId: "bandits", governorActorId: "bandit_ai", recipe: { inputs: {}, energyInputs: {}, maintenanceInputs: {}, outputs: {}, workforceRequired: 0, cycleDays: 1, blockedRetryDays: null, shortagePolicies: [] }, active: false, generation: 0, nextEventOrdinal: 0, pendingTickEventId: null, processedEventIds: [] }], [{ hostId: "bandit_base_host", inventory: { food: 10 }, storageCaps: { food: 100 }, cohorts: [] }]);
  const governance = new Governance({ managedEntities: [{ entityId: "bandits", ownerId: "bandits", governorActorId: "bandit_ai" }, { entityId: "bandit_party", ownerId: "bandits", governorActorId: "bandit_ai" }, { entityId: "patrol", ownerId: "wroclaw", governorActorId: "governor" }, { entityId: "black_pine_bandit_base", ownerId: "bandits", governorActorId: "bandit_ai" }], governors: [{ actorId: "bandit_ai", principalId: "bandits", superiorActorId: null, roles: ["bandit"], authorityScopes: ["navigation:command", "spatial:relocate"], controller: "deterministic_policy" }, { actorId: "governor", principalId: "wroclaw", superiorActorId: null, roles: ["governor"], authorityScopes: ["navigation:command"], controller: "deterministic_policy" }], delegations: [] });
  const foundation = new WorldSimulationFoundation({ clock, facilities, governance, maxEventsPerAdvance: 1000 });
  return new WorldSimulation(graph, travel, [
    { id: "bandit_party", displayName: "Bandits", managerActorId: "bandit_ai", nodeId: "black_pine_bandit_base", composition: { footCount: 5, horseCount: 0, wagonCount: 0, packAnimalCount: 1, guardCount: 3 }, knownRouteIds: ["great_forest_bandit_track"], cargo: { food: 5 } },
    { id: "merchant", displayName: "Merchant", managerActorId: "merchant_ai", nodeId: "great_forest", composition: { footCount: 2, horseCount: 0, wagonCount: 1, packAnimalCount: 0, guardCount: 0 }, knownRouteIds: ["great_forest_opole"], cargo: {} },
    { id: "patrol", displayName: "Patrol", managerActorId: "governor", nodeId: "great_forest", composition: { footCount: 4, horseCount: 0, wagonCount: 0, packAnimalCount: 1, guardCount: 4 }, knownRouteIds: ["great_forest_opole"], cargo: {} },
  ], economy, clock, foundation, memory);
}

test("spatial primitives are finite, deterministic and terrain-sensitive", () => {
  assert.equal(distance([0, 0], [3, 4]), 5);
  assert.equal(pointInUncertainty([1, 0], { center: [0, 0], radiusKm: 1 }), true);
  const path = deterministicSearchPath([10, 10], 4, 12);
  assert.deepEqual(path, deterministicSearchPath([10, 10], 4, 12));
  assert.equal(polylineDistance([[0, 0], [3, 4], [6, 8]]), 10);
  assert.deepEqual(pointAlongPolyline([[0, 0], [3, 4], [6, 8]], 7.5), [4.5, 6]);
  assert.equal(distanceToPolyline([3, 1], [[0, 0], [6, 0]]), 1);
  const config = { coordinateKmScale: 5, roadSpeedPermille: 1200, trackSpeedPermille: 850, terrainSpeedPermille: { forest: 650 }, burdenSpeedFloorPermille: 500, winterSpeedPermille: 800, nightVisibilityPermille: 500, baseVisibilityKm: 3, maxSearchSteps: 12 };
  assert.equal(spatialSpeedKmPerDay(30, config, ["forest"], 900, 700, true, 500, "offroad") < spatialSpeedKmPerDay(30, config, [], 0, 1000, false, 1000, "road"), true);
  assert.equal(detectionSucceeds("stable", 10, 2, 1000, 0), false);
});

test("hidden base is one truth object known to bandits but absent from merchant knowledge and Party Map", () => {
  const world = fixture();
  const bandit = world.navigationKnowledgeGraph("bandit_party", "party"), merchant = world.navigationKnowledgeGraph("merchant", "party");
  assert.equal(bandit.nodes.some((item) => item.worldObjectId === "black_pine_bandit_base"), true);
  assert.equal(merchant.nodes.some((item) => item.worldObjectId === "black_pine_bandit_base"), false);
  assert.equal(world.partyMapSnapshot("merchant").region.nodes.some((node) => node.id === "black_pine_bandit_base"), false);
  assert.equal(world.partyMapSnapshot("bandit_party").region.nodes.filter((node) => node.id === "black_pine_bandit_base").length, 1);
  const rejected = world.submitCommand({ commandType: "spatial_travel", command: { commandId: "merchant-cheat", issuerActorId: "merchant_ai", partyId: "merchant", kind: "known_target", targetKnowledgeId: "node:black_pine_bandit_base" } }).result;
  assert.equal(rejected.accepted, false);
  assert.equal(!rejected.accepted && rejected.errorCode, "KNOWLEDGE_UNKNOWN");
});

test("off-road travel is scheduled, continuous, cargo-conserving and replays from a mid-journey save", () => {
  const world = fixture();
  assert.equal(world.submitCommand({ commandType: "move_party", command: { party_id: "bandit_party", from_node_id: "black_pine_bandit_base", to_node_id: "great_forest" } }).result.accepted, true);
  world.advanceDays(1);
  world.advanceDays(20);
  const command = { commandType: "spatial_travel" as const, command: { commandId: "return-base", issuerActorId: "bandit_ai", partyId: "bandit_party", kind: "known_target" as const, targetKnowledgeId: "node:black_pine_bandit_base" } };
  assert.equal(world.submitCommand(command).result.accepted, true);
  const duration = world.partySnapshot("bandit_party").spatialTravel!.distanceKm / world.partySnapshot("bandit_party").spatialTravel!.speedKmPerDay;
  world.advanceDays(duration / 2);
  const saved = JSON.parse(JSON.stringify(world.snapshot()));
  const resumed = WorldSimulation.fromSnapshot(graph, travel, economy, saved);
  world.advanceDays(duration / 2 + 0.000001); resumed.advanceDays(duration / 2 + 0.000001);
  assert.deepEqual(resumed.snapshot(), world.snapshot());
  assert.equal(world.partySnapshot("bandit_party").currentNodeId, "black_pine_bandit_base");
  assert.equal(world.partySnapshot("bandit_party").cargo.food, 5);
  assert.equal(world.snapshot().continuousSpace.metrics.hiddenSiteVisits, 1);
});

test("landmark rumor adds uncertainty without truth coordinates; search may fail and knowledge stays isolated", () => {
  const memory = new WorldMemory();
  memory.ingest({ ingestId: "rumor-patrol", ownerId: "patrol", ownerKind: "party", kind: "navigation_rumor", observedAtElapsedDays: 0, knownAtElapsedDays: 0, staleAfterDays: 20, provenance: { sourceType: "rumor", sourceId: "woodcutter", sourceOwnerId: "woodcutter", nodeId: "great_forest" }, payload: { knowledgeId: "area:oak-east", knowledgeKind: "area", worldObjectId: null, estimatedPosition: null, uncertaintyCenter: [89, 34], uncertaintyRadiusKm: 4, relation: "east of the old oak, half a day from the great stone, beside a lake", confidencePermille: 450 } });
  const world = fixture(memory), map = world.partyMapSnapshot("patrol");
  assert.equal(map.navigationKnowledge.approximateAreas.length, 1);
  assert.equal(map.region.nodes.some((node) => node.id === "black_pine_bandit_base"), false);
  const search = world.submitCommand({ commandType: "search_area", command: { commandId: "blind-search", issuerActorId: "governor", partyId: "patrol", areaKnowledgeId: "area:oak-east", searchRadiusKm: 4, observationSkillPermille: 0 } }).result;
  assert.equal(search.accepted, true);
  const travelState = world.partySnapshot("patrol").spatialTravel!;
  const saved = JSON.parse(JSON.stringify(world.snapshot()));
  const resumed = WorldSimulation.fromSnapshot(graph, travel, economy, saved);
  world.advanceDays(travelState.distanceKm / travelState.speedKmPerDay + 0.001); resumed.advanceDays(travelState.distanceKm / travelState.speedKmPerDay + 0.001);
  assert.deepEqual(resumed.snapshot(), world.snapshot());
  assert.equal(world.navigationKnowledgeGraph("patrol", "party").nodes.some((item) => item.worldObjectId === "black_pine_bandit_base"), false);
  assert.equal(world.navigationKnowledgeGraph("merchant", "party").areas.length, 0);
  assert.equal(world.snapshot().continuousSpace.metrics.falseLeads, 1);
});

test("successful repeated observation is explicit and idempotent while another actor remains ignorant", () => {
  const world = fixture();
  let discovered = false;
  for (let index = 0; index < 30 && !discovered; index += 1) {
    world.submitCommand({ commandType: "observe_surroundings", command: { commandId: `bandit-look-${index}`, issuerActorId: "bandit_ai", partyId: "bandit_party", observationSkillPermille: 1000 } });
    discovered = world.navigationKnowledgeGraph("bandit_party", "party").nodes.some((item) => item.worldObjectId === "black_pine_bandit_base" && item.provenanceEntryId !== "memory:0");
  }
  assert.equal(discovered, true);
  assert.equal(world.navigationKnowledgeGraph("bandit_party", "party").edges.some((item) => item.worldObjectId === "great_forest_bandit_track"), true);
  const before = world.snapshot().worldMemory.entries.length;
  const replay = world.submitCommand({ commandType: "observe_surroundings", command: { commandId: "bandit-look-0", issuerActorId: "bandit_ai", partyId: "bandit_party", observationSkillPermille: 1000 } }).result;
  assert.equal("idempotentReplay" in replay && replay.idempotentReplay, true);
  assert.equal(world.snapshot().worldMemory.entries.length, before);
  assert.equal(world.navigationKnowledgeGraph("merchant", "party").nodes.some((item) => item.worldObjectId === "black_pine_bandit_base"), false);
});

test("reports preserve provenance with delay and relocation leaves private knowledge stale rather than teleporting truth", () => {
  const world = fixture();
  const immediate = world.submitCommand({ commandType: "report_navigation_knowledge", command: { commandId: "instant-report", issuerActorId: "bandit_ai", reporterPartyId: "bandit_party", recipientOwnerId: "patrol", recipientOwnerKind: "party", sourceKnowledgeId: "node:black_pine_bandit_base", knownDelayDays: 0, confidenceLossPermille: 100, distortionPermille: 200 } }).result;
  assert.equal(immediate.accepted, false);
  assert.equal(world.submitCommand({ commandType: "report_navigation_knowledge", command: { commandId: "courier-report", issuerActorId: "bandit_ai", reporterPartyId: "bandit_party", recipientOwnerId: "patrol", recipientOwnerKind: "party", sourceKnowledgeId: "node:black_pine_bandit_base", knownDelayDays: 2, confidenceLossPermille: 200, distortionPermille: 300 } }).result.accepted, true);
  assert.equal(world.navigationKnowledgeGraph("patrol", "party").nodes.some((item) => item.worldObjectId === "black_pine_bandit_base"), false);
  world.advanceDays(2);
  const report = world.navigationKnowledgeGraph("patrol", "party").nodes.find((item) => item.knowledgeId === "node:black_pine_bandit_base")!;
  assert.equal(report.worldObjectId, null);
  assert.equal(report.uncertainty !== null, true);
  assert.equal(report.provenanceEntryId.length > 0, true);
  const oldPosition = report.uncertainty!.center;
  assert.equal(world.submitCommand({ commandType: "relocate_spatial_object", command: { commandId: "relocate-base", issuerActorId: "bandit_ai", worldObjectId: "black_pine_bandit_base", position: [98, 40] } }).result.accepted, true);
  assert.deepEqual(world.navigationKnowledgeGraph("patrol", "party").nodes.find((item) => item.knowledgeId === "node:black_pine_bandit_base")!.uncertainty!.center, oldPosition);
  const denied = world.submitCommand({ commandType: "relocate_spatial_object", command: { commandId: "merchant-relocate", issuerActorId: "merchant_ai", worldObjectId: "black_pine_bandit_base", position: [99, 41] } }).result;
  assert.equal(denied.accepted, false);
});

test("invalid coordinates, command conflicts and unauthorized exploration fail atomically", () => {
  const world = fixture(), before = world.snapshot();
  assert.equal(world.submitCommand({ commandType: "relocate_spatial_object", command: { commandId: "nan", issuerActorId: "bandit_ai", worldObjectId: "black_pine_bandit_base", position: [Number.NaN, 1] } }).result.accepted, false);
  const denied = world.submitCommand({ commandType: "observe_surroundings", command: { commandId: "denied-look", issuerActorId: "merchant_ai", partyId: "patrol", observationSkillPermille: 1000 } }).result;
  assert.equal(denied.accepted, false);
  const first = world.submitCommand({ commandType: "observe_surroundings", command: { commandId: "same-id", issuerActorId: "governor", partyId: "patrol", observationSkillPermille: 0 } }).result;
  const conflict = world.submitCommand({ commandType: "observe_surroundings", command: { commandId: "same-id", issuerActorId: "governor", partyId: "patrol", observationSkillPermille: 1 } }).result;
  assert.equal(first.accepted, true); assert.equal(conflict.accepted, false);
  assert.deepEqual(world.partySnapshot("patrol"), before.parties.find((party) => party.id === "patrol"));
});

test("knowledge graph is a WorldMemory projection with explicit stale state", () => {
  const memory = new WorldMemory();
  memory.ingest({ ingestId: "relation", ownerId: "patrol", ownerKind: "party", kind: "navigation_report", observedAtElapsedDays: 0, knownAtElapsedDays: 2, staleAfterDays: 1, provenance: { sourceType: "report", sourceId: "scout", sourceOwnerId: "scout", nodeId: "great_forest" }, payload: { knowledgeId: "relation:lake", knowledgeKind: "relation", worldObjectId: null, estimatedPosition: null, uncertaintyCenter: [90, 35], uncertaintyRadiusKm: 5, relation: "beside the lake", confidencePermille: 300 } });
  assert.equal(buildNavigationKnowledgeGraph(memory.ownerView("patrol", "party", 1)).relations.length, 0);
  assert.equal(buildNavigationKnowledgeGraph(memory.ownerView("patrol", "party", 4)).relations[0]?.freshness, "stale");
});
