import assert from "node:assert/strict";
import { resolve } from "node:path";
import test from "node:test";

import { BanditRouteController, Facilities, Governance, RouteSecurity, SecurityAwareRouteController, WorldClock, WorldMemory, WorldSimulation, WorldSimulationFoundation, loadGoodsCatalogFile, loadPartyCargoConfigFile, loadPartyTravelConfigFile, loadRegionGraphFile } from "../src/index.js";
import type { EncounterPartyView, EncounterPhysicalMutation, RouteSecuritySnapshot } from "../src/index.js";

const SNAPSHOT: RouteSecuritySnapshot = {
  seed: 17,
  routes: [{ routeId: "a_b", riskPermille: 300, trafficValue: 40, incidentCount: 0, successfulAmbushes: 0, patrolStrength: 0 }],
  parties: [
    { partyId: "bandits", role: "bandit", ownerId: "bandits", governorActorId: "bandit_ai", conditionPermille: 900, moralePermille: 800, supplies: 10, casualties: 0 },
    { partyId: "patrol", role: "patrol", ownerId: "town", governorActorId: "governor", conditionPermille: 1000, moralePermille: 900, supplies: 10, casualties: 0 },
    { partyId: "escort", role: "escort", ownerId: "town", governorActorId: "governor", conditionPermille: 1000, moralePermille: 900, supplies: 10, casualties: 0 },
  ], tasks: [], encounters: [], processedCommandIds: [], processedEventIds: [],
};

function party(partyId: string, guardCount: number, cargo: Record<string, number> = {}): EncounterPartyView {
  return { partyId, travelingRouteId: "a_b", composition: { footCount: 2, horseCount: 0, wagonCount: 1, packAnimalCount: 0, guardCount }, cargo, cargoFreeBulk: 20, conditionPermille: 1000, moralePermille: 900 };
}

test("encounter is a deterministic delayed event with atomic physical effects and exact replay", () => {
  const clock = new WorldClock();
  const security = new RouteSecurity(SNAPSHOT);
  const foundation = new WorldSimulationFoundation({ clock, facilities: new Facilities([], []), governance: new Governance({ managedEntities: [{ entityId: "bandits", ownerId: "bandits", governorActorId: "bandit_ai" }], governors: [{ actorId: "bandit_ai", principalId: "bandits", superiorActorId: null, roles: ["bandit"], authorityScopes: ["security:encounter"], controller: "deterministic_policy" }], delegations: [] }), routeSecurity: security, maxEventsPerAdvance: 100 });
  const parties = new Map([["bandits", party("bandits", 5)], ["merchant", party("merchant", 0, { food: 8 })], ["escort", party("escort", 4)]]);
  const mutations: EncounterPhysicalMutation[] = [];
  foundation.setEncounterPhysicalPort({ party: (id) => parties.get(id) ?? null, apply: (mutation) => { mutations.push(structuredClone(mutation)); return true; } });
  const command = { commandId: "plan-1", issuerActorId: "bandit_ai", encounterId: "raid-1", routeId: "a_b", attackerPartyId: "bandits", defenderPartyId: "merchant", escortPartyIds: ["escort"], delayDays: 1 };
  assert.equal(foundation.executePlanRouteEncounter(command).accepted, true);
  assert.equal(foundation.executePlanRouteEncounter(command).idempotentReplay, true);
  const saved = JSON.parse(JSON.stringify(foundation.snapshot()));
  const resumed = WorldSimulationFoundation.fromSnapshot(saved); resumed.setEncounterPhysicalPort({ party: (id) => parties.get(id) ?? null, apply: () => true });
  foundation.advanceDays(1); resumed.advanceDays(1);
  assert.deepEqual(resumed.snapshot(), foundation.snapshot());
  assert.equal(mutations.length, 1);
  assert.equal(foundation.snapshot().events.at(-1)?.eventType, "RouteEncounterResolved");
});

test("non-physical encounter, unauthorized task, duplicate task and invalid lifecycle are rejected", () => {
  const security = new RouteSecurity(SNAPSHOT);
  const physical = (id: string) => id === "bandits" ? party(id, 4) : null;
  assert.equal(security.planEncounter({ commandId: "bad", issuerActorId: "ai", encounterId: "bad", routeId: "a_b", attackerPartyId: "bandits", defenderPartyId: "missing", escortPartyIds: [], delayDays: 1 }, 0, true, physical).result.accepted, false);
  const task = { commandId: "task", issuerActorId: "governor", taskId: "patrol-task", kind: "patrol" as const, executorPartyId: "patrol", routeId: "a_b", protectedPartyId: null, labourRequired: 3 };
  assert.equal(security.createTask(task, 0, false, 10).accepted, false);
  assert.equal(security.createTask({ ...task, commandId: "task-2" }, 0, true, 2).accepted, false);
  assert.equal(security.createTask({ ...task, commandId: "task-ok" }, 0, true, 3).accepted, true);
  assert.equal(security.createTask({ ...task, commandId: "duplicate", taskId: "other" }, 0, true, 3).accepted, false);
  assert.equal(security.transitionTask({ commandId: "invalid-transition", issuerActorId: "governor", taskId: "patrol-task", status: "completed", reason: "magic" }, 0, true).accepted, false);
});

