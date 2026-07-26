import { Facilities } from "./facilities.js";
import type { FacilityHostSeed, FacilitySeed } from "./facilities.js";
import { Governance } from "./governance.js";
import { PREINDUSTRIAL_FACILITY_PROFILES_V1 } from "./preindustrial-profile-fixtures.js";
import { AutonomousRegionalEconomyRunner, routeKey } from "./regional-economy.js";
import type { AutonomousRegionalEconomyConfig } from "./regional-economy.js";
import type { RegionGraph } from "./region-graph.js";
import { SeasonalRegionalEconomyRunner } from "./seasonal-regional-economy.js";
import { resourceConsumptionIntent, WorldSimulationFoundation } from "./simulation-foundation.js";
import { TradeHubs } from "./trade-hubs.js";
import type { TradeHubAccountSnapshot, TradeHubSnapshot } from "./trade-hubs.js";
import { WorldClock } from "./world-clock.js";
import { WorldMemory } from "./world-memory.js";
import { WorldSimulation } from "./world-sim.js";
import type { PartySeed, PartyTravelConfig, WorldEconomySeed } from "./world-sim.js";
import type { GoodsCatalog, LocationEconomyConfig, PartyCargoConfig } from "./economy-config.js";
import { PopulationDynamics } from "./population-dynamics.js";
import type { PopulationPolicy } from "./population-dynamics.js";
import { RouteSecurity } from "./route-security.js";

export const SEASONAL_ACTIVE_NODES = ["wroclaw", "opole", "raciborz", "legnica", "glogow", "nysa", "olomouc", "prague", "sudety_pass", "odra_crossing"] as const;
const PROFILE_IDS = ["cereal_rye_farm_v1", "hay_meadow_v1", "poultry_yard_v1", "pig_husbandry_v1", "cattle_husbandry_v1", "tannery_v1", "weaver_v1", "mill_v1", "granary_spoilage_v1", "cereal_rye_farm_v1"] as const;
const GOODS = ["seed_grain", "gross_grain", "edible_grain", "straw", "hay", "feed", "eggs", "manure", "meat", "hides", "milk", "traction", "leather", "fibre", "cloth", "flour"] as const;

export interface SeasonalRegionalFixture { readonly runner: SeasonalRegionalEconomyRunner; readonly economySeed: WorldEconomySeed; readonly config: AutonomousRegionalEconomyConfig; readonly world: WorldSimulation }

export function createSeasonalRegionalEconomyFixture(graph: RegionGraph, travelConfig: PartyTravelConfig, seed = 17, merchantCount = 12): SeasonalRegionalFixture {
  if (!Number.isSafeInteger(merchantCount) || merchantCount < 12 || merchantCount > 40) throw new Error("merchantCount must be from 12 to 40.");
  const merchants = [...Array.from({ length: merchantCount }, (_, index) => `seasonal_merchant_${index}`), "security_convoy"];
  const supply = SEASONAL_ACTIVE_NODES.map((node) => `${node}_quartermaster`);
  const facilities = new Facilities(createFacilitySeeds(), createHosts(), {
    definitions: PREINDUSTRIAL_FACILITY_PROFILES_V1,
    instances: SEASONAL_ACTIVE_NODES.map((node, index) => ({
      facilityId: `${node}_seasonal_facility`, hostId: `${node}_host`, profileId: PROFILE_IDS[index]!, visualSkinId: `silesia_${PROFILE_IDS[index]}`,
      processStages: {}, nextEventOrdinal: 0, processedEventIds: [], animalCohorts: animalCohorts(PROFILE_IDS[index]!), winterFeedRequired: PROFILE_IDS[index]!.includes("husbandry") ? 30 : 0,
    })),
  });
  const clock = new WorldClock();
  const governance = createGovernance(merchants, supply);
  const foundation = new WorldSimulationFoundation({ clock, facilities, governance, tradeHubs: new TradeHubs({ hubs: createHubs(merchants, supply) }), population: createPopulation(), routeSecurity: createRouteSecurity(graph, seed), maxEventsPerAdvance: 20_000 });
  foundation.scheduleInitialFacilityProfileProcesses();
  foundation.scheduleInitialPopulationProcesses();
  for (const node of SEASONAL_ACTIVE_NODES) foundation.schedule(resourceConsumptionIntent(`seasonal:${node}:food`, 1, { hostId: `${node}_host`, resourceId: "edible_grain", amount: 1, cohortId: `${node}_residents`, recurrenceDays: 15, consequences: [{ type: "block" }, { type: "retry", delayDays: 5 }, { type: "cohort_delta", cohortId: `${node}_residents`, conditionId: "hunger", conditionDelta: 1, unrestDelta: 1, workforceDelta: -1, application: "once_per_episode" }] }));
  const economySeed = createEconomySeed();
  const world = new WorldSimulation(graph, travelConfig, createParties(graph, merchants, supply), economySeed, clock, foundation, createMemory(merchants, supply));
  seedDemand(world);
  const config = createConfig(graph, seed, merchants);
  return { runner: new SeasonalRegionalEconomyRunner(new AutonomousRegionalEconomyRunner(config, world)), economySeed, config, world };
}

