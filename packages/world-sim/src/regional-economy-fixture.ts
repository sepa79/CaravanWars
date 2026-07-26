import { Facilities } from "./facilities.js";
import type { FacilitySeed, ResourceShortagePolicy } from "./facilities.js";
import { Governance } from "./governance.js";
import { AutonomousRegionalEconomyRunner, routeKey } from "./regional-economy.js";
import type { AutonomousRegionalEconomyConfig } from "./regional-economy.js";
import type { RegionGraph } from "./region-graph.js";
import { resourceConsumptionIntent, WorldSimulationFoundation } from "./simulation-foundation.js";
import { TradeHubs } from "./trade-hubs.js";
import type { TradeHubAccountSnapshot, TradeHubSnapshot } from "./trade-hubs.js";
import { WorldClock } from "./world-clock.js";
import { WorldMemory } from "./world-memory.js";
import { WorldSimulation } from "./world-sim.js";
import type { GoodsCatalog, LocationEconomyConfig, PartyCargoConfig } from "./economy-config.js";
import type { PartySeed, PartyTravelConfig, WorldEconomySeed } from "./world-sim.js";

export interface AutonomousRegionalEconomyFixture {
  readonly runner: AutonomousRegionalEconomyRunner;
  readonly world: WorldSimulation;
  readonly config: AutonomousRegionalEconomyConfig;
  readonly economySeed: WorldEconomySeed;
}

const NODES = ["wroclaw", "opole", "raciborz"] as const;
const ROUTES = ["wroclaw_opole", "wroclaw_raciborz", "opole_raciborz"] as const;
const SUPPLY_PARTIES = ["wroclaw_supply", "opole_supply", "raciborz_supply"] as const;
const MERCHANT_PARTIES = ["merchant_a", "merchant_b"] as const;

export function createAutonomousRegionalEconomyFixture(
  graph: RegionGraph,
  travelConfig: PartyTravelConfig,
  seed = 17,
): AutonomousRegionalEconomyFixture {
  const clock = new WorldClock();
  const facilities = createFacilities();
  const governance = createGovernance();
  const tradeHubs = new TradeHubs({ hubs: createHubs() });
  const foundation = new WorldSimulationFoundation({ clock, facilities, governance, tradeHubs, maxEventsPerAdvance: 2_000 });
  for (const facilityId of ["wroclaw_farm", "opole_tannery", "raciborz_workshop"]) foundation.scheduleInitialFacilityTick(facilityId);
  for (const [nodeId, amount] of [["wroclaw", 5], ["opole", 6], ["raciborz", 6]] as const) {
      foundation.schedule(resourceConsumptionIntent(`regional:${nodeId}:food`, 1, {
        hostId: `${nodeId}_host`, resourceId: "food", amount, cohortId: `${nodeId}_residents`,
        recurrenceDays: 1,
        consequences: [{ type: "block" }, { type: "retry", delayDays: 0.5 }, {
          type: "cohort_delta", cohortId: `${nodeId}_residents`, conditionId: "hunger",
          conditionDelta: 1, unrestDelta: 1, workforceDelta: -1, application: "once_per_episode",
        }],
      }));
  }
  const economySeed = createEconomySeed();
  const memory = createInitialMemory();
  const world = new WorldSimulation(graph, travelConfig, createParties(), economySeed, clock, foundation, memory);
  seedStandingDemand(world);
  const config = createRunnerConfig(graph, seed);
  return { runner: new AutonomousRegionalEconomyRunner(config, world), world, config, economySeed };
}

function createFacilities(): Facilities {
  return new Facilities([
    facility("wroclaw_farm", "wroclaw_host", "wroclaw", { food: 12 }, {}, []),
    facility("opole_tannery", "opole_host", "opole", { leather: 6 }, {}, []),
    facility("raciborz_workshop", "raciborz_host", "raciborz", { tools: 3 }, { leather: 2 }, [{ resourceId: "leather", consequences: [{ type: "block" }, { type: "retry", delayDays: 1 }, { type: "none" }] }]),
  ], NODES.map((nodeId) => ({
    hostId: `${nodeId}_host`, inventory: nodeId === "wroclaw" ? { food: 5 } : {},
    storageCaps: { food: 80, leather: 80, tools: 80 },
    cohorts: [{ cohortId: `${nodeId}_residents`, population: 30, availableWorkforce: 12, unrest: 0 }],
  })));
}

function facility(
  facilityId: string,
  hostId: string,
  ownerId: string,
  outputs: Readonly<Record<string, number>>,
  inputs: Readonly<Record<string, number>>,
  shortagePolicies: readonly ResourceShortagePolicy[],
): FacilitySeed {
  return {
    facilityId, facilityType: "regional_fixture", hostId, ownerId, governorActorId: `${ownerId}_governor`,
    recipe: { inputs, energyInputs: {}, maintenanceInputs: {}, outputs, workforceRequired: 4, cycleDays: 1, blockedRetryDays: 1, shortagePolicies },
    active: true, generation: 0, nextEventOrdinal: 0, pendingTickEventId: null, processedEventIds: [],
  };
}