test("route controllers use only fresh private memory and deterministic tie breaking", () => {
  const memory = new WorldMemory();
  memory.ingest({ ingestId: "risk-a", ownerId: "merchant", ownerKind: "party", kind: "route_security_observation", observedAtElapsedDays: 0, knownAtElapsedDays: 0, staleAfterDays: 2, provenance: { sourceType: "direct_observation", sourceId: "look", sourceOwnerId: "merchant", nodeId: "a" }, payload: { routeId: "a_b", riskPermille: 200 } });
  memory.ingest({ ingestId: "traffic", ownerId: "bandits", ownerKind: "party", kind: "route_traffic_observation", observedAtElapsedDays: 0, knownAtElapsedDays: 0, staleAfterDays: 2, provenance: { sourceType: "rumor", sourceId: "rumor", sourceOwnerId: "scout", nodeId: "a" }, payload: { routeId: "a_b", trafficValue: 50 } });
  assert.equal(new SecurityAwareRouteController().choose(memory.ownerView("merchant", "party", 1), [{ routeId: "a_b", distanceKm: 10, escorted: false }], 5, { valueOfDayDelay: 1, riskCostPerPermille: 1, maximumRiskPermille: 500 }).routeId, "a_b");
  assert.equal(new SecurityAwareRouteController().choose(memory.ownerView("other", "party", 1), [{ routeId: "a_b", distanceKm: 10, escorted: false }], 5, { valueOfDayDelay: 1, riskCostPerPermille: 1, maximumRiskPermille: 500 }).routeId, null);
  assert.equal(new BanditRouteController().choose(memory.ownerView("bandits", "party", 1), "bandits").routeId, "a_b");
  assert.equal(new BanditRouteController().choose(memory.ownerView("bandits", "party", 3), "bandits").routeId, null);
});

test("canonical WorldSimulation conserves physical cargo, applies casualties, and resumes mid-encounter", () => {
  const graph = loadRegionGraphFile(resolve("data/regions/silesia.json")), travel = loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json"));
  const goodsCatalog = loadGoodsCatalogFile(resolve("data/simulation/goods_catalog.json"));
  const economy = { goodsCatalog, partyCargoConfig: loadPartyCargoConfigFile(resolve("data/simulation/party_cargo.json")), locationEconomyConfig: { profiles: [], profilesByLocationId: new Map() }, locations: [] };
  const clock = new WorldClock();
  const worldSecurity: RouteSecuritySnapshot = { ...SNAPSHOT, routes: [{ ...SNAPSHOT.routes[0]!, routeId: "wroclaw_opole" }], parties: SNAPSHOT.parties.filter((item) => item.partyId === "bandits") };
  const foundation = new WorldSimulationFoundation({ clock, facilities: new Facilities([], []), routeSecurity: new RouteSecurity(worldSecurity), governance: new Governance({ managedEntities: [{ entityId: "bandits", ownerId: "bandits", governorActorId: "bandit_ai" }], governors: [{ actorId: "bandit_ai", principalId: "bandits", superiorActorId: null, roles: ["bandit"], authorityScopes: ["security:encounter"], controller: "deterministic_policy" }], delegations: [] }), maxEventsPerAdvance: 100 });
  const world = new WorldSimulation(graph, travel, [seed("bandits", "bandit_ai", 8, {}), seed("merchant", "merchant_ai", 0, { food: 8 })], economy, clock, foundation);
  assert.equal(world.submitCommand({ commandType: "move_party", command: { party_id: "bandits", from_node_id: "wroclaw", to_node_id: "opole" } }).result.accepted, true);
  assert.equal(world.submitCommand({ commandType: "move_party", command: { party_id: "merchant", from_node_id: "wroclaw", to_node_id: "opole" } }).result.accepted, true);
  assert.equal(world.submitCommand({ commandType: "plan_route_encounter", command: { commandId: "world-plan", issuerActorId: "bandit_ai", encounterId: "world-raid", routeId: "wroclaw_opole", attackerPartyId: "bandits", defenderPartyId: "merchant", escortPartyIds: [], delayDays: 0.1 } }).result.accepted, true);
  const saved = JSON.parse(JSON.stringify(world.snapshot()));
  const resumed = WorldSimulation.fromSnapshot(graph, travel, economy, saved);
  world.advanceDays(0.1); resumed.advanceDays(0.1);
  assert.deepEqual(resumed.snapshot(), world.snapshot());
  const after = world.snapshot().parties;
  assert.equal(after.reduce((sum, item) => sum + (item.cargo.food ?? 0), 0), 8);
  assert.equal(world.snapshot().simulationFoundation?.events.at(-1)?.eventType, "RouteEncounterResolved");
});

function seed(id: string, managerActorId: string, guardCount: number, cargo: Record<string, number>) {
  return { id, displayName: id, managerActorId, nodeId: "wroclaw", composition: { footCount: 2, horseCount: 0, wagonCount: 1, packAnimalCount: 0, guardCount }, knownRouteIds: ["wroclaw_opole"], cargo };
}