function createFacilitySeeds(): FacilitySeed[] { return SEASONAL_ACTIVE_NODES.map((node) => ({ facilityId: `${node}_seasonal_facility`, facilityType: "profiled", hostId: `${node}_host`, ownerId: node, governorActorId: `${node}_governor`, recipe: { inputs: {}, energyInputs: {}, maintenanceInputs: {}, outputs: {}, workforceRequired: 0, cycleDays: 1, blockedRetryDays: null, shortagePolicies: [] }, active: false, generation: 0, nextEventOrdinal: 0, pendingTickEventId: null, processedEventIds: [] })); }
function createHosts(): FacilityHostSeed[] { return SEASONAL_ACTIVE_NODES.map((node, index) => ({ hostId: `${node}_host`, inventory: { seed_grain: PROFILE_IDS[index] === "cereal_rye_farm_v1" ? 20 : 0, edible_grain: index === 0 ? 50 : 2, hay: PROFILE_IDS[index]!.includes("husbandry") ? 60 : 0, feed: PROFILE_IDS[index] === "poultry_yard_v1" ? 30 : 0, hides: PROFILE_IDS[index] === "tannery_v1" ? 12 : 0, fibre: PROFILE_IDS[index] === "weaver_v1" ? 12 : 0 }, storageCaps: Object.fromEntries(GOODS.map((goods) => [goods, 500])), cohorts: [{ cohortId: `${node}_residents`, population: 40 + index * 3, availableWorkforce: 18, unrest: 0 }] })); }

const POPULATION_POLICY: PopulationPolicy = {
  foodGoodsId: "edible_grain", foodUnitsPerPersonPerSeasonPermille: 80, rationingPermille: 1000, reserveTargetUnits: 2,
  nutritionLossOnShortagePermille: 80, nutritionRecoveryPermille: 40, healthLossFromMalnutritionPermille: 50, healthRecoveryPermille: 30,
  unrestDeltaOnFoodShortage: 0, baselineBirthsPerAdultYearPermille: 30, baselineDeathsPerYearPermille: 15,
  malnutritionDeathsPerYearPermille: 35, maturationPerYearPermille: 80, agingPerYearPermille: 25,
  seasonalDiseaseRiskPermille: { winter: 180, spring: 70, summer: 40, autumn: 90 }, diseaseHealthLossPermille: 100, diseaseDurationSeasons: 2,
  seasonalLabourAvailabilityPermille: { winter: 650, spring: 900, summer: 1000, autumn: 900 },
  labourPriority: ["agriculture", "care", "transport", "industry", "military"],
};

function createPopulation(): PopulationDynamics {
  return new PopulationDynamics({ settlements: SEASONAL_ACTIVE_NODES.map((node, index) => {
    const population = 40 + index * 3;
    return { settlementId: node, nodeId: node, hostId: `${node}_host`, ownerId: node, governorActorId: `${node}_governor`, cohorts: { children: Math.floor(population * 0.3), workingAdults: Math.floor(population * 0.58), elders: population - Math.floor(population * 0.3) - Math.floor(population * 0.58) }, healthPermille: 900, nutritionPermille: 900, unrest: 0, diseaseState: "none" as const, diseaseSeasonsRemaining: 0, allocations: [], policy: POPULATION_POLICY, nextEventOrdinal: 0, pendingSeasonEventId: null, processedEventIds: [], processedCommandIds: [] };
  }), migrations: [] });
}