function createGovernance(): Governance {
  const managedEntities = [
    ...NODES.flatMap((nodeId) => [
      { entityId: facilityId(nodeId), ownerId: nodeId, governorActorId: `${nodeId}_governor` },
      { entityId: nodeId, ownerId: nodeId, governorActorId: `${nodeId}_governor` },
      { entityId: `${nodeId}_supply`, ownerId: nodeId, governorActorId: `${nodeId}_governor` },
    ]),
    ...MERCHANT_PARTIES.map((id) => ({ entityId: id, ownerId: id, governorActorId: `${id}_actor` })),
  ];
  const scopes = ["facility:operate", "facility:supply", "supply:delegate", "trade:transfer", "trade:order", "trade:cancel"];
  const governors = [
    ...NODES.map((nodeId) => ({ actorId: `${nodeId}_governor`, principalId: nodeId, superiorActorId: null, roles: ["governor"], authorityScopes: scopes, controller: "deterministic_policy" as const })),
    ...SUPPLY_PARTIES.map((id) => ({ actorId: `${id}_actor`, principalId: id.split("_")[0]!, superiorActorId: `${id.split("_")[0]}_governor`, roles: ["quartermaster"], authorityScopes: scopes, controller: "deterministic_policy" as const })),
    ...MERCHANT_PARTIES.map((id) => ({ actorId: `${id}_actor`, principalId: id, superiorActorId: null, roles: ["merchant"], authorityScopes: scopes, controller: "deterministic_policy" as const })),
  ];
  const delegations = SUPPLY_PARTIES.map((id) => ({
    delegationId: `${id}:delegation`, delegatorActorId: `${id.split("_")[0]}_governor`, delegateActorId: `${id}_actor`,
    authorityScopes: ["facility:supply", "trade:transfer", "trade:order", "trade:cancel"], validFromElapsedDays: 0, validUntilElapsedDays: null,
  }));
  return new Governance({ managedEntities, governors, delegations });
}

function createHubs(): TradeHubSnapshot[] {
  return NODES.map((nodeId) => ({
    hubId: `${nodeId}_hub`, nodeId, ownerId: nodeId, governorActorId: `${nodeId}_governor`, connectedFacilityHostIds: [`${nodeId}_host`],
    storageCaps: { food: 100, leather: 100, tools: 100 }, inventory: {},
    accounts: [account(nodeId, 300), ...SUPPLY_PARTIES.map((id) => account(id, 120)), ...MERCHANT_PARTIES.map((id) => account(id, 120))],
    orders: [], nextPlacementSequence: 0, nextScheduledEventOrdinal: 0, processedCommandIds: [], processedScheduledEventIds: [],
  }));
}

function account(accountEntityId: string, availableCurrency: number): TradeHubAccountSnapshot {
  return { accountEntityId, availableGoods: {}, escrowGoods: {}, availableCurrency, escrowCurrency: 0 };
}

function createParties(): PartySeed[] {
  return [
    ...NODES.map((nodeId) => party(`${nodeId}_supply`, `${nodeId}_supply_actor`, nodeId, 1)),
    party("merchant_a", "merchant_a_actor", "wroclaw", 1),
    party("merchant_b", "merchant_b_actor", "wroclaw", 0, 0),
  ];
}

function party(id: string, managerActorId: string, nodeId: string, wagonCount: number, packAnimalCount = 1): PartySeed {
  return { id, displayName: id, managerActorId, nodeId, composition: { footCount: 2, horseCount: 0, wagonCount, packAnimalCount, guardCount: 0 }, knownRouteIds: [...ROUTES], cargo: {} };
}

function createEconomySeed(): WorldEconomySeed {
  const goods = [
    { id: "food", displayName: "Food", category: "fixture", bulkPerUnit: 1, baseValue: 0, perishable: true, tags: [] },
    { id: "leather", displayName: "Leather", category: "fixture", bulkPerUnit: 2, baseValue: 0, perishable: false, tags: [] },
    { id: "tools", displayName: "Tools", category: "fixture", bulkPerUnit: 3, baseValue: 0, perishable: false, tags: [] },
  ];
  const goodsCatalog: GoodsCatalog = { goods, goodsById: new Map(goods.map((item) => [item.id, item])) };
  const profiles = NODES.map((nodeId) => ({ locationId: `${nodeId}_location`, productionPerDay: {}, consumptionPerDay: {}, storageCaps: { food: 100, leather: 100, tools: 100 } }));
  const locationEconomyConfig: LocationEconomyConfig = { profiles, profilesByLocationId: new Map(profiles.map((item) => [item.locationId, item])) };
  const partyCargoConfig: PartyCargoConfig = { footCapacityBulk: 1, horseCapacityBulk: 0, packAnimalCapacityBulk: 8, wagonCapacityBulk: 20 };
  return { goodsCatalog, locationEconomyConfig, partyCargoConfig, locations: NODES.map((nodeId) => ({ id: `${nodeId}_location`, displayName: nodeId, managerActorId: `${nodeId}_governor`, nodeId, resources: {} })) };
}