function createGovernance(merchants: readonly string[], supply: readonly string[]): Governance {
  const entities = [...SEASONAL_ACTIVE_NODES.flatMap((node) => [{ entityId: node, ownerId: node, governorActorId: `${node}_governor` }, { entityId: `${node}_seasonal_facility`, ownerId: node, governorActorId: `${node}_governor` }, { entityId: `${node}_quartermaster`, ownerId: node, governorActorId: `${node}_governor` }]), ...merchants.map((id) => ({ entityId: id, ownerId: id, governorActorId: `${id}_actor` })), { entityId: "wroclaw_raciborz", ownerId: "wroclaw", governorActorId: "wroclaw_governor" }, { entityId: "wroclaw_patrol", ownerId: "wroclaw", governorActorId: "wroclaw_governor" }, { entityId: "wroclaw_escort", ownerId: "wroclaw", governorActorId: "wroclaw_governor" }, { entityId: "bandit_red", ownerId: "bandit_red", governorActorId: "bandit_red_ai" }, { entityId: "bandit_black", ownerId: "bandit_black", governorActorId: "bandit_black_ai" }];
  const scopes = ["facility:operate", "facility:supply", "supply:delegate", "trade:transfer", "trade:order", "trade:cancel", "population:allocate", "population:migrate", "security:task"];
  return new Governance({ managedEntities: entities, governors: [...SEASONAL_ACTIVE_NODES.map((node) => ({ actorId: `${node}_governor`, principalId: node, superiorActorId: null, roles: ["governor"], authorityScopes: scopes, controller: "deterministic_policy" as const })), ...supply.map((id) => ({ actorId: `${id}_actor`, principalId: id.replace("_quartermaster", ""), superiorActorId: `${id.replace("_quartermaster", "")}_governor`, roles: ["quartermaster"], authorityScopes: scopes, controller: "deterministic_policy" as const })), ...merchants.map((id) => ({ actorId: `${id}_actor`, principalId: id, superiorActorId: null, roles: ["merchant"], authorityScopes: scopes, controller: "deterministic_policy" as const })), ...["bandit_red", "bandit_black"].map((id) => ({ actorId: `${id}_ai`, principalId: id, superiorActorId: null, roles: ["bandit"], authorityScopes: ["security:encounter"], controller: "deterministic_policy" as const }))], delegations: supply.map((id) => ({ delegationId: `${id}:delegation`, delegatorActorId: `${id.replace("_quartermaster", "")}_governor`, delegateActorId: `${id}_actor`, authorityScopes: ["facility:supply", "trade:transfer", "trade:order", "trade:cancel"], validFromElapsedDays: 0, validUntilElapsedDays: null })) });
}

function createHubs(merchants: readonly string[], supply: readonly string[]): TradeHubSnapshot[] { return SEASONAL_ACTIVE_NODES.map((node) => ({ hubId: `${node}_hub`, nodeId: node, ownerId: node, governorActorId: `${node}_governor`, connectedFacilityHostIds: [`${node}_host`], storageCaps: Object.fromEntries(GOODS.map((goods) => [goods, 1000])), inventory: node === "wroclaw" ? { edible_grain: 40 } : {}, accounts: [account(node, 2000, node === "wroclaw" ? { edible_grain: 40 } : {}), ...supply.map((id) => account(id, 400)), ...merchants.map((id) => account(id, 400))], orders: [], nextPlacementSequence: 0, nextScheduledEventOrdinal: 0, processedCommandIds: [], processedScheduledEventIds: [] })); }
function account(accountEntityId: string, currency: number, goods: Record<string, number> = {}): TradeHubAccountSnapshot { return { accountEntityId, availableGoods: goods, escrowGoods: {}, availableCurrency: currency, escrowCurrency: 0 }; }

function createParties(graph: RegionGraph, merchants: readonly string[], supply: readonly string[]): PartySeed[] { const routes = graph.edges.map((edge) => edge.id); return [...supply.map((id) => party(id, `${id}_actor`, id.replace("_quartermaster", ""), routes, 1)), ...merchants.map((id, index) => ({ ...party(id, `${id}_actor`, id === "security_convoy" || index % 2 === 0 ? "wroclaw" : "opole", routes, index % 3 === 0 ? 1 : 0), cargo: id === "security_convoy" ? { edible_grain: 8 } : {} })), { ...party("bandit_red", "bandit_red_ai", "wroclaw", routes, 0), composition: { footCount: 4, horseCount: 0, wagonCount: 0, packAnimalCount: 1, guardCount: 5 } }, { ...party("bandit_black", "bandit_black_ai", "wroclaw", routes, 0), composition: { footCount: 4, horseCount: 0, wagonCount: 0, packAnimalCount: 1, guardCount: 4 } }, { ...party("wroclaw_patrol", "wroclaw_governor", "wroclaw", routes, 0), composition: { footCount: 3, horseCount: 0, wagonCount: 0, packAnimalCount: 1, guardCount: 5 } }, { ...party("wroclaw_escort", "wroclaw_governor", "wroclaw", routes, 0), composition: { footCount: 2, horseCount: 0, wagonCount: 0, packAnimalCount: 1, guardCount: 4 } }]; }
function party(id: string, managerActorId: string, nodeId: string, knownRouteIds: readonly string[], wagons: number): PartySeed { return { id, displayName: id, managerActorId, nodeId, composition: { footCount: 2, horseCount: 0, wagonCount: wagons, packAnimalCount: 1, guardCount: 0 }, knownRouteIds, cargo: {} }; }

function createEconomySeed(): WorldEconomySeed { const goods = GOODS.map((id) => ({ id, displayName: id, category: "seasonal_fixture", bulkPerUnit: id === "traction" ? 5 : 1, baseValue: 0, perishable: ["edible_grain", "eggs", "milk", "meat", "hay"].includes(id), tags: [] })); const goodsCatalog: GoodsCatalog = { goods, goodsById: new Map(goods.map((item) => [item.id, item])) }; const profiles = SEASONAL_ACTIVE_NODES.map((node) => ({ locationId: `${node}_location`, productionPerDay: {}, consumptionPerDay: {}, storageCaps: Object.fromEntries(GOODS.map((goodsId) => [goodsId, 1000])) })); const locationEconomyConfig: LocationEconomyConfig = { profiles, profilesByLocationId: new Map(profiles.map((item) => [item.locationId, item])) }; const partyCargoConfig: PartyCargoConfig = { footCapacityBulk: 1, horseCapacityBulk: 0, packAnimalCapacityBulk: 8, wagonCapacityBulk: 20 }; return { goodsCatalog, locationEconomyConfig, partyCargoConfig, locations: SEASONAL_ACTIVE_NODES.map((node) => ({ id: `${node}_location`, displayName: node, managerActorId: `${node}_governor`, nodeId: node, resources: {} })) }; }

function createMemory(merchants: readonly string[], supply: readonly string[]): WorldMemory { const memory = new WorldMemory(); for (const partyId of [...merchants, ...supply]) for (const [index, node] of ["wroclaw", "opole", "legnica", "nysa", "raciborz"].entries()) memory.ingest({ ingestId: `seasonal-rumor:${partyId}:${node}`, ownerId: partyId, ownerKind: "party", kind: "trade_hub_observation", observedAtElapsedDays: 0, knownAtElapsedDays: index * 0.2, staleAfterDays: 180, provenance: { sourceType: "rumor", sourceId: `seasonal-courier:${node}`, sourceOwnerId: "regional_courier", nodeId: node }, payload: { hubId: `${node}_hub`, nodeId: node, market: [{ goodsId: "edible_grain", bestAsk: node === "wroclaw" ? 3 : null, bestBid: node === "wroclaw" ? null : 6 + index }] } }); for (const partyId of ["bandit_red", "bandit_black"]) memory.ingest({ ingestId: `traffic-rumor:${partyId}`, ownerId: partyId, ownerKind: "party", kind: "route_traffic_observation", observedAtElapsedDays: 0, knownAtElapsedDays: 1, staleAfterDays: 180, provenance: { sourceType: "rumor", sourceId: "roadside-informant", sourceOwnerId: "informant", nodeId: "wroclaw" }, payload: { routeId: "wroclaw_raciborz", trafficValue: 100 } }); return memory; }