function createInitialMemory(): WorldMemory {
  const memory = new WorldMemory();
  for (const partyId of [...SUPPLY_PARTIES, ...MERCHANT_PARTIES]) {
    for (const [index, observation] of [
      { hubId: "wroclaw_hub", nodeId: "wroclaw", market: [{ goodsId: "food", bestAsk: 2, bestBid: null }] },
      { hubId: "opole_hub", nodeId: "opole", market: [{ goodsId: "food", bestAsk: null, bestBid: 5 }, { goodsId: "leather", bestAsk: 3, bestBid: null }] },
      { hubId: "raciborz_hub", nodeId: "raciborz", market: [{ goodsId: "food", bestAsk: null, bestBid: 6 }, { goodsId: "leather", bestAsk: null, bestBid: 5 }] },
    ].entries()) memory.ingest({
      ingestId: `fixture-rumor:${partyId}:${index}`, ownerId: partyId, ownerKind: "party", kind: "trade_hub_observation",
      observedAtElapsedDays: 0, knownAtElapsedDays: index * 0.25, staleAfterDays: 8,
      provenance: { sourceType: "rumor", sourceId: `regional-market-rumor:${index}`, sourceOwnerId: "fixture_courier", nodeId: observation.nodeId },
      payload: observation,
    });
  }
  return memory;
}

function seedStandingDemand(world: WorldSimulation): void {
  for (const [nodeId, price] of [["opole", 5], ["raciborz", 6]] as const) {
    world.submitCommand({ commandType: "place_trade_hub_order", command: {
      commandId: `fixture:${nodeId}:food-demand`, issuerActorId: `${nodeId}_governor`, accountEntityId: nodeId,
      hubId: `${nodeId}_hub`, orderId: `fixture:${nodeId}:food-bid`, side: "buy", goodsId: "food", quantity: 30,
      limitPrice: price, expiresAtElapsedDays: null,
    }});
  }
  world.advanceDays(0.001);
}

function createRunnerConfig(graph: RegionGraph, seed: number): AutonomousRegionalEconomyConfig {
  const distance: Record<string, number> = {};
  for (const edge of graph.edges) distance[routeKey(edge.originNodeId, edge.targetNodeId)] = edge.distanceKm;
  const independentMerchants = seed % 2 === 0
    ? [{ partyId: "merchant_b", goodsId: "food", quantity: 6 }, { partyId: "merchant_a", goodsId: "food", quantity: 6 }]
    : [{ partyId: "merchant_a", goodsId: "food", quantity: 6 }, { partyId: "merchant_b", goodsId: "food", quantity: 6 }];
  return {
    configId: "regional-economy-fixture-v1", seed, observationStaleAfterDays: 8,
    routeDistanceByKey: distance,
    facilityMarkets: [
      market("wroclaw_farm", "wroclaw", "food", 8, 2),
      market("opole_tannery", "opole", "leather", 4, 3),
      market("raciborz_workshop", "raciborz", "tools", 2, 7),
    ],
    governors: NODES.map((nodeId) => ({ governorActorId: `${nodeId}_governor`, facilityId: facilityId(nodeId), facilityHostId: `${nodeId}_host`, destinationNodeId: nodeId, executorPartyIds: [`${nodeId}_supply`], shortagePolicy: { consequenceWeights: { cohort_delta: 100, block: 20, reduced_output: 10, retry: 5, none: 0 } } })),
    merchants: [
      ...SUPPLY_PARTIES.map((partyId) => ({ partyId, goodsId: "food", quantity: 6 })),
      ...independentMerchants,
    ],
  };
}

function market(facilityIdValue: string, nodeId: string, goodsId: string, lotSize: number, askPrice: number) {
  return { facilityId: facilityIdValue, facilityHostId: `${nodeId}_host`, hubId: `${nodeId}_hub`, sellerAccountEntityId: nodeId, issuerActorId: `${nodeId}_governor`, goodsId, lotSize, askPrice };
}

function facilityId(nodeId: string): string {
  return nodeId === "wroclaw" ? "wroclaw_farm" : nodeId === "opole" ? "opole_tannery" : "raciborz_workshop";
}