function createRouteSecurity(graph: RegionGraph, seed: number): RouteSecurity {
  return new RouteSecurity({ seed, routes: graph.edges.map((edge) => ({ routeId: edge.id, riskPermille: edge.id === "wroclaw_raciborz" ? 280 : 80, trafficValue: edge.id === "wroclaw_raciborz" ? 100 : 20, incidentCount: 0, successfulAmbushes: 0, patrolStrength: 0 })), parties: [
    { partyId: "bandit_red", role: "bandit", ownerId: "bandit_red", governorActorId: "bandit_red_ai", conditionPermille: 900, moralePermille: 850, supplies: 200, casualties: 0 },
    { partyId: "bandit_black", role: "bandit", ownerId: "bandit_black", governorActorId: "bandit_black_ai", conditionPermille: 850, moralePermille: 750, supplies: 200, casualties: 0 },
    { partyId: "wroclaw_patrol", role: "patrol", ownerId: "wroclaw", governorActorId: "wroclaw_governor", conditionPermille: 950, moralePermille: 900, supplies: 200, casualties: 0 },
    { partyId: "wroclaw_escort", role: "escort", ownerId: "wroclaw", governorActorId: "wroclaw_governor", conditionPermille: 950, moralePermille: 900, supplies: 200, casualties: 0 },
  ], tasks: [], encounters: [], processedCommandIds: [], processedEventIds: [] });
}

function seedDemand(world: WorldSimulation): void { world.submitCommand({ commandType: "place_trade_hub_order", command: { commandId: "seasonal:wroclaw:supply", issuerActorId: "wroclaw_governor", accountEntityId: "wroclaw", hubId: "wroclaw_hub", orderId: "seasonal:wroclaw:grain-ask", side: "sell", goodsId: "edible_grain", quantity: 40, limitPrice: 3, expiresAtElapsedDays: null } }); for (const [index, node] of SEASONAL_ACTIVE_NODES.entries()) if (node !== "wroclaw") world.submitCommand({ commandType: "place_trade_hub_order", command: { commandId: `seasonal:${node}:demand`, issuerActorId: `${node}_governor`, accountEntityId: node, hubId: `${node}_hub`, orderId: `seasonal:${node}:grain-bid`, side: "buy", goodsId: "edible_grain", quantity: 100, limitPrice: 6 + index, expiresAtElapsedDays: null } }); world.advanceDays(0.001); }

function createConfig(graph: RegionGraph, seed: number, merchants: readonly string[]): AutonomousRegionalEconomyConfig {
  const distance = Object.fromEntries(graph.edges.map((edge) => [routeKey(edge.originNodeId, edge.targetNodeId), edge.distanceKm]));
  const offset = Math.abs(seed) % merchants.length;
  const orderedMerchants = [...merchants.slice(offset), ...merchants.slice(0, offset)];
  return {
    configId: "seasonal-silesia-v1", seed, observationStaleAfterDays: 180, routeDistanceByKey: distance,
    facilityMarkets: SEASONAL_ACTIVE_NODES.map((node, index) => ({ facilityId: `${node}_seasonal_facility`, facilityHostId: `${node}_host`, hubId: `${node}_hub`, sellerAccountEntityId: node, issuerActorId: `${node}_governor`, goodsId: marketGoods(PROFILE_IDS[index]!), lotSize: 8, askPrice: 3 + (index % 5) })),
    governors: SEASONAL_ACTIVE_NODES.map((node) => ({ governorActorId: `${node}_governor`, facilityId: `${node}_seasonal_facility`, facilityHostId: `${node}_host`, destinationNodeId: node, executorPartyIds: [`${node}_quartermaster`], shortagePolicy: { consequenceWeights: { cohort_delta: 100, block: 20, reduced_output: 10, retry: 5, none: 0 } } })),
    merchants: orderedMerchants.map((partyId) => ({ partyId, goodsId: "edible_grain", quantity: 4 })),
    populationGovernors: SEASONAL_ACTIVE_NODES.map((node) => ({ governorActorId: `${node}_governor`, settlementId: node, policy: { seasonalTargets: {
      winter: [{ targetEntityId: `${node}_seasonal_facility`, sector: "industry", workers: 4 }, { targetEntityId: `${node}_quartermaster`, sector: "transport", workers: 3 }, ...(node === "wroclaw" ? [{ targetEntityId: "wroclaw_patrol", sector: "military" as const, workers: 2 }, { targetEntityId: "wroclaw_escort", sector: "military" as const, workers: 2 }] : [])],
      spring: [{ targetEntityId: `${node}_seasonal_facility`, sector: "agriculture", workers: 10 }, { targetEntityId: `${node}_quartermaster`, sector: "transport", workers: 3 }, ...(node === "wroclaw" ? [{ targetEntityId: "wroclaw_patrol", sector: "military" as const, workers: 2 }, { targetEntityId: "wroclaw_escort", sector: "military" as const, workers: 2 }] : [])],
      summer: [{ targetEntityId: `${node}_seasonal_facility`, sector: "agriculture", workers: 16 }, { targetEntityId: `${node}_quartermaster`, sector: "transport", workers: 2 }, ...(node === "wroclaw" ? [{ targetEntityId: "wroclaw_patrol", sector: "military" as const, workers: 2 }, { targetEntityId: "wroclaw_escort", sector: "military" as const, workers: 2 }] : [])],
      autumn: [{ targetEntityId: `${node}_seasonal_facility`, sector: "agriculture", workers: 14 }, { targetEntityId: `${node}_quartermaster`, sector: "transport", workers: 3 }, ...(node === "wroclaw" ? [{ targetEntityId: "wroclaw_patrol", sector: "military" as const, workers: 2 }, { targetEntityId: "wroclaw_escort", sector: "military" as const, workers: 2 }] : [])],
    } } })),
    security: { bandits: ["bandit_red", "bandit_black"].map((partyId) => ({ partyId, issuerActorId: `${partyId}_ai`, routeId: "wroclaw_raciborz", originNodeId: "wroclaw", destinationNodeId: "raciborz", targetPartyIds: orderedMerchants })), responses: [{ governorActorId: "wroclaw_governor", routeId: "wroclaw_raciborz", originNodeId: "wroclaw", destinationNodeId: "raciborz", patrolPartyId: "wroclaw_patrol", escortPartyId: "wroclaw_escort" }] },
  };
}
function marketGoods(profileId: string): string { if (profileId.startsWith("cereal")) return "edible_grain"; if (profileId.startsWith("hay")) return "hay"; if (profileId.startsWith("poultry")) return "eggs"; if (profileId.startsWith("pig")) return "meat"; if (profileId.startsWith("cattle")) return "milk"; if (profileId.startsWith("tannery")) return "leather"; if (profileId.startsWith("weaver")) return "cloth"; if (profileId.startsWith("mill")) return "flour"; return "edible_grain"; }
function animalCohorts(profileId: string) { if (profileId.startsWith("poultry")) return [{ cohortId: "hens", speciesId: "poultry" as const, lifeStage: "adult", count: 20, ageDays: 400, breedingSharePermille: 300, milkToYoungSharePermille: 0, tractionSharePermille: 0 }]; if (profileId.startsWith("pig")) return [{ cohortId: "breeding_sows", speciesId: "pig" as const, lifeStage: "adult", count: 6, ageDays: 500, breedingSharePermille: 700, milkToYoungSharePermille: 0, tractionSharePermille: 0 }]; if (profileId.startsWith("cattle")) return [{ cohortId: "cows", speciesId: "cattle" as const, lifeStage: "adult", count: 8, ageDays: 800, breedingSharePermille: 400, milkToYoungSharePermille: 400, tractionSharePermille: 200 }, { cohortId: "oxen", speciesId: "cattle" as const, lifeStage: "adult", count: 4, ageDays: 900, breedingSharePermille: 0, milkToYoungSharePermille: 0, tractionSharePermille: 900 }]; return []; }
