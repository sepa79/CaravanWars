import { readFileSync } from "node:fs";

import { getEdgeBetween } from "./region-graph.js";
import type {
  RegionGraph,
  RegionGraphEdge,
  RegionGraphNode,
  RegionLandmark,
  RegionRouteWaypoint,
  Vec2,
} from "./region-graph.js";
import { WorldClock } from "./world-clock.js";
import { Facilities } from "./facilities.js";
import { Governance } from "./governance.js";
import { TradeHubs } from "./trade-hubs.js";
import type { ScheduledEventIntent, SerializableValue, WorldClockSnapshot } from "./world-clock.js";
import type {
  FacilityOperationCommand,
  FacilityOperationResult,
  SimulationFoundationDomainSnapshot,
  TransferFacilityGoodsToTradeHubCommand,
} from "./simulation-foundation.js";
import { WorldSimulationFoundation } from "./simulation-foundation.js";
import type {
  CancelTradeHubOrderCommand,
  PlaceTradeHubOrderCommand,
  TradeHubAccountSnapshot,
  TradeHubSnapshot,
  TradeHubCommandResult,
  TransferTradeHubGoodsCommand,
} from "./trade-hubs.js";
import type {
  GoodsCatalog,
  LocationEconomyConfig,
  PartyCargoConfig,
} from "./economy-config.js";
import { WorldMemory } from "./world-memory.js";
import type {
  WorldMemoryEntry,
  WorldMemoryIngest,
  WorldMemoryOwnerKind,
  WorldMemoryOwnerView,
  WorldMemorySnapshot,
} from "./world-memory.js";
import type { AssignSupplyTaskCommand, GovernorSupplyAffordance } from "./governor-controller.js";
import { PopulationDynamics } from "./population-dynamics.js";
import type { AllocateLabourCommand, PopulationCommandResult, StartMigrationCommand } from "./population-dynamics.js";
import { RouteSecurity } from "./route-security.js";
import type { CreateSecurityTaskCommand, EncounterPartyView, EncounterPhysicalMutation, PlanRouteEncounterCommand, RouteEncounterEvent, SecurityCommandResult, TransitionSecurityTaskCommand } from "./route-security.js";
import { ContinuousSpace, SPATIAL_SEARCH_DUE, SPATIAL_TRAVEL_DUE, buildNavigationKnowledgeGraph, detectionSucceeds, deterministicSearchPath, distance as spatialDistance, distanceToPolyline, navigationItem, pointAlongPolyline, polylineDistance, spatialSpeedKmPerDay, terrainAt } from "./continuous-space.js";
import type { ObserveSurroundingsCommand, ReportNavigationKnowledgeCommand, SearchAreaCommand, SpatialCommandResult, SpatialRuntimeSnapshot, SpatialSearchPlan, SpatialTravelCommand, SpatialTravelPlan } from "./continuous-space.js";
import { CaravanExpeditions } from "./caravan-expedition.js";
import type { AbandonCaravanContractCommand, AcceptCaravanContractCommand, CaravanExpeditionSnapshot, DeliverCaravanContractCommand, EncounterMutationPlan, ExpeditionCommandResult, ExpeditionPhysicalPort, OfferCaravanContractCommand, PickupCaravanContractCommand, PlanExpeditionEncounterCommand, ResolveExpeditionEncounterCommand, RestExpeditionPartyCommand } from "./caravan-expedition.js";

export const PARTY_MOVEMENT_COMPONENT = "party_movement";
export const PARTY_MOVEMENT_TICK_DUE = "PartyMovementTickEvent";

export interface DeliverSupplyTaskCommand {
  readonly commandId: string;
  readonly issuerActorId: string;
  readonly taskId: string;
  readonly executorPartyId: string;
  readonly facilityId: string;
  readonly facilityHostId: string;
  readonly goodsId: string;
  readonly amount: number;
}

export interface ReportSupplyTaskCommand {
  readonly commandId: string;
  readonly issuerActorId: string;
  readonly taskId: string;
  readonly executorPartyId: string;
  readonly recipientActorId: string;
  readonly facilityId: string;
}

export type SupplyCommandResult = { readonly accepted: true; readonly idempotentReplay: boolean } | {
  readonly accepted: false;
  readonly errorCode: "NOT_AUTHORIZED" | "PARTY_NOT_FOUND" | "PARTY_BUSY" | "LOCATION_MISMATCH" | "INSUFFICIENT_GOODS" | "STORAGE_EXCEEDED" | "TASK_NOT_FOUND" | "MEMORY_CONFLICT";
  readonly message: string;
};

export interface PartyTravelConfig {
  readonly movementTickDays: number;
  readonly baseSpeedKmPerDay: number;
  readonly horseSpeedBonusKmPerDay: number;
  readonly wagonSpeedPenaltyKmPerDay: number;
  readonly minimumSpeedKmPerDay: number;
}

export interface PartyComposition {
  readonly footCount: number;
  readonly horseCount: number;
  readonly wagonCount: number;
  readonly packAnimalCount: number;
  readonly guardCount: number;
}

export interface PartySeed {
  readonly id: string;
  readonly displayName: string;
  readonly managerActorId: string;
  readonly nodeId: string;
  readonly composition: PartyComposition;
  readonly knownRouteIds: readonly string[];
  readonly cargo: Readonly<Record<string, number>>;
}

export interface LocationSeed {
  readonly id: string;
  readonly displayName: string;
  readonly managerActorId: string;
  readonly nodeId: string;
  readonly resources: Readonly<Record<string, number>>;
}

export interface WorldEconomySeed {
  readonly goodsCatalog: GoodsCatalog;
  readonly partyCargoConfig: PartyCargoConfig;
  readonly locationEconomyConfig: LocationEconomyConfig;
  readonly locations: readonly LocationSeed[];
}

export interface MovePartyCommand {
  readonly party_id: string;
  readonly from_node_id: string;
  readonly to_node_id: string;
}

export type MovePartyErrorCode =
  | "PARTY_NOT_FOUND"
  | "PARTY_BUSY"
  | "ORIGIN_MISMATCH"
  | "NODE_NOT_FOUND"
  | "ROUTE_NOT_FOUND"
  | "ROUTE_UNKNOWN"
  | "SCHEDULING_FAILED";

export type CommandResult =
  | { readonly accepted: true }
  | {
      readonly accepted: false;
      readonly errorCode: MovePartyErrorCode;
      readonly message: string;
    };

export interface TransferGoodsCommand {
  readonly party_id: string;
  readonly location_id: string;
  readonly goods_id: string;
  readonly amount: number;
  readonly direction: "withdraw_from_location" | "deposit_to_location";
}

export type TransferGoodsErrorCode =
  | "ECONOMY_NOT_CONFIGURED"
  | "PARTY_NOT_FOUND"
  | "LOCATION_NOT_FOUND"
  | "GOODS_NOT_FOUND"
  | "INVALID_AMOUNT"
  | "PARTY_BUSY"
  | "LOCATION_MISMATCH"
  | "INSUFFICIENT_LOCATION_GOODS"
  | "INSUFFICIENT_PARTY_GOODS"
  | "PARTY_CAPACITY_EXCEEDED"
  | "LOCATION_STORAGE_EXCEEDED";

export type TransferGoodsResult =
  | { readonly accepted: true }
  | {
      readonly accepted: false;
      readonly errorCode: TransferGoodsErrorCode;
      readonly message: string;
    };

export interface TransferPartyGoodsWithTradeHubCommand extends TransferTradeHubGoodsCommand {
  readonly partyId: string;
}

export interface RelocateSpatialObjectCommand { readonly commandId: string; readonly issuerActorId: string; readonly worldObjectId: string; readonly position: Vec2 }

export type WorldCommandEnvelope =
  | { readonly commandType: "move_party"; readonly command: MovePartyCommand }
  | { readonly commandType: "transfer_goods"; readonly command: TransferGoodsCommand }
  | { readonly commandType: "set_facility_operation"; readonly command: FacilityOperationCommand }
  | {
      readonly commandType: "trade_hub_transfer_party_goods";
      readonly command: TransferPartyGoodsWithTradeHubCommand;
    }
  | {
      readonly commandType: "trade_hub_transfer_facility_goods";
      readonly command: TransferFacilityGoodsToTradeHubCommand;
    }
  | { readonly commandType: "place_trade_hub_order"; readonly command: PlaceTradeHubOrderCommand }
  | { readonly commandType: "cancel_trade_hub_order"; readonly command: CancelTradeHubOrderCommand }
  | { readonly commandType: "assign_supply_task"; readonly command: AssignSupplyTaskCommand }
  | { readonly commandType: "deliver_supply_task"; readonly command: DeliverSupplyTaskCommand }
  | { readonly commandType: "report_supply_task"; readonly command: ReportSupplyTaskCommand }
  | { readonly commandType: "allocate_labour"; readonly command: AllocateLabourCommand }
  | { readonly commandType: "start_population_migration"; readonly command: StartMigrationCommand }
  | { readonly commandType: "create_security_task"; readonly command: CreateSecurityTaskCommand }
  | { readonly commandType: "transition_security_task"; readonly command: TransitionSecurityTaskCommand }
  | { readonly commandType: "plan_route_encounter"; readonly command: PlanRouteEncounterCommand }
  | { readonly commandType: "spatial_travel"; readonly command: SpatialTravelCommand }
  | { readonly commandType: "search_area"; readonly command: SearchAreaCommand }
  | { readonly commandType: "observe_surroundings"; readonly command: ObserveSurroundingsCommand }
  | { readonly commandType: "report_navigation_knowledge"; readonly command: ReportNavigationKnowledgeCommand }
  | { readonly commandType: "relocate_spatial_object"; readonly command: RelocateSpatialObjectCommand }
  | { readonly commandType: "accept_caravan_contract"; readonly command: AcceptCaravanContractCommand }
  | { readonly commandType: "offer_caravan_contract"; readonly command: OfferCaravanContractCommand }
  | { readonly commandType: "pickup_caravan_contract"; readonly command: PickupCaravanContractCommand }
  | { readonly commandType: "deliver_caravan_contract"; readonly command: DeliverCaravanContractCommand }
  | { readonly commandType: "abandon_caravan_contract"; readonly command: AbandonCaravanContractCommand }
  | { readonly commandType: "plan_expedition_encounter"; readonly command: PlanExpeditionEncounterCommand }
  | { readonly commandType: "resolve_expedition_encounter"; readonly command: ResolveExpeditionEncounterCommand }
  | { readonly commandType: "rest_expedition_party"; readonly command: RestExpeditionPartyCommand };

export type WorldCommandSubmissionResult =
  | { readonly commandType: "move_party"; readonly result: CommandResult }
  | { readonly commandType: "transfer_goods"; readonly result: TransferGoodsResult }
  | { readonly commandType: "set_facility_operation"; readonly result: FacilityOperationResult }
  | { readonly commandType: "trade_hub_transfer_party_goods"; readonly result: TradeHubCommandResult }
  | { readonly commandType: "trade_hub_transfer_facility_goods"; readonly result: TradeHubCommandResult }
  | { readonly commandType: "place_trade_hub_order"; readonly result: TradeHubCommandResult }
  | { readonly commandType: "cancel_trade_hub_order"; readonly result: TradeHubCommandResult }
  | { readonly commandType: "assign_supply_task"; readonly result: SupplyCommandResult }
  | { readonly commandType: "deliver_supply_task"; readonly result: SupplyCommandResult }
  | { readonly commandType: "report_supply_task"; readonly result: SupplyCommandResult }
  | { readonly commandType: "allocate_labour"; readonly result: PopulationCommandResult }
  | { readonly commandType: "start_population_migration"; readonly result: PopulationCommandResult }
  | { readonly commandType: "create_security_task"; readonly result: SecurityCommandResult }
  | { readonly commandType: "transition_security_task"; readonly result: SecurityCommandResult }
  | { readonly commandType: "plan_route_encounter"; readonly result: SecurityCommandResult }
  | { readonly commandType: "spatial_travel"; readonly result: SpatialCommandResult }
  | { readonly commandType: "search_area"; readonly result: SpatialCommandResult }
  | { readonly commandType: "observe_surroundings"; readonly result: SpatialCommandResult }
  | { readonly commandType: "report_navigation_knowledge"; readonly result: SpatialCommandResult }
  | { readonly commandType: "relocate_spatial_object"; readonly result: SpatialCommandResult }
  | { readonly commandType: "offer_caravan_contract"; readonly result: ExpeditionCommandResult }
  | { readonly commandType: "accept_caravan_contract"; readonly result: ExpeditionCommandResult }
  | { readonly commandType: "pickup_caravan_contract"; readonly result: ExpeditionCommandResult }
  | { readonly commandType: "deliver_caravan_contract"; readonly result: ExpeditionCommandResult }
  | { readonly commandType: "abandon_caravan_contract"; readonly result: ExpeditionCommandResult }
  | { readonly commandType: "plan_expedition_encounter"; readonly result: ExpeditionCommandResult }
  | { readonly commandType: "resolve_expedition_encounter"; readonly result: ExpeditionCommandResult }
  | { readonly commandType: "rest_expedition_party"; readonly result: ExpeditionCommandResult };

export interface PartyTravelSnapshot {
  readonly edgeId: string;
  readonly originNodeId: string;
  readonly destinationNodeId: string;
  readonly distanceKm: number;
  readonly progressKm: number;
  readonly speedKmPerDay: number;
}

export interface PartyMovementOrderSnapshot {
  readonly targetNodeId: string;
  readonly generation: number;
}

export interface PartySpatialTravelSnapshot {
  readonly journeyId: string;
  readonly kind: "offroad" | "search";
  readonly origin: Vec2;
  readonly destination: Vec2;
  readonly path: readonly Vec2[];
  readonly distanceKm: number;
  readonly progressKm: number;
  readonly speedKmPerDay: number;
  readonly targetWorldObjectId: string | null;
}

export interface PartySnapshot {
  readonly id: string;
  readonly displayName: string;
  readonly managerActorId: string;
  readonly seedNodeId: string;
  readonly status: "idle" | "traveling";
  readonly currentNodeId: string | null;
  readonly position: Vec2;
  composition: PartyComposition;
  readonly knownRouteIds: readonly string[];
  readonly observedWaypointIds: readonly string[];
  readonly observedLandmarkIds: readonly string[];
  readonly cargo: Readonly<Record<string, number>>;
  readonly cargoCapacityBulk: number | null;
  readonly cargoUsedBulk: number | null;
  readonly travel: PartyTravelSnapshot | null;
  readonly spatialTravel: PartySpatialTravelSnapshot | null;
  readonly movementOrder: PartyMovementOrderSnapshot | null;
  readonly movementGeneration: number;
  readonly nextMovementTickOrdinal: number;
  readonly pendingMovementTickEventId: string | null;
}

export interface LocationSnapshot {
  readonly id: string;
  readonly displayName: string;
  readonly managerActorId: string;
  readonly nodeId: string;
  readonly resources: Readonly<Record<string, number>>;
}

export interface WorldSnapshot {
  readonly clock: WorldClockSnapshot;
  readonly simulationFoundation: SimulationFoundationDomainSnapshot | null;
  readonly parties: readonly PartySnapshot[];
  readonly locations: readonly LocationSnapshot[];
  readonly runtimeEvents: readonly WorldSimulationEvent[];
  readonly worldMemory: WorldMemorySnapshot;
  readonly shortageObservationCursors: Readonly<Record<string, number>>;
  readonly continuousSpace: SpatialRuntimeSnapshot;
  readonly caravanExpedition: CaravanExpeditionSnapshot | null;
}

export interface ObserveLocalTradeContextRequest {
  readonly observationId: string;
  readonly observerPartyId: string;
  readonly ownerId: string;
  readonly ownerKind: Extract<WorldMemoryOwnerKind, "actor" | "party">;
  readonly accountEntityId: string;
  readonly staleAfterDays: number;
}

export type ObserveLocalTradeContextResult =
  | { readonly accepted: true; readonly entries: readonly WorldMemoryEntry[] }
  | {
      readonly accepted: false;
      readonly errorCode: "PARTY_NOT_FOUND" | "PARTY_BUSY" | "OWNER_SCOPE_MISMATCH" | "NO_LOCAL_TRADE_HUB" | "MEMORY_INGEST_CONFLICT";
      readonly message: string;
    };

export interface LocalTradeHubAffordance {
  readonly hubId: string;
  readonly nodeId: string;
  readonly account: TradeHubAccountSnapshot | null;
}

export interface MerchantLocalTradeAffordances {
  readonly party: PartySnapshot;
  readonly issuerActorId: string;
  readonly accountEntityId: string;
  readonly localTradeHubs: readonly LocalTradeHubAffordance[];
}

export interface RouteWaypointObservedEvent {
  readonly eventType: "worldsim_route_waypoint_observed";
  readonly elapsedDays: number;
  readonly ownerPartyId: string;
  readonly edgeId: string;
  readonly originNodeId: string;
  readonly destinationNodeId: string;
  readonly waypointId: string;
  readonly waypointKind: string;
  readonly distanceFromStartKm: number;
  readonly elevationM: number;
  readonly terrainAreaIds: readonly string[];
  readonly landmarkIds: readonly string[];
  readonly landmarkTags: readonly string[];
}

export interface GoodsTransferredEvent {
  readonly eventType: "goods_transferred";
  readonly elapsedDays: number;
  readonly partyId: string;
  readonly managerActorId: string;
  readonly locationId: string;
  readonly locationManagerActorId: string;
  readonly nodeId: string;
  readonly goodsId: string;
  readonly amount: number;
  readonly direction: TransferGoodsCommand["direction"];
  readonly partyCargoAmount: number;
  readonly locationResourceAmount: number;
}

export interface LocationEconomyTickedEvent {
  readonly eventType: "location_economy_ticked";
  readonly elapsedDays: number;
  readonly locationId: string;
  readonly managerActorId: string;
  readonly elapsedFullDays: number;
  readonly resourceChanges: Readonly<Record<string, number>>;
}

export type WorldSimulationEvent =
  | RouteWaypointObservedEvent
  | GoodsTransferredEvent
  | LocationEconomyTickedEvent;

export interface PartyMapRegionNode {
  readonly id: string;
  readonly displayName: string;
  readonly kind: string;
  readonly position: Vec2;
}

export interface PartyMapRegionEdge {
  readonly id: string;
  readonly originNodeId: string;
  readonly targetNodeId: string;
  readonly distanceKm: number;
  readonly kind: string;
  readonly routeWaypoints: readonly RegionRouteWaypoint[];
}

export interface PartyMapRegionSnapshot {
  readonly id: string;
  readonly displayName: string;
  readonly mapBounds: { readonly minimum: Vec2; readonly maximum: Vec2 };
  readonly nodes: readonly PartyMapRegionNode[];
  readonly edges: readonly PartyMapRegionEdge[];
  readonly terrainAreas: readonly never[];
  readonly landmarks: readonly RegionLandmark[];
}

export interface PartyMapSnapshot {
  readonly mode: "party";
  readonly observerPartyId: string;
  readonly region: PartyMapRegionSnapshot;
  readonly snapshot: {
    readonly clock: WorldClockSnapshot;
    readonly parties: readonly [PartySnapshot];
    readonly locations: readonly LocationSnapshot[];
  };
  readonly navigationKnowledge: {
    readonly approximateAreas: readonly { readonly knowledgeId: string; readonly center: Vec2; readonly radiusKm: number; readonly confidencePermille: number; readonly freshness: "fresh" | "stale"; readonly provenanceEntryId: string }[];
    readonly landmarkRelations: readonly { readonly knowledgeId: string; readonly relation: string; readonly confidencePermille: number; readonly freshness: "fresh" | "stale"; readonly provenanceEntryId: string }[];
  };
}

interface IdlePartyState {
  readonly status: "idle";
  readonly nodeId: string | null;
  readonly position: Vec2;
}

interface TravelingPartyState {
  readonly status: "traveling";
  readonly edgeId: string;
  readonly originNodeId: string;
  readonly destinationNodeId: string;
  readonly distanceKm: number;
  speedKmPerDay: number;
  progressKm: number;
}

interface SpatialTravelingPartyState {
  readonly status: "traveling";
  readonly spatial: true;
  readonly journeyId: string;
  readonly kind: "offroad" | "search";
  readonly origin: Vec2;
  readonly destination: Vec2;
  readonly path: readonly Vec2[];
  readonly distanceKm: number;
  readonly speedKmPerDay: number;
  readonly targetWorldObjectId: string | null;
  progressKm: number;
}

type PartyLocationState = IdlePartyState | TravelingPartyState | SpatialTravelingPartyState;

interface PartyRuntimeState {
  readonly id: string;
  readonly displayName: string;
  readonly managerActorId: string;
  readonly seedNodeId: string;
  composition: PartyComposition;
  readonly cargo: Map<string, number>;
  readonly knownRouteIds: ReadonlySet<string>;
  readonly observedWaypointIds: Set<string>;
  readonly observedLandmarkIds: Set<string>;
  location: PartyLocationState;
  movementOrder: PartyMovementOrderSnapshot | null;
  movementGeneration: number;
  nextMovementTickOrdinal: number;
  pendingMovementTickEventId: string | null;
}

interface LocationRuntimeState {
  readonly id: string;
  readonly displayName: string;
  readonly managerActorId: string;
  readonly nodeId: string;
  readonly resources: Map<string, number>;
}

interface AuthoredPartyTravelConfig {
  readonly movement_tick_hours?: unknown;
  readonly base_speed_km_per_day?: unknown;
  readonly horse_speed_bonus_km_per_day?: unknown;
  readonly wagon_speed_penalty_km_per_day?: unknown;
  readonly minimum_speed_km_per_day?: unknown;
}

export class PartyTravelConfigValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "PartyTravelConfigValidationError";
  }
}

export class WorldSimulationConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "WorldSimulationConfigurationError";
  }
}

export class WorldSimulationQueryError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "WorldSimulationQueryError";
  }
}

export function loadPartyTravelConfigFile(filePath: string): PartyTravelConfig {
  const fileText = readFileSync(filePath, "utf8");
  let parsed: unknown;
  try {
    parsed = JSON.parse(fileText) as unknown;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    throw new PartyTravelConfigValidationError(`Party travel config JSON is invalid: ${message}`);
  }

  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new PartyTravelConfigValidationError("Party travel config must be an object.");
  }
  const source = parsed as AuthoredPartyTravelConfig;
  return {
    movementTickDays: requirePositiveNumber(source.movement_tick_hours, "movement_tick_hours") / 24,
    baseSpeedKmPerDay: requirePositiveNumber(source.base_speed_km_per_day, "base_speed_km_per_day"),
    horseSpeedBonusKmPerDay: requireNonNegativeNumber(
      source.horse_speed_bonus_km_per_day,
      "horse_speed_bonus_km_per_day",
    ),
    wagonSpeedPenaltyKmPerDay: requireNonNegativeNumber(
      source.wagon_speed_penalty_km_per_day,
      "wagon_speed_penalty_km_per_day",
    ),
    minimumSpeedKmPerDay: requirePositiveNumber(
      source.minimum_speed_km_per_day,
      "minimum_speed_km_per_day",
    ),
  };
}

export function calculatePartyTravelSpeed(
  composition: PartyComposition,
  config: PartyTravelConfig,
): number {
  const calculated = config.baseSpeedKmPerDay
    + composition.horseCount * config.horseSpeedBonusKmPerDay
    - composition.wagonCount * config.wagonSpeedPenaltyKmPerDay;
  return Math.max(config.minimumSpeedKmPerDay, calculated);
}

export class WorldSimulation {
  readonly #graph: RegionGraph;
  readonly #travelConfig: PartyTravelConfig;
  readonly #clock: WorldClock;
  readonly #partySeeds: readonly PartySeed[];
  readonly #economySeed: WorldEconomySeed | null;
  readonly #simulationFoundation: WorldSimulationFoundation | null;
  #caravanExpedition: CaravanExpeditions | null;
  readonly #initialCaravanExpeditionSnapshot: CaravanExpeditionSnapshot | null;
  #continuousSpace: ContinuousSpace;
  readonly #initialContinuousSpaceSnapshot: SpatialRuntimeSnapshot;
  #worldMemory: WorldMemory;
  readonly #initialWorldMemorySnapshot: WorldMemorySnapshot;
  #parties: Map<string, PartyRuntimeState>;
  #locations: Map<string, LocationRuntimeState>;
  #runtimeEvents: WorldSimulationEvent[] = [];
  readonly #shortageObservationCursors = new Map<string, number>();

  constructor(
    graph: RegionGraph,
    travelConfig: PartyTravelConfig,
    partySeeds: readonly PartySeed[],
    economySeed: WorldEconomySeed | null,
    clock = new WorldClock(),
    simulationFoundation: WorldSimulationFoundation | null = null,
    worldMemory = new WorldMemory(),
    continuousSpace = ContinuousSpace.create(defaultSpatialConfig()),
    caravanExpedition: CaravanExpeditions | null = null,
  ) {
    this.#graph = graph;
    this.#travelConfig = travelConfig;
    this.#clock = clock;
    if (simulationFoundation !== null && !simulationFoundation.usesClock(clock)) {
      throw new WorldSimulationConfigurationError(
        "Simulation foundation and WorldSimulation must share the canonical WorldClock instance.",
      );
    }
    this.#simulationFoundation = simulationFoundation;
    this.#simulationFoundation?.captureResetState();
    this.#partySeeds = partySeeds.map(copyPartySeed);
    this.#economySeed = economySeed === null ? null : copyWorldEconomySeed(economySeed);
    this.#parties = createParties(graph, this.#partySeeds, this.#economySeed?.goodsCatalog ?? null);
    this.#locations = createLocations(graph, this.#economySeed);
    for (const route of this.#simulationFoundation?.routeSecuritySnapshot()?.routes ?? []) if (!graph.edgesById.has(route.routeId)) throw new WorldSimulationConfigurationError(`RouteSecurity route ${route.routeId} is absent from the canonical graph.`);
    for (const securityParty of this.#simulationFoundation?.routeSecuritySnapshot()?.parties ?? []) if (!this.#parties.has(securityParty.partyId)) throw new WorldSimulationConfigurationError(`RouteSecurity party ${securityParty.partyId} is not a physical WorldSimulation Party.`);
    validateInitialCargoCapacities(this.#parties, this.#economySeed);
    this.#worldMemory = new WorldMemory(worldMemory.snapshot());
    this.#continuousSpace = new ContinuousSpace(continuousSpace.snapshot());
    this.#caravanExpedition = caravanExpedition === null ? null : new CaravanExpeditions(caravanExpedition.snapshot());
    this.#initialCaravanExpeditionSnapshot = this.#caravanExpedition?.snapshot() ?? null;
    this.#initialContinuousSpaceSnapshot = this.#continuousSpace.snapshot();
    this.#seedNavigationKnowledge();
    this.#initialWorldMemorySnapshot = this.#worldMemory.snapshot();
    this.#bindEncounterPort();
    this.#simulationFoundation?.setSpatialEventHandler((intent, elapsedDays) => this.#handleSpatialEvent(intent, elapsedDays));
    this.#simulationFoundation?.setMovementEventHandler((intent, elapsedDays) => this.#handleMovementTick(intent, elapsedDays));
    this.#simulationFoundation?.setExpeditionEventHandler((intent, elapsedDays) => this.#caravanExpedition?.handleEvent(intent, elapsedDays, this.#expeditionPort()));
  }

  static fromSnapshot(
    graph: RegionGraph,
    travelConfig: PartyTravelConfig,
    economySeed: WorldEconomySeed | null,
    snapshot: WorldSnapshot,
  ): WorldSimulation {
    const clock = WorldClock.fromSnapshot(snapshot.clock);
    const domain = snapshot.simulationFoundation;
    const foundation = domain === null ? null : new WorldSimulationFoundation({
      clock,
      governance: new Governance(domain.governance),
      facilities: new Facilities(domain.facilities.facilities, domain.facilities.hosts, domain.facilities.profileRuntime ?? null),
      tradeHubs: domain.tradeHubs === null ? null : new TradeHubs(domain.tradeHubs),
      population: domain.population === undefined || domain.population === null ? null : new PopulationDynamics(domain.population),
      routeSecurity: domain.routeSecurity === undefined || domain.routeSecurity === null ? null : new RouteSecurity(domain.routeSecurity),
      maxEventsPerAdvance: domain.maxEventsPerAdvance,
      events: domain.events,
    });
    const seeds = snapshot.parties.map((party) => ({
      id: party.id,
      displayName: party.displayName,
      managerActorId: party.managerActorId,
      nodeId: party.seedNodeId,
      composition: party.composition,
      knownRouteIds: party.knownRouteIds,
      cargo: party.cargo,
    }));
    const simulation = new WorldSimulation(
      graph, travelConfig, seeds, economySeed, clock, foundation, new WorldMemory(snapshot.worldMemory), new ContinuousSpace(snapshot.continuousSpace), snapshot.caravanExpedition === null ? null : new CaravanExpeditions(snapshot.caravanExpedition),
    );
    simulation.#restoreRuntimeSnapshot(snapshot);
    return simulation;
  }

  submitCommand(
    envelope: Extract<WorldCommandEnvelope, { readonly commandType: "move_party" }>,
  ): Extract<WorldCommandSubmissionResult, { readonly commandType: "move_party" }>;
  submitCommand(
    envelope: Extract<WorldCommandEnvelope, { readonly commandType: "transfer_goods" }>,
  ): Extract<WorldCommandSubmissionResult, { readonly commandType: "transfer_goods" }>;
  submitCommand(
    envelope: Extract<WorldCommandEnvelope, { readonly commandType: "set_facility_operation" }>,
  ): Extract<WorldCommandSubmissionResult, { readonly commandType: "set_facility_operation" }>;
  submitCommand(
    envelope: Extract<WorldCommandEnvelope, { readonly commandType: "trade_hub_transfer_party_goods" }>,
  ): Extract<WorldCommandSubmissionResult, { readonly commandType: "trade_hub_transfer_party_goods" }>;
  submitCommand(
    envelope: Extract<WorldCommandEnvelope, { readonly commandType: "trade_hub_transfer_facility_goods" }>,
  ): Extract<WorldCommandSubmissionResult, { readonly commandType: "trade_hub_transfer_facility_goods" }>;
  submitCommand(
    envelope: Extract<WorldCommandEnvelope, { readonly commandType: "place_trade_hub_order" }>,
  ): Extract<WorldCommandSubmissionResult, { readonly commandType: "place_trade_hub_order" }>;
  submitCommand(
    envelope: Extract<WorldCommandEnvelope, { readonly commandType: "cancel_trade_hub_order" }>,
  ): Extract<WorldCommandSubmissionResult, { readonly commandType: "cancel_trade_hub_order" }>;
  submitCommand(
    envelope: Extract<WorldCommandEnvelope, { readonly commandType: "offer_caravan_contract" }>,
  ): Extract<WorldCommandSubmissionResult, { readonly commandType: "offer_caravan_contract" }>;
  submitCommand(envelope: WorldCommandEnvelope): WorldCommandSubmissionResult;
  submitCommand(envelope: WorldCommandEnvelope): WorldCommandSubmissionResult {
    if (envelope.commandType === "offer_caravan_contract") return { commandType: envelope.commandType, result: this.#requireExpedition().offer(envelope.command, this.#clock.elapsedDays, this.#expeditionPort()) };
    if (envelope.commandType === "accept_caravan_contract") return { commandType: envelope.commandType, result: this.#acceptCaravanContract(envelope.command) };
    if (envelope.commandType === "pickup_caravan_contract") return { commandType: envelope.commandType, result: this.#requireExpedition().pickup(envelope.command, this.#clock.elapsedDays, this.#expeditionPort()) };
    if (envelope.commandType === "deliver_caravan_contract") return { commandType: envelope.commandType, result: this.#deliverCaravanContract(envelope.command) };
    if (envelope.commandType === "abandon_caravan_contract") return { commandType: envelope.commandType, result: this.#requireExpedition().abandon(envelope.command, this.#clock.elapsedDays, this.#expeditionPort()) };
    if (envelope.commandType === "plan_expedition_encounter") return { commandType: envelope.commandType, result: this.#planExpeditionEncounter(envelope.command) };
    if (envelope.commandType === "resolve_expedition_encounter") return { commandType: envelope.commandType, result: this.#resolveExpeditionEncounter(envelope.command) };
    if (envelope.commandType === "rest_expedition_party") return { commandType: envelope.commandType, result: this.#requireExpedition().rest(envelope.command, this.#clock.elapsedDays, this.#expeditionPort()) };
    if (envelope.commandType === "spatial_travel") return { commandType: envelope.commandType, result: this.#startSpatialTravel(envelope.command) };
    if (envelope.commandType === "search_area") return { commandType: envelope.commandType, result: this.#startSpatialSearch(envelope.command) };
    if (envelope.commandType === "observe_surroundings") return { commandType: envelope.commandType, result: this.#observeSurroundings(envelope.command) };
    if (envelope.commandType === "report_navigation_knowledge") return { commandType: envelope.commandType, result: this.#reportNavigationKnowledge(envelope.command) };
    if (envelope.commandType === "relocate_spatial_object") return { commandType: envelope.commandType, result: this.#relocateSpatialObject(envelope.command) };
    if (envelope.commandType === "create_security_task") return { commandType: envelope.commandType, result: this.#simulationFoundation?.executeCreateSecurityTask(envelope.command) ?? securityUnavailable() };
    if (envelope.commandType === "transition_security_task") return { commandType: envelope.commandType, result: this.#simulationFoundation?.executeTransitionSecurityTask(envelope.command) ?? securityUnavailable() };
    if (envelope.commandType === "plan_route_encounter") {
      if (!this.#graph.edgesById.has(envelope.command.routeId)) return { commandType: envelope.commandType, result: securityRejected("INVALID_COMMAND", "Encounter route is absent from the region graph.") };
      return { commandType: envelope.commandType, result: this.#simulationFoundation?.executePlanRouteEncounter(envelope.command) ?? securityUnavailable() };
    }
    if (envelope.commandType === "allocate_labour") {
      return { commandType: envelope.commandType, result: this.#simulationFoundation?.executeAllocateLabour(envelope.command, this.#caravanExpedition?.reservedLabour(envelope.command.settlementId) ?? 0) ?? populationUnavailable() };
    }
    if (envelope.commandType === "start_population_migration") {
      const foundation = this.#simulationFoundation;
      if (foundation === null) return { commandType: envelope.commandType, result: populationUnavailable() };
      const origin = foundation.populationSettlement(envelope.command.originSettlementId), destination = foundation.populationSettlement(envelope.command.destinationSettlementId);
      const edge = this.#graph.edgesById.get(envelope.command.routeId);
      if (origin === null || destination === null || edge === undefined || !((edge.originNodeId === origin.nodeId && edge.targetNodeId === destination.nodeId) || (edge.targetNodeId === origin.nodeId && edge.originNodeId === destination.nodeId))) {
        return { commandType: envelope.commandType, result: { accepted: false, idempotentReplay: false, errorCode: "INVALID_COMMAND", message: "Migration route must physically connect the origin and destination settlements." } };
      }
      return { commandType: envelope.commandType, result: foundation.executeStartMigration(envelope.command) };
    }
    if (envelope.commandType === "assign_supply_task") {
      return { commandType: envelope.commandType, result: this.#assignSupplyTask(envelope.command) };
    }
    if (envelope.commandType === "deliver_supply_task") {
      return { commandType: envelope.commandType, result: this.#deliverSupplyTask(envelope.command) };
    }
    if (envelope.commandType === "report_supply_task") {
      return { commandType: envelope.commandType, result: this.#reportSupplyTask(envelope.command) };
    }
    if (envelope.commandType === "move_party") {
      return { commandType: "move_party", result: this.#executeMoveParty(envelope.command) };
    }
    if (envelope.commandType === "transfer_goods") {
      return { commandType: "transfer_goods", result: this.#executeTransferGoods(envelope.command) };
    }
    if (envelope.commandType === "set_facility_operation") {
      return {
        commandType: "set_facility_operation",
        result: this.#simulationFoundation?.executeFacilityOperation(envelope.command) ?? {
          accepted: false,
          errorCode: "FOUNDATION_NOT_CONFIGURED",
          message: "World simulation foundation is not configured.",
        },
      };
    }
    if (envelope.commandType === "trade_hub_transfer_party_goods") {
      const result = this.#executePartyTradeHubTransfer(envelope.command);
      this.#rememberTradeCommandResult(envelope.command, result);
      return {
        commandType: envelope.commandType,
        result,
      };
    }
    if (envelope.commandType === "trade_hub_transfer_facility_goods") {
      const result = this.#simulationFoundation?.executeFacilityTradeHubTransfer(envelope.command)
        ?? tradeFoundationNotConfigured();
      this.#rememberTradeCommandResult(envelope.command, result);
      return {
        commandType: envelope.commandType,
        result,
      };
    }
    if (envelope.commandType === "place_trade_hub_order") {
      const result = this.#simulationFoundation?.executePlaceTradeHubOrder(envelope.command)
        ?? tradeFoundationNotConfigured();
      this.#rememberTradeCommandResult(envelope.command, result);
      return {
        commandType: envelope.commandType,
        result,
      };
    }
    const result = this.#simulationFoundation?.executeCancelTradeHubOrder(envelope.command)
      ?? tradeFoundationNotConfigured();
    this.#rememberTradeCommandResult(envelope.command, result);
    return {
      commandType: envelope.commandType,
      result,
    };
  }

  partySnapshot(partyId: string): PartySnapshot {
    const party = this.#parties.get(partyId);
    if (party === undefined) throw new WorldSimulationQueryError(`Party ${partyId} does not exist.`);
    return createPartySnapshot(this.#graph, party, this.#economySeed);
  }

  elapsedDays(): number {
    return this.#clock.elapsedDays;
  }

  caravanExpeditionSnapshot(): CaravanExpeditionSnapshot | null { return this.#caravanExpedition?.snapshot() ?? null; }
  privateExpeditionLog(partyId: string) { if (!this.#parties.has(partyId)) throw new WorldSimulationQueryError(`Party ${partyId} does not exist.`); return this.#caravanExpedition?.privateLog(partyId) ?? []; }
  partyExpeditionView(partyId: string) {
    const party = this.#parties.get(partyId); if (party === undefined) throw new WorldSimulationQueryError(`Party ${partyId} does not exist.`);
    const snapshot = this.#caravanExpedition?.snapshot(); if (snapshot === undefined) return null;
    const nodeId = party.location.status === "idle" ? party.location.nodeId : null;
    return {
      characters: snapshot.characters.filter((item) => item.partyId === partyId), animals: snapshot.animals.filter((item) => item.partyId === partyId), vehicles: snapshot.vehicles.filter((item) => item.partyId === partyId),
      contracts: snapshot.contracts.filter((item) => item.contractorPartyId === partyId || (item.status === "offered" && this.#locations.get(item.pickupLocationId)?.nodeId === nodeId)),
      encounter: snapshot.encounters.find((item) => item.defenderPartyId === partyId && item.status === "awaiting_decision") ?? null,
      metrics: snapshot.metrics, log: this.#caravanExpedition?.privateLog(partyId) ?? [],
    };
  }

  facilityHostResource(hostId: string, resourceId: string): number {
    return this.#simulationFoundation?.facilityHostResource(hostId, resourceId) ?? 0;
  }

  managedTradeHubSnapshot(issuerActorId: string, accountEntityId: string, hubId: string): TradeHubSnapshot | null {
    const foundation = this.#simulationFoundation;
    if (foundation === null || !foundation.authorize(issuerActorId, accountEntityId, "trade:order")) return null;
    return foundation.tradeHubSnapshot(hubId);
  }

  worldMemoryView(ownerId: string, ownerKind: WorldMemoryOwnerKind): WorldMemoryOwnerView {
    return this.#worldMemory.ownerView(ownerId, ownerKind, this.#clock.elapsedDays);
  }

  navigationKnowledgeGraph(ownerId: string, ownerKind: WorldMemoryOwnerKind) { return buildNavigationKnowledgeGraph(this.#worldMemory.ownerView(ownerId, ownerKind, this.#clock.elapsedDays)); }
  spatialTruthSnapshot(): { readonly hiddenNodes: readonly RegionGraphNode[]; readonly metrics: ReturnType<ContinuousSpace["metrics"]> } { return { hiddenNodes: this.#graph.nodes.filter((node) => node.visibility === "hidden").map((node) => structuredClone(node)), metrics: this.#continuousSpace.metrics() }; }

  observeGovernorShortages(
    governorActorId: string,
    staleAfterDays: number,
  ): readonly WorldMemoryEntry[] {
    const foundation = this.#simulationFoundation;
    if (foundation === null) return [];
    const facilityById = new Map(foundation.facilitySnapshots().map((item) => [item.facilityId, item]));
    const ingests: WorldMemoryIngest[] = [];
    const cursor = this.#shortageObservationCursors.get(governorActorId) ?? 0;
    const batch = foundation.eventsSince(cursor);
    for (const event of batch.events) {
      if (event.eventType === "FacilityProductionRecovered") {
        const facility = facilityById.get(event.facilityId);
        if (facility === undefined || !foundation.authorize(governorActorId, facility.facilityId, "facility:supply")) continue;
        for (const goodsId of event.recoveredResourceIds) ingests.push(shortageMemoryIngest(
          governorActorId, facility, goodsId, event.scheduledEventId, event.elapsedDays,
          this.#clock.elapsedDays, staleAfterDays, "shortage_recovered", [], 1,
        ));
        continue;
      }
      if (event.eventType === "ResourceConsumptionAttempted" && event.outcome === "recovered") {
        const facility = [...facilityById.values()].find((item) => item.hostId === event.hostId);
        if (facility !== undefined && foundation.authorize(governorActorId, facility.facilityId, "facility:supply")) {
          ingests.push(shortageMemoryIngest(
            governorActorId, facility, event.resourceId, event.scheduledEventId, event.elapsedDays,
            this.#clock.elapsedDays, staleAfterDays, "shortage_recovered", [], event.amount,
          ));
        }
        continue;
      }
      if (event.eventType !== "FacilityProductionBlocked"
        && event.eventType !== "FacilityProductionDegraded"
        && (event.eventType !== "ResourceConsumptionAttempted" || event.outcome !== "shortage")) continue;
      const facility = event.eventType === "ResourceConsumptionAttempted"
        ? [...facilityById.values()].find((item) => item.hostId === event.hostId)
        : facilityById.get(event.facilityId);
      if (facility === undefined || !foundation.authorize(governorActorId, facility.facilityId, "facility:supply")) continue;
      const resourceIds = event.eventType === "ResourceConsumptionAttempted"
        ? [event.resourceId]
        : event.missingResourceIds;
      for (const goodsId of resourceIds) {
        const consequences = event.eventType === "ResourceConsumptionAttempted"
          ? event.configuredConsequences
          : facility.recipe.shortagePolicies.find((policy) => policy.resourceId === goodsId)?.consequences ?? [];
        ingests.push(shortageMemoryIngest(
          governorActorId, facility, goodsId, event.scheduledEventId, event.elapsedDays,
          this.#clock.elapsedDays, staleAfterDays, "shortage_observation",
          consequences.map((item) => item.type),
          event.eventType === "ResourceConsumptionAttempted" ? event.amount : 1,
        ));
      }
    }
    const result = this.#worldMemory.ingestAll(ingests);
    if (result.accepted) this.#shortageObservationCursors.set(governorActorId, batch.nextIndex);
    return result.accepted ? result.entries : [];
  }

  observeGovernorPopulation(governorActorId: string, staleAfterDays: number): readonly WorldMemoryEntry[] {
    const foundation = this.#simulationFoundation, population = foundation?.populationSnapshot();
    if (foundation === null || foundation === undefined || population === null || population === undefined) return [];
    const settlementIds = new Set(population.settlements.filter((item) => foundation.authorize(governorActorId, item.settlementId, "population:allocate")).map((item) => item.settlementId));
    const ingests: WorldMemoryIngest[] = foundation.eventsSince(0).events.flatMap((event) => event.eventType === "PopulationSeasonAdvanced" && settlementIds.has(event.settlementId) ? [{ ingestId: `population:${governorActorId}:${event.scheduledEventId}`, ownerId: governorActorId, ownerKind: "actor" as const, kind: "population_observation", observedAtElapsedDays: event.elapsedDays, knownAtElapsedDays: this.#clock.elapsedDays, staleAfterDays, provenance: { sourceType: "direct_observation" as const, sourceId: event.scheduledEventId, sourceOwnerId: event.settlementId, nodeId: population.settlements.find((item) => item.settlementId === event.settlementId)?.nodeId ?? null }, payload: { settlementId: event.settlementId, season: event.season, population: event.populationAfter, healthPermille: event.healthPermille, nutritionPermille: event.nutritionPermille, labourAvailable: event.labourAvailable, foodRequired: event.foodRequired, foodConsumed: event.foodConsumed, diseaseState: event.diseaseState } }] : []);
    const result = this.#worldMemory.ingestAll(ingests);
    return result.accepted ? result.entries : [];
  }

  governorSupplyAffordances(governorActorId: string): readonly GovernorSupplyAffordance[] {
    const foundation = this.#simulationFoundation;
    if (foundation === null) return [];
    const hubs = foundation.tradeHubSnapshots();
    return foundation.facilitySnapshots()
      .filter((facility) => foundation.authorize(governorActorId, facility.facilityId, "facility:supply"))
      .map((facility) => ({
        facilityId: facility.facilityId,
        facilityHostId: facility.hostId,
        destinationNodeId: hubs.find((hub) => hub.connectedFacilityHostIds.includes(facility.hostId))?.nodeId ?? "",
        executorPartyIds: [...this.#parties.values()]
          .filter((party) => party.location.status === "idle" && party.location.nodeId === (hubs.find((hub) => hub.connectedFacilityHostIds.includes(facility.hostId))?.nodeId ?? ""))
          .map((party) => party.id).sort(),
      }));
  }

  observeLocalRouteSecurity(observationId: string, observerPartyId: string, ownerId: string, ownerKind: Extract<WorldMemoryOwnerKind, "actor" | "party">, routeId: string, staleAfterDays: number): WorldMemoryEntry | null {
    const party = this.#parties.get(observerPartyId), edge = this.#graph.edgesById.get(routeId), security = this.#simulationFoundation?.routeSecurityRoute(routeId);
    if (party === undefined || edge === undefined || security === null || security === undefined) return null;
    const local = party.location.status === "traveling" ? !("spatial" in party.location) && party.location.edgeId === routeId : edge.originNodeId === party.location.nodeId || edge.targetNodeId === party.location.nodeId;
    if (!local || ownerId !== (ownerKind === "party" ? party.id : party.managerActorId)) return null;
    const result = this.#worldMemory.ingest({ ingestId: `route-security:${observationId}`, ownerId, ownerKind, kind: "route_security_observation", observedAtElapsedDays: this.#clock.elapsedDays, knownAtElapsedDays: this.#clock.elapsedDays, staleAfterDays, provenance: { sourceType: "direct_observation", sourceId: observationId, sourceOwnerId: observerPartyId, nodeId: party.location.status === "idle" ? party.location.nodeId : null }, payload: { routeId, riskPermille: security.riskPermille, incidentCount: security.incidentCount, patrolStrength: security.patrolStrength } });
    return result.accepted ? result.entry : null;
  }

  reportRouteIncident(reportId: string, reporterPartyId: string, recipientActorId: string, encounterId: string, staleAfterDays: number): WorldMemoryEntry | null {
    const party = this.#parties.get(reporterPartyId), foundation = this.#simulationFoundation;
    if (party === undefined || foundation === null || party.location.status !== "idle") return null;
    const incident = foundation.eventsSince(0).events.find((event): event is RouteEncounterEvent & { readonly eventType: "RouteEncounterResolved" } => event.eventType === "RouteEncounterResolved" && event.encounterId === encounterId && (event.attackerPartyId === party.id || event.defenderPartyId === party.id));
    const edge = incident === undefined ? undefined : this.#graph.edgesById.get(incident.routeId);
    if (incident === undefined || edge === undefined || (party.location.nodeId !== edge.originNodeId && party.location.nodeId !== edge.targetNodeId) || !foundation.authorize(recipientActorId, incident.routeId, "security:task")) return null;
    const result = this.#worldMemory.ingest({ ingestId: `route-report:${reportId}`, ownerId: recipientActorId, ownerKind: "actor", kind: "route_incident_report", observedAtElapsedDays: incident.elapsedDays, knownAtElapsedDays: this.#clock.elapsedDays, staleAfterDays, provenance: { sourceType: "report", sourceId: reportId, sourceOwnerId: reporterPartyId, nodeId: party.location.nodeId }, payload: { encounterId, routeId: incident.routeId, outcome: incident.outcome, stolenCargo: incident.stolenCargo, casualties: incident.attackerCasualties + incident.defenderCasualties } });
    return result.accepted ? result.entry : null;
  }

  merchantLocalTradeAffordances(partyId: string): MerchantLocalTradeAffordances {
    const party = this.#parties.get(partyId);
    if (party === undefined) throw new WorldSimulationQueryError(`Party ${partyId} does not exist.`);
    const snapshot = createPartySnapshot(this.#graph, party, this.#economySeed);
    const hubs = party.location.status === "idle" && party.location.nodeId !== null
      ? this.#simulationFoundation?.tradeHubSnapshotsAtNode(party.location.nodeId) ?? []
      : [];
    return {
      party: snapshot,
      issuerActorId: party.managerActorId,
      accountEntityId: party.id,
      localTradeHubs: hubs.map((hub) => ({
        hubId: hub.hubId,
        nodeId: hub.nodeId,
        account: structuredClone(hub.accounts.find((account) => account.accountEntityId === party.id) ?? null),
      })),
    };
  }

  observeLocalTradeContext(request: ObserveLocalTradeContextRequest): ObserveLocalTradeContextResult {
    const party = this.#parties.get(request.observerPartyId);
    if (party === undefined) {
      return { accepted: false, errorCode: "PARTY_NOT_FOUND", message: `Party ${request.observerPartyId} does not exist.` };
    }
    if (party.location.status !== "idle") {
      return { accepted: false, errorCode: "PARTY_BUSY", message: `Party ${party.id} is traveling.` };
    }
    const expectedOwnerId = request.ownerKind === "party" ? party.id : party.managerActorId;
    if (request.ownerId !== expectedOwnerId) {
      return {
        accepted: false,
        errorCode: "OWNER_SCOPE_MISMATCH",
        message: `Observer ${party.id} cannot write memory owned by ${request.ownerId}.`,
      };
    }
    if (party.location.nodeId === null) return { accepted: false, errorCode: "NO_LOCAL_TRADE_HUB", message: `Party ${party.id} is off-road and has no local TradeHub.` };
    const hubs = this.#simulationFoundation?.tradeHubSnapshotsAtNode(party.location.nodeId) ?? [];
    if (hubs.length === 0) {
      return {
        accepted: false,
        errorCode: "NO_LOCAL_TRADE_HUB",
        message: `Party ${party.id} has no TradeHub at ${party.location.nodeId}.`,
      };
    }
    const observationNodeId = party.location.nodeId;
    const ingests: WorldMemoryIngest[] = hubs.map((hub) => {
      const openOrders = hub.orders.filter((order) =>
        order.status === "open" || order.status === "partially_filled");
      const goodsIds = [...new Set(openOrders.map((order) => order.goodsId))].sort();
      const market = goodsIds.map((goodsId) => {
        const orders = openOrders.filter((order) => order.goodsId === goodsId);
        const bids = orders.filter((order) => order.side === "buy").map((order) => order.limitPrice);
        const asks = orders.filter((order) => order.side === "sell").map((order) => order.limitPrice);
        return {
          goodsId,
          bestBid: bids.length === 0 ? null : Math.max(...bids),
          bestAsk: asks.length === 0 ? null : Math.min(...asks),
        };
      });
      const account = hub.accounts.find((item) => item.accountEntityId === request.accountEntityId);
      return {
        ingestId: `${request.observationId}:${hub.hubId}`,
        ownerId: request.ownerId,
        ownerKind: request.ownerKind,
        kind: "trade_hub_observation",
        observedAtElapsedDays: this.#clock.elapsedDays,
        knownAtElapsedDays: this.#clock.elapsedDays,
        staleAfterDays: request.staleAfterDays,
        provenance: {
          sourceType: "direct_observation",
          sourceId: request.observationId,
          sourceOwnerId: request.ownerId,
          nodeId: observationNodeId,
        },
        payload: {
          hubId: hub.hubId,
          nodeId: hub.nodeId,
          market,
          observerPartyId: party.id,
          observerPartyCargo: Object.fromEntries(party.cargo),
          account: account === undefined ? null : {
            availableGoods: account.availableGoods,
            escrowGoods: account.escrowGoods,
            availableCurrency: account.availableCurrency,
            escrowCurrency: account.escrowCurrency,
          },
        },
      };
    });
    const result = this.#worldMemory.ingestAll(ingests);
    if (!result.accepted) {
      return { accepted: false, errorCode: "MEMORY_INGEST_CONFLICT", message: result.message };
    }
    return { accepted: true, entries: result.entries };
  }

  #assignSupplyTask(command: AssignSupplyTaskCommand): SupplyCommandResult {
    const foundation = this.#simulationFoundation;
    const party = this.#parties.get(command.executorPartyId);
    if (foundation === null
      || !foundation.authorize(command.issuerActorId, command.facilityId, "facility:supply")
      || !foundation.authorize(command.issuerActorId, command.executorPartyId, "supply:delegate")) {
      return supplyRejected("NOT_AUTHORIZED", "Issuer cannot delegate supply for this Facility and party.");
    }
    if (party === undefined) return supplyRejected("PARTY_NOT_FOUND", `Party ${command.executorPartyId} does not exist.`);
    if (party.location.status !== "idle") return supplyRejected("PARTY_BUSY", `Party ${party.id} is traveling.`);
    if (party.location.nodeId !== command.destinationNodeId) return supplyRejected("LOCATION_MISMATCH", "Executor and managed Facility are not co-located for delegation.");
    const result = this.#worldMemory.ingest({
      ingestId: `supply-command:${command.commandId}`,
      ownerId: party.id,
      ownerKind: "party",
      kind: "supply_task",
      observedAtElapsedDays: this.#clock.elapsedDays,
      knownAtElapsedDays: this.#clock.elapsedDays,
      staleAfterDays: null,
      provenance: { sourceType: "command_result", sourceId: command.commandId, sourceOwnerId: command.issuerActorId, nodeId: command.destinationNodeId },
      payload: { ...command },
    });
    return result.accepted
      ? { accepted: true, idempotentReplay: result.idempotentReplay }
      : supplyRejected("MEMORY_CONFLICT", result.message);
  }

  #deliverSupplyTask(command: DeliverSupplyTaskCommand): SupplyCommandResult {
    const foundation = this.#simulationFoundation;
    const party = this.#parties.get(command.executorPartyId);
    if (foundation === null || !foundation.authorize(command.issuerActorId, command.facilityId, "facility:supply")) {
      return supplyRejected("NOT_AUTHORIZED", "Issuer cannot deliver supply for this Facility.");
    }
    if (party === undefined) return supplyRejected("PARTY_NOT_FOUND", `Party ${command.executorPartyId} does not exist.`);
    const priorResult = this.#worldMemory.ownerView(party.id, "party", this.#clock.elapsedDays).entries.find((entry) =>
      entry.kind === "supply_task_result" && entry.payload.commandId === command.commandId);
    if (priorResult !== undefined) {
      return priorResult.payload.taskId === command.taskId
        && priorResult.payload.goodsId === command.goodsId
        && priorResult.payload.amount === command.amount
        ? { accepted: true, idempotentReplay: true }
        : supplyRejected("MEMORY_CONFLICT", `Command id ${command.commandId} was reused with different data.`);
    }
    const task = this.#worldMemory.ownerView(party.id, "party", this.#clock.elapsedDays).entries.find((entry) =>
      entry.kind === "supply_task" && entry.payload.taskId === command.taskId);
    if (task === undefined) return supplyRejected("TASK_NOT_FOUND", `Task ${command.taskId} is not known by ${party.id}.`);
    if (party.location.status !== "idle") return supplyRejected("PARTY_BUSY", `Party ${party.id} is traveling.`);
    const hubNode = foundation.domainSnapshot().tradeHubs?.hubs.find((hub) => hub.connectedFacilityHostIds.includes(command.facilityHostId))?.nodeId;
    if (hubNode === undefined || party.location.nodeId !== hubNode) return supplyRejected("LOCATION_MISMATCH", "Party is not physically at the Facility host node.");
    const carried = party.cargo.get(command.goodsId) ?? 0;
    if (carried < command.amount) return supplyRejected("INSUFFICIENT_GOODS", "Party cargo does not contain the assigned goods.");
    const resultIngest: WorldMemoryIngest = {
      ingestId: `supply-delivery:${command.commandId}`,
      ownerId: party.id,
      ownerKind: "party",
      kind: "supply_task_result",
      observedAtElapsedDays: this.#clock.elapsedDays,
      knownAtElapsedDays: this.#clock.elapsedDays,
      staleAfterDays: null,
      provenance: { sourceType: "command_result", sourceId: command.commandId, sourceOwnerId: command.issuerActorId, nodeId: hubNode },
      payload: { commandId: command.commandId, taskId: command.taskId, facilityId: command.facilityId, goodsId: command.goodsId, amount: command.amount, outcome: "delivered" },
    };
    const preview = this.#worldMemory.previewIngest(resultIngest);
    if (!preview.accepted) return supplyRejected("MEMORY_CONFLICT", preview.message);
    if (!foundation.depositToFacilityHost(command.facilityHostId, command.goodsId, command.amount)) {
      return supplyRejected("STORAGE_EXCEEDED", "Facility host cannot accept the delivery.");
    }
    setQuantity(party.cargo, command.goodsId, carried - command.amount);
    const result = this.#worldMemory.ingest(resultIngest);
    if (!result.accepted) throw new WorldSimulationConfigurationError("Supply delivery result ingest conflicted after validated mutation.");
    return { accepted: true, idempotentReplay: false };
  }

  #reportSupplyTask(command: ReportSupplyTaskCommand): SupplyCommandResult {
    const foundation = this.#simulationFoundation;
    const party = this.#parties.get(command.executorPartyId);
    if (foundation === null || party === undefined) return supplyRejected("PARTY_NOT_FOUND", "Reporting party does not exist.");
    if (party.managerActorId !== command.issuerActorId
      || !foundation.authorize(command.recipientActorId, command.facilityId, "facility:supply")) {
      return supplyRejected("NOT_AUTHORIZED", "Report sender or recipient is not authorized.");
    }
    const resultEntry = this.#worldMemory.ownerView(party.id, "party", this.#clock.elapsedDays).entries.find((entry) =>
      entry.kind === "supply_task_result" && entry.payload.taskId === command.taskId);
    if (resultEntry === undefined) return supplyRejected("TASK_NOT_FOUND", `Completed task ${command.taskId} is not known by ${party.id}.`);
    if (party.location.status !== "idle") return supplyRejected("PARTY_BUSY", "A traveling party cannot deliver a report.");
    const facility = foundation.facilitySnapshot(command.facilityId);
    const reportNode = foundation.domainSnapshot().tradeHubs?.hubs.find((hub) =>
      hub.connectedFacilityHostIds.includes(facility.hostId))?.nodeId;
    if (reportNode === undefined || party.location.nodeId !== reportNode) {
      return supplyRejected("LOCATION_MISMATCH", "Report handoff must occur at the managed Facility node.");
    }
    const result = this.#worldMemory.ingest({
      ingestId: `supply-report:${command.commandId}`,
      ownerId: command.recipientActorId,
      ownerKind: "actor",
      kind: "supply_report",
      observedAtElapsedDays: resultEntry.observedAtElapsedDays,
      knownAtElapsedDays: this.#clock.elapsedDays,
      staleAfterDays: null,
      provenance: { sourceType: "report", sourceId: command.commandId, sourceOwnerId: party.id, nodeId: reportNode },
      payload: { taskId: command.taskId, resultEntryId: resultEntry.entryId, outcome: "delivered" },
    });
    return result.accepted ? { accepted: true, idempotentReplay: result.idempotentReplay } : supplyRejected("MEMORY_CONFLICT", result.message);
  }

  #acceptCaravanContract(command: AcceptCaravanContractCommand): ExpeditionCommandResult {
    const expedition = this.#requireExpedition(), beforeExpedition = expedition.snapshot(), beforeLocations = [...this.#locations.entries()].map(([id, value]) => [id, new Map(value.resources)] as const), beforeParties = [...this.#parties.entries()].map(([id, value]) => [id, new Map(value.cargo)] as const);
    const mutation = expedition.accept(command, this.#clock.elapsedDays, this.#expeditionPort());
    if (!mutation.result.accepted || mutation.intent === null) return mutation.result;
    try { this.#simulationFoundation?.scheduleCommandIntent(mutation.intent); if (this.#simulationFoundation === null) throw new Error("Contracts require the canonical Foundation dispatcher."); return mutation.result; }
    catch (error) { this.#caravanExpedition = new CaravanExpeditions(beforeExpedition); for (const [id, resources] of beforeLocations) { const location = this.#locations.get(id)!; location.resources.clear(); for (const [goodsId, amount] of resources) location.resources.set(goodsId, amount); } for (const [id, cargo] of beforeParties) { const party = this.#parties.get(id)!; party.cargo.clear(); for (const [goodsId, amount] of cargo) party.cargo.set(goodsId, amount); } return { accepted: false, idempotentReplay: false, errorCode: "SCHEDULING_FAILED", message: error instanceof Error ? error.message : String(error) }; }
  }

  #deliverCaravanContract(command: DeliverCaravanContractCommand): ExpeditionCommandResult {
    const result = this.#requireExpedition().deliver(command, this.#clock.elapsedDays, this.#expeditionPort());
    if (result.accepted) this.#rememberExpeditionResult(command.commandId, command.contractId, "contract_completed", result.outcome ?? "completed");
    return result;
  }

  #planExpeditionEncounter(command: PlanExpeditionEncounterCommand): ExpeditionCommandResult {
    const expedition = this.#requireExpedition(), before = expedition.snapshot(), mutation = expedition.planEncounter(command, this.#clock.elapsedDays, this.#expeditionPort());
    if (!mutation.result.accepted || mutation.intent === null) return mutation.result;
    try { if (this.#simulationFoundation === null) throw new Error("Encounters require the canonical Foundation dispatcher."); this.#simulationFoundation.scheduleCommandIntent(mutation.intent); return mutation.result; }
    catch (error) { this.#caravanExpedition = new CaravanExpeditions(before); return { accepted: false, idempotentReplay: false, errorCode: "SCHEDULING_FAILED", message: error instanceof Error ? error.message : String(error) }; }
  }

  #resolveExpeditionEncounter(command: ResolveExpeditionEncounterCommand): ExpeditionCommandResult {
    const result = this.#requireExpedition().resolveEncounter(command, this.#clock.elapsedDays, this.#expeditionPort());
    if (result.accepted) { const encounter = this.#caravanExpedition?.snapshot().encounters.find((item) => item.encounterId === command.encounterId); if (encounter !== undefined) { this.#simulationFoundation?.recordExpeditionEncounter(encounter.routeId, result.outcome ?? command.decision); this.#ensureMovementTick(this.#parties.get(encounter.defenderPartyId)); } this.#rememberExpeditionResult(command.commandId, command.encounterId, "encounter_result", result.outcome ?? command.decision); }
    return result;
  }

  #rememberExpeditionResult(sourceId: string, subjectId: string, kind: string, outcome: string): void {
    const encounter = this.#caravanExpedition?.snapshot().encounters.find((item) => item.encounterId === subjectId), contract = this.#caravanExpedition?.snapshot().contracts.find((item) => item.contractId === subjectId), ownerId = encounter?.defenderPartyId ?? contract?.contractorPartyId;
    if (ownerId === null || ownerId === undefined) return;
    const owner = this.#parties.get(ownerId), nodeId = owner?.location.status === "idle" ? owner.location.nodeId : null;
    this.#worldMemory.ingest({ ingestId: `expedition-result:${sourceId}`, ownerId, ownerKind: "party", kind, observedAtElapsedDays: this.#clock.elapsedDays, knownAtElapsedDays: this.#clock.elapsedDays, staleAfterDays: null, provenance: { sourceType: "command_result", sourceId, sourceOwnerId: ownerId, nodeId }, payload: { subjectId, outcome } });
  }

  #requireExpedition(): CaravanExpeditions { if (this.#caravanExpedition === null) throw new WorldSimulationConfigurationError("Caravan expedition is not configured."); return this.#caravanExpedition; }

  #expeditionPort(): ExpeditionPhysicalPort {
    return {
      party: (partyId) => { const party = this.#parties.get(partyId); if (party === undefined) return null; const snapshot = createPartySnapshot(this.#graph, party, this.#economySeed), capacity = this.#economySeed === null ? 0 : calculatePartyCargoCapacity(party.composition, this.#economySeed.partyCargoConfig), used = this.#economySeed === null ? 0 : calculateCargoUsedBulk(party.cargo, this.#economySeed.goodsCatalog); return { partyId, managerActorId: party.managerActorId, nodeId: snapshot.currentNodeId, travelingRouteId: snapshot.travel?.edgeId ?? null, composition: { ...party.composition }, cargo: { ...snapshot.cargo }, cargoFreeBulk: Math.max(0, capacity - used), position: [...snapshot.position] }; },
      authorize: (issuerActorId, entityId, scope) => this.#simulationFoundation?.authorize(issuerActorId, entityId, scope) === true,
      locationNode: (locationId) => this.#locations.get(locationId)?.nodeId ?? null,
      reserveContract: (contract, partyId) => { const party = this.#parties.get(partyId), issuer = this.#locations.get(contract.issuerLocationId); if (party === undefined || issuer === undefined || party.location.status !== "idle" || party.location.nodeId !== issuer.nodeId) return "location"; if ((issuer.resources.get("coin") ?? 0) < contract.paymentCoin || (party.cargo.get("coin") ?? 0) < contract.collateralCoin) return "funds"; setQuantity(issuer.resources, "coin", (issuer.resources.get("coin") ?? 0) - contract.paymentCoin); setQuantity(party.cargo, "coin", (party.cargo.get("coin") ?? 0) - contract.collateralCoin); return "ok"; },
      pickupContract: (contract) => { const party = contract.contractorPartyId === null ? undefined : this.#parties.get(contract.contractorPartyId), location = this.#locations.get(contract.pickupLocationId); if (party === undefined || location === undefined || party.location.status !== "idle" || party.location.nodeId !== location.nodeId) return "location"; if ((location.resources.get(contract.goodsId) ?? 0) < contract.quantity) return "goods"; if (this.#economySeed === null) return "capacity"; const cargo = new Map(party.cargo); setQuantity(cargo, contract.goodsId, (cargo.get(contract.goodsId) ?? 0) + contract.quantity); if (calculateCargoUsedBulk(cargo, this.#economySeed.goodsCatalog) > calculatePartyCargoCapacity(party.composition, this.#economySeed.partyCargoConfig)) return "capacity"; setQuantity(location.resources, contract.goodsId, (location.resources.get(contract.goodsId) ?? 0) - contract.quantity); setQuantity(party.cargo, contract.goodsId, (party.cargo.get(contract.goodsId) ?? 0) + contract.quantity); return "ok"; },
      deliverContract: (contract) => { const party = contract.contractorPartyId === null ? undefined : this.#parties.get(contract.contractorPartyId), location = this.#locations.get(contract.deliveryLocationId); if (party === undefined || location === undefined || party.location.status !== "idle" || party.location.nodeId !== location.nodeId) return "location"; if ((party.cargo.get(contract.goodsId) ?? 0) < contract.quantity) return "goods"; if (this.#economySeed === null) return "capacity"; const cargo = new Map(party.cargo); setQuantity(cargo, contract.goodsId, (cargo.get(contract.goodsId) ?? 0) - contract.quantity); setQuantity(cargo, "coin", (cargo.get("coin") ?? 0) + contract.paymentEscrowCoin + contract.collateralEscrowCoin); if (calculateCargoUsedBulk(cargo, this.#economySeed.goodsCatalog) > calculatePartyCargoCapacity(party.composition, this.#economySeed.partyCargoConfig)) return "capacity"; setQuantity(party.cargo, contract.goodsId, (party.cargo.get(contract.goodsId) ?? 0) - contract.quantity); setQuantity(location.resources, contract.goodsId, (location.resources.get(contract.goodsId) ?? 0) + contract.quantity); setQuantity(party.cargo, "coin", (party.cargo.get("coin") ?? 0) + contract.paymentEscrowCoin + contract.collateralEscrowCoin); return "ok"; },
      abandonContract: (contract) => { const issuer = this.#locations.get(contract.issuerLocationId); if (issuer !== undefined) setQuantity(issuer.resources, "coin", (issuer.resources.get("coin") ?? 0) + contract.paymentEscrowCoin + contract.collateralEscrowCoin); },
      applyEncounter: (plan) => this.#applyExpeditionEncounter(plan),
    };
  }

  #applyExpeditionEncounter(plan: EncounterMutationPlan): boolean {
    const attacker = this.#parties.get(plan.attackerPartyId), defender = this.#parties.get(plan.defenderPartyId); if (attacker === undefined || defender === undefined || this.#economySeed === null) return false;
    const transfers = { ...plan.cargo, ...(plan.coin > 0 ? { coin: plan.coin } : {}) }; for (const [goodsId, amount] of Object.entries(transfers)) if (!Number.isSafeInteger(amount) || amount < 0 || (defender.cargo.get(goodsId) ?? 0) < amount) return false;
    const incoming = new Map(attacker.cargo); for (const [goodsId, amount] of Object.entries(transfers)) setQuantity(incoming, goodsId, (incoming.get(goodsId) ?? 0) + amount); if (calculateCargoUsedBulk(incoming, this.#economySeed.goodsCatalog) > calculatePartyCargoCapacity(attacker.composition, this.#economySeed.partyCargoConfig)) return false;
    const defenderLoss = plan.defenderCasualtyCharacterIds.length, attackerLoss = plan.attackerCasualtyCharacterIds.length; if (defenderLoss > defender.composition.footCount || attackerLoss > attacker.composition.footCount) return false;
    this.#delayMovement(defender, plan.retreatDays);
    for (const [goodsId, amount] of Object.entries(transfers)) { setQuantity(defender.cargo, goodsId, (defender.cargo.get(goodsId) ?? 0) - amount); setQuantity(attacker.cargo, goodsId, (attacker.cargo.get(goodsId) ?? 0) + amount); }
    defender.composition = applyCharacterCasualties(defender.composition, defenderLoss); attacker.composition = applyCharacterCasualties(attacker.composition, attackerLoss); if (plan.abandonWagon && defender.composition.wagonCount > 0) defender.composition = { ...defender.composition, wagonCount: defender.composition.wagonCount - 1 }; return true;
  }

  #startSpatialTravel(command: SpatialTravelCommand): SpatialCommandResult {
    const replay = this.#continuousSpace.replay(command); if (replay !== null) return replay;
    const party = this.#parties.get(command.partyId); if (party === undefined) return this.#continuousSpace.record(command, spatialRejected("PARTY_NOT_FOUND", `Party ${command.partyId} does not exist.`));
    if (party.location.status !== "idle") return this.#continuousSpace.record(command, spatialRejected("PARTY_BUSY", `Party ${command.partyId} is traveling.`));
    if (!this.#canCommandNavigation(command.issuerActorId, party)) return this.#continuousSpace.record(command, spatialRejected("NOT_AUTHORIZED", "Issuer cannot command this Party's navigation."));
    const graph = this.navigationKnowledgeGraph(party.id, "party"), knowledge = navigationItem(graph, command.targetKnowledgeId);
    if (knowledge === null || knowledge.estimatedPosition === null) return this.#continuousSpace.record(command, spatialRejected("KNOWLEDGE_UNKNOWN", `Navigation target ${command.targetKnowledgeId} is not known by ${party.id}.`));
    if (knowledge.freshness === "stale") return this.#continuousSpace.record(command, spatialRejected("KNOWLEDGE_STALE", `Navigation target ${command.targetKnowledgeId} is stale.`));
    const origin = party.location.position, destination = knowledge.estimatedPosition, config = this.#continuousSpace.config();
    const terrain = terrainAt(this.#graph, destination), distanceKm = spatialDistance(origin, destination, config.coordinateKmScale);
    if (distanceKm <= 0) return this.#continuousSpace.record(command, spatialRejected("INVALID_COMMAND", "Spatial destination must differ from current position."));
    const speed = this.#spatialSpeed(party, terrain.map((item) => item.kind), knowledge.kind === "edge" ? "track" : "offroad");
    const plan: SpatialTravelPlan = { commandId: command.commandId, eventId: `spatial:${command.commandId}:arrival`, partyId: party.id, kind: command.kind, origin: [...origin], destination: [...destination], targetWorldObjectId: knowledge.worldObjectId, distanceKm, durationDays: distanceKm / speed, terrainAreaIds: terrain.map((item) => item.id), knowledgeEntryId: knowledge.provenanceEntryId };
    const intent: ScheduledEventIntent = { eventId: plan.eventId, kind: SPATIAL_TRAVEL_DUE, dueElapsedDays: this.#clock.elapsedDays + plan.durationDays, targetComponent: "continuous_space", targetEntityId: party.id, payload: { plan: plan as unknown as SerializableValue } };
    if (this.#simulationFoundation === null) return this.#continuousSpace.record(command, spatialRejected("SCHEDULING_FAILED", "Spatial travel requires the canonical Foundation dispatcher."));
    try { this.#simulationFoundation.scheduleCommandIntent(intent); }
    catch (error) { return this.#continuousSpace.record(command, spatialRejected("SCHEDULING_FAILED", error instanceof Error ? error.message : String(error))); }
    party.location = { status: "traveling", spatial: true, journeyId: command.commandId, kind: "offroad", origin: [...origin], destination: [...destination], path: [[...origin], [...destination]], distanceKm, speedKmPerDay: speed, progressKm: 0, targetWorldObjectId: knowledge.worldObjectId };
    return this.#continuousSpace.record(command, { accepted: true, idempotentReplay: false, scheduledEventId: plan.eventId });
  }

  #startSpatialSearch(command: SearchAreaCommand): SpatialCommandResult {
    const replay = this.#continuousSpace.replay(command); if (replay !== null) return replay;
    const party = this.#parties.get(command.partyId); if (party === undefined) return this.#continuousSpace.record(command, spatialRejected("PARTY_NOT_FOUND", `Party ${command.partyId} does not exist.`));
    if (party.location.status !== "idle") return this.#continuousSpace.record(command, spatialRejected("PARTY_BUSY", `Party ${command.partyId} is traveling.`));
    if (!this.#canCommandNavigation(command.issuerActorId, party)) return this.#continuousSpace.record(command, spatialRejected("NOT_AUTHORIZED", "Issuer cannot command this search."));
    const item = navigationItem(this.navigationKnowledgeGraph(party.id, "party"), command.areaKnowledgeId);
    if (item === null || (item.uncertainty === null && item.estimatedPosition === null)) return this.#continuousSpace.record(command, spatialRejected("KNOWLEDGE_UNKNOWN", "Search area is not present in private navigation knowledge."));
    if (!Number.isFinite(command.searchRadiusKm) || command.searchRadiusKm <= 0 || command.searchRadiusKm > 30 || !Number.isSafeInteger(command.observationSkillPermille) || command.observationSkillPermille < 0 || command.observationSkillPermille > 1000) return this.#continuousSpace.record(command, spatialRejected("INVALID_COMMAND", "Search radius or observation skill is invalid."));
    const center = item.uncertainty?.center ?? item.estimatedPosition!, config = this.#continuousSpace.config(), searchPath = deterministicSearchPath(center, Math.min(command.searchRadiusKm, item.uncertainty?.radiusKm ?? command.searchRadiusKm) / config.coordinateKmScale, config.maxSearchSteps), path = [[...party.location.position] as Vec2, ...searchPath], distanceKm = polylineDistance(path, config.coordinateKmScale), speed = this.#spatialSpeed(party, terrainAt(this.#graph, center).map((area) => area.kind), "offroad"), observationSkill = this.#caravanExpedition === null ? command.observationSkillPermille : Math.min(command.observationSkillPermille, this.#caravanExpedition.visibilitySkill(party.id));
    const plan: SpatialSearchPlan = { commandId: command.commandId, eventId: `spatial:${command.commandId}:search`, partyId: party.id, center: [...center], radiusKm: command.searchRadiusKm, path, distanceKm, durationDays: distanceKm / speed, observationSkillPermille: observationSkill, knowledgeEntryId: item.provenanceEntryId };
    const intent: ScheduledEventIntent = { eventId: plan.eventId, kind: SPATIAL_SEARCH_DUE, dueElapsedDays: this.#clock.elapsedDays + plan.durationDays, targetComponent: "continuous_space", targetEntityId: party.id, payload: { plan: plan as unknown as SerializableValue } };
    if (this.#simulationFoundation === null) return this.#continuousSpace.record(command, spatialRejected("SCHEDULING_FAILED", "Spatial search requires the canonical Foundation dispatcher."));
    try { this.#simulationFoundation.scheduleCommandIntent(intent); } catch (error) { return this.#continuousSpace.record(command, spatialRejected("SCHEDULING_FAILED", error instanceof Error ? error.message : String(error))); }
    party.location = { status: "traveling", spatial: true, journeyId: command.commandId, kind: "search", origin: [...party.location.position], destination: [...searchPath.at(-1)!], path, distanceKm, speedKmPerDay: speed, progressKm: 0, targetWorldObjectId: null };
    return this.#continuousSpace.record(command, { accepted: true, idempotentReplay: false, scheduledEventId: plan.eventId });
  }

  #observeSurroundings(command: ObserveSurroundingsCommand): SpatialCommandResult {
    const replay = this.#continuousSpace.replay(command); if (replay !== null) return replay;
    const party = this.#parties.get(command.partyId); if (party === undefined) return this.#continuousSpace.record(command, spatialRejected("PARTY_NOT_FOUND", `Party ${command.partyId} does not exist.`));
    if (!this.#canCommandNavigation(command.issuerActorId, party)) return this.#continuousSpace.record(command, spatialRejected("NOT_AUTHORIZED", "Issuer cannot command observation."));
    if (!Number.isSafeInteger(command.observationSkillPermille) || command.observationSkillPermille < 0 || command.observationSkillPermille > 1000) return this.#continuousSpace.record(command, spatialRejected("INVALID_COMMAND", "Observation skill is invalid."));
    const position = createPartySnapshot(this.#graph, party, this.#economySeed).position;
    this.#adjudicateSpatialObservation(party, position, [position], this.#caravanExpedition === null ? command.observationSkillPermille : Math.min(command.observationSkillPermille, this.#caravanExpedition.visibilitySkill(party.id)), command.commandId);
    return this.#continuousSpace.record(command, { accepted: true, idempotentReplay: false, scheduledEventId: null });
  }

  #reportNavigationKnowledge(command: ReportNavigationKnowledgeCommand): SpatialCommandResult {
    const replay = this.#continuousSpace.replay(command); if (replay !== null) return replay;
    const reporter = this.#parties.get(command.reporterPartyId); if (reporter === undefined) return this.#continuousSpace.record(command, spatialRejected("PARTY_NOT_FOUND", "Reporter Party does not exist."));
    if (reporter.location.status !== "idle") return this.#continuousSpace.record(command, spatialRejected("PARTY_BUSY", "A report requires a physical handoff while idle."));
    if (!this.#canCommandNavigation(command.issuerActorId, reporter)) return this.#continuousSpace.record(command, spatialRejected("NOT_AUTHORIZED", "Issuer cannot report for this Party."));
    const item = navigationItem(this.navigationKnowledgeGraph(reporter.id, "party"), command.sourceKnowledgeId);
    if (item === null || !Number.isFinite(command.knownDelayDays) || command.knownDelayDays <= 0 || !Number.isSafeInteger(command.confidenceLossPermille) || !Number.isSafeInteger(command.distortionPermille)) return this.#continuousSpace.record(command, spatialRejected("INVALID_COMMAND", "A report requires valid source knowledge and an explicit positive courier delay."));
    const confidence = Math.max(0, item.confidencePermille - command.confidenceLossPermille), uncertaintyRadius = (item.uncertainty?.radiusKm ?? 0.5) * (1 + Math.max(0, command.distortionPermille) / 1000), sourceCenter = item.estimatedPosition ?? item.uncertainty?.center ?? null, uncertaintyCenter = sourceCenter === null ? null : distortedReportCenter(sourceCenter, uncertaintyRadius, command.distortionPermille, command.commandId, this.#continuousSpace.config().coordinateKmScale);
    const exact = confidence >= 900 && command.distortionPermille === 0;
    const result = this.#worldMemory.ingest({ ingestId: `navigation-report:${command.commandId}`, ownerId: command.recipientOwnerId, ownerKind: command.recipientOwnerKind, kind: "navigation_report", observedAtElapsedDays: this.#clock.elapsedDays, knownAtElapsedDays: this.#clock.elapsedDays + command.knownDelayDays, staleAfterDays: 180, provenance: { sourceType: "report", sourceId: command.commandId, sourceOwnerId: reporter.id, nodeId: reporter.location.nodeId }, payload: { knowledgeId: item.knowledgeId, knowledgeKind: item.kind, worldObjectId: exact ? item.worldObjectId : null, estimatedPosition: exact ? item.estimatedPosition : null, uncertaintyCenter, uncertaintyRadiusKm: uncertaintyRadius, relation: item.relation, confidencePermille: confidence, distortionPermille: command.distortionPermille, sourceEntryId: item.provenanceEntryId } });
    return this.#continuousSpace.record(command, result.accepted ? { accepted: true, idempotentReplay: result.idempotentReplay, scheduledEventId: null } : spatialRejected("COMMAND_ID_CONFLICT", result.message));
  }

  #relocateSpatialObject(command: RelocateSpatialObjectCommand): SpatialCommandResult {
    const replay = this.#continuousSpace.replay(command); if (replay !== null) return replay;
    const foundation = this.#simulationFoundation;
    if (foundation === null || !foundation.authorize(command.issuerActorId, command.worldObjectId, "spatial:relocate")) return this.#continuousSpace.record(command, spatialRejected("NOT_AUTHORIZED", "Issuer cannot relocate this world object."));
    if (command.position.length !== 2 || command.position.some((value) => !Number.isFinite(value))) return this.#continuousSpace.record(command, spatialRejected("INVALID_COMMAND", "Relocation coordinate is invalid."));
    this.#continuousSpace.relocate(command.worldObjectId, command.position);
    return this.#continuousSpace.record(command, { accepted: true, idempotentReplay: false, scheduledEventId: null });
  }

  #handleSpatialEvent(intent: ScheduledEventIntent, elapsedDays: number): void {
    if (!this.#continuousSpace.recordEvent(intent.eventId)) return;
    const plan = readSpatialPlan(intent), party = this.#parties.get(plan.partyId);
    if (party === undefined || party.location.status !== "traveling" || !("spatial" in party.location) || party.location.journeyId !== plan.commandId) return;
    party.location.progressKm = party.location.distanceKm;
    if (intent.kind === SPATIAL_SEARCH_DUE) {
      const search = plan as SpatialSearchPlan, position = search.path.at(-1)!;
      const discovered = this.#adjudicateSpatialObservation(party, position, search.path, search.observationSkillPermille, search.commandId);
      party.location = { status: "idle", nodeId: null, position: [...position] };
      this.#continuousSpace.addTravel(search.distanceKm, false); this.#continuousSpace.addSearch(search.radiusKm, discovered);
      return;
    }
    const travel = plan as SpatialTravelPlan, targetNode = travel.targetWorldObjectId === null ? null : this.#graph.nodesById.get(travel.targetWorldObjectId);
    party.location = { status: "idle", nodeId: targetNode === undefined || targetNode === null ? null : targetNode.id, position: [...travel.destination] };
    this.#continuousSpace.addTravel(travel.distanceKm, targetNode?.visibility === "hidden");
    this.#adjudicateSpatialObservation(party, travel.destination, [travel.origin, travel.destination], 700, travel.commandId);
  }

  #adjudicateSpatialObservation(party: PartyRuntimeState, position: Vec2, path: readonly Vec2[], skillPermille: number, observationId: string): boolean {
    const config = this.#continuousSpace.config(), elapsed = this.#clock.elapsedDays, visibility = config.baseVisibilityKm * ((Math.floor(elapsed) % 360) >= 330 ? config.nightVisibilityPermille / 1000 : 1);
    let discovered = false;
    for (const node of this.#graph.nodes.filter((item) => item.visibility === "hidden").sort((a, b) => a.id < b.id ? -1 : 1)) {
      const truth = this.#continuousSpace.truthPosition(this.#graph, node.id)!;
      const closest = Math.min(distanceToPolyline(truth, path, config.coordinateKmScale), spatialDistance(position, truth, config.coordinateKmScale));
      if (!detectionSucceeds(`${observationId}:${node.id}`, closest, Math.max(visibility, node.discoveryRadiusKm), skillPermille, node.concealmentPermille)) continue;
      const uncertainty = Math.max(0.1, (1000 - skillPermille) / 500);
      const ingest = this.#worldMemory.ingest({ ingestId: `navigation-discovery:${party.id}:${observationId}:${node.id}`, ownerId: party.id, ownerKind: "party", kind: "navigation_discovery", observedAtElapsedDays: elapsed, knownAtElapsedDays: elapsed, staleAfterDays: 360, provenance: { sourceType: "direct_observation", sourceId: observationId, sourceOwnerId: party.id, nodeId: party.location.status === "idle" ? party.location.nodeId : null }, payload: { knowledgeId: `node:${node.id}`, knowledgeKind: "node", worldObjectId: node.id, estimatedPosition: truth, uncertaintyCenter: truth, uncertaintyRadiusKm: uncertainty, relation: "directly_observed", confidencePermille: Math.max(500, skillPermille) } });
      if (ingest.accepted && !ingest.idempotentReplay) discovered = true;
      for (const edge of this.#graph.edges.filter((item) => item.visibility === "hidden" && (item.originNodeId === node.id || item.targetNodeId === node.id)).sort((a, b) => a.id < b.id ? -1 : 1)) {
        const otherNodeId = edge.originNodeId === node.id ? edge.targetNodeId : edge.originNodeId;
        this.#worldMemory.ingest({ ingestId: `navigation-discovery:${party.id}:${observationId}:${edge.id}`, ownerId: party.id, ownerKind: "party", kind: "navigation_discovery", observedAtElapsedDays: elapsed, knownAtElapsedDays: elapsed, staleAfterDays: 180, provenance: { sourceType: "direct_observation", sourceId: observationId, sourceOwnerId: party.id, nodeId: node.id }, payload: { knowledgeId: `edge:${edge.id}`, knowledgeKind: "edge", worldObjectId: edge.id, estimatedPosition: this.#continuousSpace.truthPosition(this.#graph, otherNodeId), uncertaintyCenter: truth, uncertaintyRadiusKm: uncertainty, relation: `${edge.originNodeId}->${edge.targetNodeId}`, confidencePermille: Math.max(500, skillPermille) } });
      }
    }
    return discovered;
  }

  #canCommandNavigation(issuerActorId: string, party: PartyRuntimeState): boolean { return issuerActorId === party.managerActorId || this.#simulationFoundation?.authorize(issuerActorId, party.id, "navigation:command") === true; }
  #spatialSpeed(party: PartyRuntimeState, terrainKinds: readonly string[], mode: "road" | "track" | "offroad"): number {
    const capacity = this.#economySeed === null ? 1 : calculatePartyCargoCapacity(party.composition, this.#economySeed.partyCargoConfig), used = this.#economySeed === null ? 0 : calculateCargoUsedBulk(party.cargo, this.#economySeed.goodsCatalog), burden = Math.round(used / Math.max(1, capacity) * 1000), winter = (Math.floor(this.#clock.elapsedDays) % 360) < 90;
    const characterModifier = this.#caravanExpedition?.travelModifierPermille(party.id) ?? 1000;
    const hour = (this.#clock.elapsedDays - Math.floor(this.#clock.elapsedDays)) * 24, visibilityPermille = hour < 6 || hour >= 20 ? 800 : 1000;
    return spatialSpeedKmPerDay(calculatePartyTravelSpeed(party.composition, this.#travelConfig) * characterModifier / 1000, this.#continuousSpace.config(), terrainKinds, burden, 1000, winter, visibilityPermille, mode);
  }

  #seedNavigationKnowledge(): void {
    for (const party of this.#parties.values()) for (const edgeId of [...party.knownRouteIds].sort()) {
      const edge = this.#graph.edgesById.get(edgeId)!;
      for (const nodeId of [edge.originNodeId, edge.targetNodeId].sort()) { const node = this.#graph.nodesById.get(nodeId)!; this.#worldMemory.ingest({ ingestId: `navigation-seed:${party.id}:node:${node.id}`, ownerId: party.id, ownerKind: "party", kind: "navigation_seed", observedAtElapsedDays: 0, knownAtElapsedDays: 0, staleAfterDays: null, provenance: { sourceType: "command_result", sourceId: "scenario_seed", sourceOwnerId: party.id, nodeId: node.id }, payload: { knowledgeId: `node:${node.id}`, knowledgeKind: "node", worldObjectId: node.id, estimatedPosition: node.position, uncertaintyCenter: null, uncertaintyRadiusKm: null, relation: "known_location", confidencePermille: 1000 } }); }
      this.#worldMemory.ingest({ ingestId: `navigation-seed:${party.id}:edge:${edge.id}`, ownerId: party.id, ownerKind: "party", kind: "navigation_seed", observedAtElapsedDays: 0, knownAtElapsedDays: 0, staleAfterDays: null, provenance: { sourceType: "command_result", sourceId: "scenario_seed", sourceOwnerId: party.id, nodeId: null }, payload: { knowledgeId: `edge:${edge.id}`, knowledgeKind: "edge", worldObjectId: edge.id, estimatedPosition: this.#graph.nodesById.get(edge.targetNodeId)!.position, uncertaintyCenter: null, uncertaintyRadiusKm: null, relation: `${edge.originNodeId}->${edge.targetNodeId}`, confidencePermille: 1000 } });
    }
  }

  #executeMoveParty(command: MovePartyCommand): CommandResult {
    const party = this.#parties.get(command.party_id);
    if (party === undefined) {
      return rejected("PARTY_NOT_FOUND", `Party ${command.party_id} does not exist.`);
    }
    if (!this.#graph.nodesById.has(command.from_node_id)) {
      return rejected("NODE_NOT_FOUND", `Origin node ${command.from_node_id} does not exist.`);
    }
    if (!this.#graph.nodesById.has(command.to_node_id)) {
      return rejected("NODE_NOT_FOUND", `Destination node ${command.to_node_id} does not exist.`);
    }
    if (party.location.status === "traveling" && "spatial" in party.location) return rejected("PARTY_BUSY", `Party ${party.id} is traveling off-road.`);
    if (party.location.status === "idle" && party.location.nodeId !== command.from_node_id) {
      return rejected(
        "ORIGIN_MISMATCH",
        `Party ${party.id} is at ${party.location.nodeId}, not ${command.from_node_id}.`,
      );
    }

    if (party.location.status === "traveling" && command.from_node_id !== party.location.originNodeId && command.from_node_id !== party.location.destinationNodeId) return rejected("ORIGIN_MISMATCH", `Party ${party.id} is not traveling from ${command.from_node_id}.`);
    const knownEdges = this.#knownRoadEdgeIds(party);
    const starts = party.location.status === "idle" ? [command.from_node_id] : [party.location.originNodeId, party.location.destinationNodeId];
    if (!starts.some((start) => shortestKnownRoute(this.#graph, knownEdges, start, command.to_node_id) !== null)) return getEdgeBetween(this.#graph, command.from_node_id, command.to_node_id) === undefined
      ? rejected("ROUTE_NOT_FOUND", `No known road route leads from ${command.from_node_id} to ${command.to_node_id}.`)
      : rejected("ROUTE_UNKNOWN", `Party ${party.id} does not know the route to ${command.to_node_id}.`);
    const previousGeneration = party.movementGeneration, previousOrder = party.movementOrder, previousPending = party.pendingMovementTickEventId, previousOrdinal = party.nextMovementTickOrdinal;
    party.movementGeneration += 1;
    party.movementOrder = { targetNodeId: command.to_node_id, generation: party.movementGeneration };
    party.pendingMovementTickEventId = null;
    try { this.#clock.schedule(this.#nextMovementTickIntent(party, this.#clock.elapsedDays + this.#travelConfig.movementTickDays)); }
    catch (error) { party.movementGeneration = previousGeneration; party.movementOrder = previousOrder; party.pendingMovementTickEventId = previousPending; party.nextMovementTickOrdinal = previousOrdinal; return rejected("SCHEDULING_FAILED", error instanceof Error ? error.message : String(error)); }
    return { accepted: true };
  }

  #knownRoadEdgeIds(party: PartyRuntimeState): ReadonlySet<string> {
    return new Set(this.navigationKnowledgeGraph(party.id, "party").edges.filter((item) => item.worldObjectId !== null && item.freshness === "fresh").map((item) => item.worldObjectId!));
  }

  #nextMovementTickIntent(party: PartyRuntimeState, dueElapsedDays: number): ScheduledEventIntent {
    const ordinal = party.nextMovementTickOrdinal++;
    const eventId = `party:${party.id}:movement:g${party.movementGeneration}:tick:${ordinal}`;
    party.pendingMovementTickEventId = eventId;
    return { eventId, kind: PARTY_MOVEMENT_TICK_DUE, dueElapsedDays, targetComponent: PARTY_MOVEMENT_COMPONENT, targetEntityId: party.id, payload: { generation: party.movementGeneration, ordinal } };
  }

  #handleMovementTick(intent: ScheduledEventIntent, elapsedDays: number): readonly ScheduledEventIntent[] {
    if (intent.kind !== PARTY_MOVEMENT_TICK_DUE || intent.targetComponent !== PARTY_MOVEMENT_COMPONENT) throw new WorldSimulationConfigurationError(`Unexpected movement event ${intent.eventId}.`);
    const payload = movementTickPayload(intent), party = this.#parties.get(intent.targetEntityId);
    if (party === undefined || payload.generation !== party.movementGeneration || party.pendingMovementTickEventId !== intent.eventId) return [];
    party.pendingMovementTickEventId = null;
    const order = party.movementOrder;
    if (order === null || order.generation !== payload.generation || this.#caravanExpedition?.isPaused(party.id) === true || party.composition.footCount + party.composition.horseCount + party.composition.packAnimalCount <= 0) return [];
    const knownEdges = this.#knownRoadEdgeIds(party);
    let remainingDays = this.#travelConfig.movementTickDays, movedKm = 0, movedDays = 0;
    while (remainingDays > 1e-12 && party.movementOrder !== null) {
      if (party.location.status === "idle") {
        if (party.location.nodeId === order.targetNodeId) { party.movementOrder = null; break; }
        if (party.location.nodeId === null || !this.#startNextRoadEdge(party, party.location.nodeId, order.targetNodeId, knownEdges)) { party.movementOrder = null; break; }
      } else if ("spatial" in party.location) return [];
      let travel = party.location as TravelingPartyState;
      this.#orientRoadTravel(party, order.targetNodeId, knownEdges);
      travel = party.location as TravelingPartyState;
      travel.speedKmPerDay = this.#roadSpeed(party, this.#graph.edgesById.get(travel.edgeId));
      const previousProgressKm = travel.progressKm, distance = Math.min(travel.speedKmPerDay * remainingDays, travel.distanceKm - travel.progressKm), duration = distance / travel.speedKmPerDay;
      travel.progressKm += distance; remainingDays -= duration; movedDays += duration; movedKm += distance;
      this.#observeRouteProgress(party, this.#graph.edgesById.get(travel.edgeId)!, travel.originNodeId, travel.destinationNodeId, previousProgressKm, travel.progressKm);
      if (travel.progressKm + 1e-9 < travel.distanceKm) break;
      const nodeId = travel.destinationNodeId;
      party.location = { status: "idle", nodeId, position: [...this.#graph.nodesById.get(nodeId)!.position] };
      this.#observeSignpostedLocalRoutes(party, nodeId);
      if (nodeId === order.targetNodeId) { party.movementOrder = null; break; }
    }
    this.#consumeTravelSupplies(party, movedDays);
    this.#caravanExpedition?.addTravelFatigue(party.id, movedKm);
    return party.movementOrder === null || this.#caravanExpedition?.isPaused(party.id) === true ? [] : [this.#nextMovementTickIntent(party, elapsedDays + this.#travelConfig.movementTickDays)];
  }

  #roadSpeed(party: PartyRuntimeState, edge: RegionGraphEdge | undefined): number {
    const position = createPartySnapshot(this.#graph, party, this.#economySeed).position;
    return this.#spatialSpeed(party, terrainAt(this.#graph, position).map((area) => area.kind), edge?.travelMode === "track" ? "track" : "road");
  }

  #startNextRoadEdge(party: PartyRuntimeState, nodeId: string, targetNodeId: string, knownEdges: ReadonlySet<string>): boolean {
    const route = shortestKnownRoute(this.#graph, knownEdges, nodeId, targetNodeId);
    if (route === null || route.length < 2) return false;
    const edge = getEdgeBetween(this.#graph, nodeId, route[1]!)!;
    party.location = { status: "traveling", edgeId: edge.id, originNodeId: nodeId, destinationNodeId: route[1]!, distanceKm: edge.distanceKm, speedKmPerDay: this.#roadSpeed(party, edge), progressKm: 0 };
    return true;
  }

  #orientRoadTravel(party: PartyRuntimeState, targetNodeId: string, knownEdges: ReadonlySet<string>): void {
    if (party.location.status !== "traveling" || "spatial" in party.location) return;
    const travel = party.location, forward = shortestKnownRoute(this.#graph, knownEdges, travel.destinationNodeId, targetNodeId), backward = shortestKnownRoute(this.#graph, knownEdges, travel.originNodeId, targetNodeId);
    const forwardCost = forward === null ? Infinity : travel.distanceKm - travel.progressKm + routeDistance(this.#graph, forward), backwardCost = backward === null ? Infinity : travel.progressKm + routeDistance(this.#graph, backward);
    if (backwardCost < forwardCost) party.location = { ...travel, originNodeId: travel.destinationNodeId, destinationNodeId: travel.originNodeId, progressKm: travel.distanceKm - travel.progressKm };
  }

  #consumeTravelSupplies(party: PartyRuntimeState, travelDays: number): void {
    if (this.#caravanExpedition === null || travelDays <= 0) return;
    const due = this.#caravanExpedition.accrueTravelSupplies(party.id, travelDays, party.composition.horseCount + party.composition.packAnimalCount > 0), foodAvailable = party.cargo.get("food") ?? 0, fodderAvailable = party.cargo.get("fodder") ?? 0, foodTaken = Math.min(foodAvailable, due.food), fodderTaken = Math.min(fodderAvailable, due.fodder);
    setQuantity(party.cargo, "food", foodAvailable - foodTaken); setQuantity(party.cargo, "fodder", fodderAvailable - fodderTaken);
    if (due.food + due.fodder > 0) this.#caravanExpedition.applySupplyCondition(party.id, foodTaken === due.food, fodderTaken === due.fodder);
  }

  #executeTransferGoods(command: TransferGoodsCommand): TransferGoodsResult {
    const economy = this.#economySeed;
    if (economy === null) {
      return rejectedTransfer("ECONOMY_NOT_CONFIGURED", "World economy is not configured.");
    }
    const party = this.#parties.get(command.party_id);
    if (party === undefined) {
      return rejectedTransfer("PARTY_NOT_FOUND", `Party ${command.party_id} does not exist.`);
    }
    const location = this.#locations.get(command.location_id);
    if (location === undefined) {
      return rejectedTransfer("LOCATION_NOT_FOUND", `Location ${command.location_id} does not exist.`);
    }
    const goods = economy.goodsCatalog.goodsById.get(command.goods_id);
    if (goods === undefined) {
      return rejectedTransfer("GOODS_NOT_FOUND", `Goods ${command.goods_id} does not exist.`);
    }
    if (!Number.isSafeInteger(command.amount) || command.amount <= 0) {
      return rejectedTransfer("INVALID_AMOUNT", "Transfer amount must be a positive safe integer.");
    }
    if (party.location.status !== "idle") {
      return rejectedTransfer("PARTY_BUSY", `Party ${party.id} is traveling.`);
    }
    if (party.location.nodeId !== location.nodeId) {
      return rejectedTransfer(
        "LOCATION_MISMATCH",
        `Party ${party.id} and location ${location.id} are not at the same node.`,
      );
    }

    const partyAmount = party.cargo.get(goods.id) ?? 0;
    const locationAmount = location.resources.get(goods.id) ?? 0;
    if (command.direction === "withdraw_from_location") {
      if (locationAmount < command.amount) {
        return rejectedTransfer(
          "INSUFFICIENT_LOCATION_GOODS",
          `Location ${location.id} has only ${locationAmount} ${goods.id}.`,
        );
      }
      const capacity = calculatePartyCargoCapacity(party.composition, economy.partyCargoConfig);
      const used = calculateCargoUsedBulk(party.cargo, economy.goodsCatalog);
      if (used + command.amount * goods.bulkPerUnit > capacity) {
        return rejectedTransfer(
          "PARTY_CAPACITY_EXCEEDED",
          `Party ${party.id} cargo would exceed capacity.`,
        );
      }
      party.cargo.set(goods.id, partyAmount + command.amount);
      location.resources.set(goods.id, locationAmount - command.amount);
    } else {
      if (partyAmount < command.amount) {
        return rejectedTransfer(
          "INSUFFICIENT_PARTY_GOODS",
          `Party ${party.id} carries only ${partyAmount} ${goods.id}.`,
        );
      }
      const storageCap = economy.locationEconomyConfig.profilesByLocationId
        .get(location.id)?.storageCaps[goods.id];
      if (storageCap === undefined || locationAmount + command.amount > storageCap) {
        return rejectedTransfer(
          "LOCATION_STORAGE_EXCEEDED",
          `Location ${location.id} cannot store ${locationAmount + command.amount} ${goods.id}.`,
        );
      }
      setQuantity(party.cargo, goods.id, partyAmount - command.amount);
      location.resources.set(goods.id, locationAmount + command.amount);
    }

    this.#runtimeEvents.push({
      eventType: "goods_transferred",
      elapsedDays: this.#clock.elapsedDays,
      partyId: party.id,
      managerActorId: party.managerActorId,
      locationId: location.id,
      locationManagerActorId: location.managerActorId,
      nodeId: location.nodeId,
      goodsId: goods.id,
      amount: command.amount,
      direction: command.direction,
      partyCargoAmount: party.cargo.get(goods.id) ?? 0,
      locationResourceAmount: location.resources.get(goods.id) ?? 0,
    });
    return { accepted: true };
  }

  #executePartyTradeHubTransfer(
    command: TransferPartyGoodsWithTradeHubCommand,
  ): TradeHubCommandResult {
    const foundation = this.#simulationFoundation;
    if (foundation === null) return tradeFoundationNotConfigured();
    const existing = foundation.preparePartyTradeHubTransfer(command);
    if (existing !== null) return existing;
    const economy = this.#economySeed;
    const party = this.#parties.get(command.partyId);
    const hubNodeId = foundation.tradeHubNodeId(command.hubId);
    let physicalFailure: string | null = null;
    if (economy === null) physicalFailure = "World economy is not configured.";
    else if (party === undefined) physicalFailure = `Party ${command.partyId} does not exist.`;
    else if (!economy.goodsCatalog.goodsById.has(command.goodsId)) {
      physicalFailure = `Goods ${command.goodsId} does not exist.`;
    } else if (!Number.isSafeInteger(command.amount) || command.amount <= 0) {
      physicalFailure = "TradeHub transfer amount must be a positive safe integer.";
    } else if (party.location.status !== "idle") {
      physicalFailure = `Party ${party.id} is traveling.`;
    } else if (hubNodeId === null) {
      physicalFailure = `TradeHub ${command.hubId} does not exist.`;
    } else if (party.location.nodeId !== hubNodeId) {
      physicalFailure = `Party ${party.id} is not at TradeHub ${command.hubId}.`;
    } else if (command.direction === "deposit"
      && (party.cargo.get(command.goodsId) ?? 0) < command.amount) {
      physicalFailure = `Party ${party.id} has insufficient ${command.goodsId}.`;
    } else if (command.direction === "withdraw") {
      const goods = economy.goodsCatalog.goodsById.get(command.goodsId)!;
      const used = calculateCargoUsedBulk(party.cargo, economy.goodsCatalog);
      const capacity = calculatePartyCargoCapacity(party.composition, economy.partyCargoConfig);
      if (used + command.amount * goods.bulkPerUnit > capacity) {
        physicalFailure = `Party ${party.id} cargo would exceed capacity.`;
      }
    }
    if (physicalFailure !== null) {
      return foundation.recordTradeHubPhysicalFailure(command, physicalFailure);
    }
    const mutation = foundation.executePreparedPartyTradeHubTransfer(command);
    if (!mutation.result.accepted) return mutation.result;
    const current = party!.cargo.get(command.goodsId) ?? 0;
    setQuantity(
      party!.cargo,
      command.goodsId,
      command.direction === "deposit" ? current - command.amount : current + command.amount,
    );
    return mutation.result;
  }

  advanceDays(days: number): void {
    if (this.#simulationFoundation !== null) {
      this.#simulationFoundation.advanceDays(days, (fromElapsedDays, toElapsedDays) => {
        this.#advanceLocationEconomyBetween(fromElapsedDays, toElapsedDays);
      }, () => this.#caravanExpedition?.snapshot().encounters.some((item) => item.status === "awaiting_decision") === true);
      return;
    }
    this.#clock.advanceDays(days, { maxEvents: 100_000, dispatch: (intent) => intent.targetComponent === PARTY_MOVEMENT_COMPONENT ? this.#handleMovementTick(intent, this.#clock.elapsedDays) : [], onTimeAdvanced: (fromElapsedDays, toElapsedDays) => this.#advanceLocationEconomyBetween(fromElapsedDays, toElapsedDays), shouldHalt: () => this.#caravanExpedition?.snapshot().encounters.some((item) => item.status === "awaiting_decision") === true });
  }

  movementTickDays(): number { return this.#travelConfig.movementTickDays; }

  #advanceLocationEconomyBetween(previousElapsedDays: number, currentElapsedDays: number): void {
    const elapsedFullDays = completedSimulationDays(currentElapsedDays)
      - completedSimulationDays(previousElapsedDays);
    if (elapsedFullDays > 0) this.#advanceLocationEconomy(elapsedFullDays);
  }

  #bindEncounterPort(): void {
    this.#simulationFoundation?.setEncounterPhysicalPort({ party: (id) => this.#encounterParty(id), apply: (mutation) => this.#applyEncounterMutation(mutation) });
  }

  #encounterParty(id: string): EncounterPartyView | null {
    const party = this.#parties.get(id); if (party === undefined) return null;
    const state = this.#simulationFoundation?.routeSecuritySnapshot()?.parties.find((item) => item.partyId === id);
    const capacity = this.#economySeed === null ? 0 : calculatePartyCargoCapacity(party.composition, this.#economySeed.partyCargoConfig);
    const used = this.#economySeed === null ? 0 : calculateCargoUsedBulk(party.cargo, this.#economySeed.goodsCatalog);
    return { partyId: id, travelingRouteId: party.location.status === "traveling" && !("spatial" in party.location) ? party.location.edgeId : null, composition: { ...party.composition }, cargo: Object.fromEntries(party.cargo), cargoFreeBulk: Math.max(0, capacity - used), conditionPermille: state?.conditionPermille ?? 1000, moralePermille: state?.moralePermille ?? 1000 };
  }

  #applyEncounterMutation(mutation: EncounterPhysicalMutation): boolean {
    const attacker = this.#parties.get(mutation.attackerPartyId), defender = this.#parties.get(mutation.defenderPartyId);
    if (attacker === undefined || defender === undefined || this.#economySeed === null) return false;
    for (const [goodsId, amount] of Object.entries(mutation.stolenCargo)) if (!Number.isSafeInteger(amount) || amount < 0 || (defender.cargo.get(goodsId) ?? 0) < amount) return false;
    const incoming = new Map(attacker.cargo); for (const [goodsId, amount] of Object.entries(mutation.stolenCargo)) setQuantity(incoming, goodsId, (incoming.get(goodsId) ?? 0) + amount);
    if (calculateCargoUsedBulk(incoming, this.#economySeed.goodsCatalog) > calculatePartyCargoCapacity(attacker.composition, this.#economySeed.partyCargoConfig)) return false;
    const casualtyTargets: readonly (readonly [PartyRuntimeState | undefined, number])[] = [[attacker, mutation.attackerCasualties], [defender, mutation.defenderCasualties], ...Object.entries(mutation.escortCasualties).map(([id, count]) => [this.#parties.get(id), count] as const)];
    if (casualtyTargets.some(([party, count]) => party === undefined || !Number.isSafeInteger(count) || count < 0 || count > party.composition.footCount + party.composition.horseCount + party.composition.guardCount)) return false;
    this.#delayMovement(defender, mutation.defenderDelayDays);
    for (const [goodsId, amount] of Object.entries(mutation.stolenCargo)) { setQuantity(defender.cargo, goodsId, (defender.cargo.get(goodsId) ?? 0) - amount); setQuantity(attacker.cargo, goodsId, (attacker.cargo.get(goodsId) ?? 0) + amount); }
    for (const [party, count] of casualtyTargets) if (party !== undefined) party.composition = applyCasualties(party.composition, count);
    return true;
  }

  #delayMovement(party: PartyRuntimeState, delayDays: number): void {
    if (party.movementOrder === null || delayDays <= 0) return;
    const previousGeneration = party.movementGeneration, previousOrder = party.movementOrder, previousPending = party.pendingMovementTickEventId, previousOrdinal = party.nextMovementTickOrdinal;
    party.movementGeneration += 1;
    party.movementOrder = { ...party.movementOrder, generation: party.movementGeneration };
    party.pendingMovementTickEventId = null;
    try { if (party.composition.footCount + party.composition.horseCount + party.composition.packAnimalCount > 0) this.#clock.schedule(this.#nextMovementTickIntent(party, this.#clock.elapsedDays + Math.max(delayDays, this.#travelConfig.movementTickDays))); }
    catch (error) { party.movementGeneration = previousGeneration; party.movementOrder = previousOrder; party.pendingMovementTickEventId = previousPending; party.nextMovementTickOrdinal = previousOrdinal; throw error; }
  }

  #ensureMovementTick(party: PartyRuntimeState | undefined): void {
    if (party === undefined || party.movementOrder === null || party.pendingMovementTickEventId !== null || this.#caravanExpedition?.isPaused(party.id) === true) return;
    this.#clock.schedule(this.#nextMovementTickIntent(party, this.#clock.elapsedDays + this.#travelConfig.movementTickDays));
  }

  reset(): void {
    if (this.#simulationFoundation === null) this.#clock.reset();
    else this.#simulationFoundation.reset();
    this.#parties = createParties(
      this.#graph,
      this.#partySeeds,
      this.#economySeed?.goodsCatalog ?? null,
    );
    this.#locations = createLocations(this.#graph, this.#economySeed);
    this.#runtimeEvents = [];
    this.#worldMemory = new WorldMemory(this.#initialWorldMemorySnapshot);
    this.#continuousSpace = new ContinuousSpace(this.#initialContinuousSpaceSnapshot);
    this.#caravanExpedition = this.#initialCaravanExpeditionSnapshot === null ? null : new CaravanExpeditions(this.#initialCaravanExpeditionSnapshot);
    this.#shortageObservationCursors.clear();
  }

  snapshot(): WorldSnapshot {
    return {
      clock: this.#clock.snapshot(),
      simulationFoundation: this.#simulationFoundation?.domainSnapshot() ?? null,
      parties: [...this.#parties.values()].map((party) =>
        createPartySnapshot(this.#graph, party, this.#economySeed)),
      locations: [...this.#locations.values()].map(createLocationSnapshot),
      runtimeEvents: this.#runtimeEvents.map(copyWorldSimulationEvent),
      worldMemory: this.#worldMemory.snapshot(),
      shortageObservationCursors: Object.fromEntries(this.#shortageObservationCursors),
      continuousSpace: this.#continuousSpace.snapshot(),
      caravanExpedition: this.#caravanExpedition?.snapshot() ?? null,
    };
  }

  #restoreRuntimeSnapshot(snapshot: WorldSnapshot): void {
    for (const source of snapshot.parties) {
      const party = this.#parties.get(source.id);
      if (party === undefined) throw new WorldSimulationConfigurationError(`Snapshot party ${source.id} is missing from seed.`);
      party.cargo.clear();
      party.composition = { ...source.composition };
      for (const [goodsId, amount] of Object.entries(source.cargo)) party.cargo.set(goodsId, amount);
      party.location = source.spatialTravel !== null
        ? { status: "traveling", spatial: true, journeyId: source.spatialTravel.journeyId, kind: source.spatialTravel.kind, origin: [...source.spatialTravel.origin], destination: [...source.spatialTravel.destination], path: source.spatialTravel.path.map((item) => [...item]), distanceKm: source.spatialTravel.distanceKm, speedKmPerDay: source.spatialTravel.speedKmPerDay, progressKm: source.spatialTravel.progressKm, targetWorldObjectId: source.spatialTravel.targetWorldObjectId }
        : source.travel === null
        ? { status: "idle", nodeId: source.currentNodeId, position: [...source.position] }
        : {
            status: "traveling",
            edgeId: source.travel.edgeId,
            originNodeId: source.travel.originNodeId,
            destinationNodeId: source.travel.destinationNodeId,
            distanceKm: source.travel.distanceKm,
            speedKmPerDay: source.travel.speedKmPerDay,
            progressKm: source.travel.progressKm,
          };
      party.movementOrder = source.movementOrder === null ? null : { ...source.movementOrder };
      party.movementGeneration = source.movementGeneration;
      party.nextMovementTickOrdinal = source.nextMovementTickOrdinal;
      party.pendingMovementTickEventId = source.pendingMovementTickEventId;
      party.observedWaypointIds.clear();
      for (const id of source.observedWaypointIds) party.observedWaypointIds.add(id);
      party.observedLandmarkIds.clear();
      for (const id of source.observedLandmarkIds) party.observedLandmarkIds.add(id);
    }
    const restoredLocations = new Map<string, LocationRuntimeState>();
    for (const source of snapshot.locations) {
      restoredLocations.set(source.id, {
        id: source.id,
        displayName: source.displayName,
        managerActorId: source.managerActorId,
        nodeId: source.nodeId,
        resources: new Map(Object.entries(source.resources)),
      });
    }
    this.#locations = restoredLocations;
    this.#runtimeEvents = snapshot.runtimeEvents.map(copyWorldSimulationEvent);
    this.#shortageObservationCursors.clear();
    const foundationEventCount = snapshot.simulationFoundation?.events.length ?? 0;
    for (const [actorId, cursor] of Object.entries(snapshot.shortageObservationCursors)) {
      if (!Number.isSafeInteger(cursor) || cursor < 0 || cursor > foundationEventCount) throw new WorldSimulationConfigurationError(`Invalid shortage cursor for ${actorId}.`);
      this.#shortageObservationCursors.set(actorId, cursor);
    }
  }

  #rememberTradeCommandResult(
    command: TransferTradeHubGoodsCommand | PlaceTradeHubOrderCommand | CancelTradeHubOrderCommand,
    result: TradeHubCommandResult,
  ): void {
    const accountParty = this.#parties.get(command.accountEntityId);
    const resultOwnerIsParty = accountParty?.managerActorId === command.issuerActorId;
    this.#worldMemory.ingest({
      ingestId: `trade-command:${command.commandId}:${result.accepted ? "accepted" : result.errorCode}`,
      ownerId: resultOwnerIsParty ? command.accountEntityId : command.issuerActorId,
      ownerKind: resultOwnerIsParty ? "party" : "actor",
      kind: "trade_command_result",
      observedAtElapsedDays: this.#clock.elapsedDays,
      knownAtElapsedDays: this.#clock.elapsedDays,
      staleAfterDays: null,
      provenance: {
        sourceType: "command_result",
        sourceId: command.commandId,
        sourceOwnerId: command.issuerActorId,
        nodeId: this.#simulationFoundation?.tradeHubNodeId(command.hubId) ?? null,
      },
      payload: {
        hubId: command.hubId,
        commandId: command.commandId,
        accepted: result.accepted,
        errorCode: result.accepted ? null : result.errorCode,
        orderId: "orderId" in command ? command.orderId : null,
      },
    });
  }

  partyMapSnapshot(partyId: string): PartyMapSnapshot {
    const party = this.#parties.get(partyId);
    if (party === undefined) {
      throw new WorldSimulationQueryError(`Party ${partyId} does not exist.`);
    }
    const localNodeId = party.location.status === "idle" ? party.location.nodeId : null;

    const knowledge = this.navigationKnowledgeGraph(party.id, "party"), knownEdgeIds = new Set(knowledge.edges.map((item) => item.worldObjectId).filter((item): item is string => item !== null));
    const knownEdges = this.#graph.edges.filter((edge) => knownEdgeIds.has(edge.id));
    const knownNodeIds = new Set<string>(knowledge.nodes.map((item) => item.worldObjectId).filter((item): item is string => item !== null));
    for (const edge of knownEdges) {
      knownNodeIds.add(edge.originNodeId);
      knownNodeIds.add(edge.targetNodeId);
    }
    if (party.location.status === "idle" && party.location.nodeId !== null) knownNodeIds.add(party.location.nodeId);
    else if (party.location.status === "traveling" && !("spatial" in party.location)) {
      knownNodeIds.add(party.location.originNodeId);
      knownNodeIds.add(party.location.destinationNodeId);
    }

    return {
      mode: "party",
      observerPartyId: partyId,
      region: {
        id: this.#graph.id,
        displayName: this.#graph.displayName,
        mapBounds: graphMapBounds(this.#graph),
        nodes: this.#graph.nodes
          .filter((node) => knownNodeIds.has(node.id))
          .map((node) => ({
            id: node.id,
            displayName: node.displayName,
            kind: node.kind,
            position: node.position,
          })),
        edges: knownEdges.map((edge) => ({
          id: edge.id,
          originNodeId: edge.originNodeId,
          targetNodeId: edge.targetNodeId,
          distanceKm: edge.distanceKm,
          kind: edge.kind,
          routeWaypoints: edge.routeWaypoints
            .filter((waypoint) => party.observedWaypointIds.has(waypoint.id))
            .map(copyRouteWaypoint),
        })),
        terrainAreas: [],
        landmarks: this.#graph.landmarks
          .filter((landmark) => party.observedLandmarkIds.has(landmark.id))
          .map(copyLandmark),
      },
      snapshot: {
        clock: this.#clock.snapshot(),
        parties: [createPartySnapshot(this.#graph, party, this.#economySeed)],
        locations: localNodeId !== null
          ? [...this.#locations.values()]
              .filter((location) => location.nodeId === localNodeId)
              .map(createLocationSnapshot)
          : [],
      },
      navigationKnowledge: {
        approximateAreas: [...knowledge.areas, ...knowledge.nodes, ...knowledge.landmarks].filter((item) => item.uncertainty !== null).map((item) => ({ knowledgeId: item.knowledgeId, center: [...item.uncertainty!.center], radiusKm: item.uncertainty!.radiusKm, confidencePermille: item.confidencePermille, freshness: item.freshness, provenanceEntryId: item.provenanceEntryId })),
        landmarkRelations: knowledge.relations.filter((item) => item.relation !== null).map((item) => ({ knowledgeId: item.knowledgeId, relation: item.relation!, confidencePermille: item.confidencePermille, freshness: item.freshness, provenanceEntryId: item.provenanceEntryId })),
      },
    };
  }

  #observeRouteProgress(
    party: PartyRuntimeState,
    edge: RegionGraphEdge,
    originNodeId: string,
    destinationNodeId: string,
    previousProgressKm: number,
    progressKm: number,
  ): void {
    for (const waypoint of edge.routeWaypoints) {
      const distanceFromOrigin = edge.originNodeId === originNodeId ? waypoint.distanceFromStartKm : edge.distanceKm - waypoint.distanceFromStartKm;
      if (distanceFromOrigin <= previousProgressKm + 1e-9 || distanceFromOrigin > progressKm + 1e-9) continue;
      if (party.observedWaypointIds.has(waypoint.id)) continue;
      party.observedWaypointIds.add(waypoint.id);
      for (const landmarkId of waypoint.landmarkIds) party.observedLandmarkIds.add(landmarkId);
      this.#runtimeEvents.push({
        eventType: "worldsim_route_waypoint_observed",
        elapsedDays: this.#clock.elapsedDays,
        ownerPartyId: party.id,
        edgeId: edge.id,
        originNodeId,
        destinationNodeId,
        waypointId: waypoint.id,
        waypointKind: waypoint.kind,
        distanceFromStartKm: waypoint.distanceFromStartKm,
        elevationM: waypoint.elevationM,
        terrainAreaIds: [...waypoint.terrainAreaIds],
        landmarkIds: [...waypoint.landmarkIds],
        landmarkTags: [...waypoint.landmarkTags],
      });
    }
  }

  #observeSignpostedLocalRoutes(party: PartyRuntimeState, nodeId: string): void {
    const elapsed = this.#clock.elapsedDays;
    const adjacentEdges = this.#graph.edges
      .filter((edge) => edge.visibility === "public" && (edge.originNodeId === nodeId || edge.targetNodeId === nodeId))
      .sort((left, right) => left.id.localeCompare(right.id));
    for (const edge of adjacentEdges) {
      for (const endpointId of [edge.originNodeId, edge.targetNodeId].sort()) {
        const endpoint = this.#graph.nodesById.get(endpointId)!;
        this.#worldMemory.ingest({ ingestId: `arrival-signpost:${party.id}:${nodeId}:node:${endpointId}`, ownerId: party.id, ownerKind: "party", kind: "navigation_discovery", observedAtElapsedDays: elapsed, knownAtElapsedDays: elapsed, staleAfterDays: null, provenance: { sourceType: "direct_observation", sourceId: `signpost:${nodeId}`, sourceOwnerId: null, nodeId }, payload: { knowledgeId: `node:${endpointId}`, knowledgeKind: "node", worldObjectId: endpointId, estimatedPosition: endpoint.position, uncertaintyCenter: null, uncertaintyRadiusKm: null, relation: `signposted_from:${nodeId}`, confidencePermille: 900 } });
      }
      const otherNodeId = edge.originNodeId === nodeId ? edge.targetNodeId : edge.originNodeId;
      this.#worldMemory.ingest({ ingestId: `arrival-signpost:${party.id}:${nodeId}:edge:${edge.id}`, ownerId: party.id, ownerKind: "party", kind: "navigation_discovery", observedAtElapsedDays: elapsed, knownAtElapsedDays: elapsed, staleAfterDays: null, provenance: { sourceType: "direct_observation", sourceId: `signpost:${nodeId}`, sourceOwnerId: null, nodeId }, payload: { knowledgeId: `edge:${edge.id}`, knowledgeKind: "edge", worldObjectId: edge.id, estimatedPosition: this.#graph.nodesById.get(otherNodeId)!.position, uncertaintyCenter: null, uncertaintyRadiusKm: null, relation: `${edge.originNodeId}->${edge.targetNodeId}`, confidencePermille: 900 } });
    }
  }

  #advanceLocationEconomy(elapsedFullDays: number): void {
    const economy = this.#economySeed;
    if (economy === null) return;
    for (const location of this.#locations.values()) {
      const profile = economy.locationEconomyConfig.profilesByLocationId.get(location.id);
      if (profile === undefined) {
        throw new WorldSimulationConfigurationError(
          `Location ${location.id} has no economy profile.`,
        );
      }
      const before = new Map(location.resources);
      for (let day = 0; day < elapsedFullDays; day += 1) {
        for (const [goodsId, amount] of Object.entries(profile.consumptionPerDay)) {
          location.resources.set(goodsId, Math.max(0, (location.resources.get(goodsId) ?? 0) - amount));
        }
        for (const [goodsId, amount] of Object.entries(profile.productionPerDay)) {
          const cap = profile.storageCaps[goodsId];
          if (cap === undefined) {
            throw new WorldSimulationConfigurationError(
              `Location ${location.id} production ${goodsId} has no storage cap.`,
            );
          }
          location.resources.set(goodsId, Math.min(cap, (location.resources.get(goodsId) ?? 0) + amount));
        }
      }
      const resourceChanges: Record<string, number> = {};
      for (const goodsId of new Set([...before.keys(), ...location.resources.keys()])) {
        const change = (location.resources.get(goodsId) ?? 0) - (before.get(goodsId) ?? 0);
        if (change !== 0) resourceChanges[goodsId] = change;
      }
      if (Object.keys(resourceChanges).length > 0) {
        this.#runtimeEvents.push({
          eventType: "location_economy_ticked",
          elapsedDays: this.#clock.elapsedDays,
          locationId: location.id,
          managerActorId: location.managerActorId,
          elapsedFullDays,
          resourceChanges,
        });
      }
    }
  }
}

function graphMapBounds(graph: RegionGraph): { readonly minimum: Vec2; readonly maximum: Vec2 } {
  const xs = graph.nodes.map((node) => node.position[0]), ys = graph.nodes.map((node) => node.position[1]);
  return { minimum: [Math.min(...xs), Math.min(...ys)], maximum: [Math.max(...xs), Math.max(...ys)] };
}

function shortestKnownRoute(graph: RegionGraph, knownEdgeIds: ReadonlySet<string>, start: string, target: string): string[] | null {
  const distances = new Map<string, number>([[start, 0]]), previous = new Map<string, string>(), pending = new Set<string>([start]);
  while (pending.size > 0) {
    const node = [...pending].sort((a, b) => (distances.get(a)! - distances.get(b)!) || a.localeCompare(b))[0]!;
    pending.delete(node);
    if (node === target) break;
    for (const edge of graph.edges.filter((item) => knownEdgeIds.has(item.id) && (item.originNodeId === node || item.targetNodeId === node))) {
      const next = edge.originNodeId === node ? edge.targetNodeId : edge.originNodeId, candidate = distances.get(node)! + edge.distanceKm;
      if (candidate >= (distances.get(next) ?? Infinity)) continue;
      distances.set(next, candidate); previous.set(next, node); pending.add(next);
    }
  }
  if (!distances.has(target)) return null;
  const route = [target];
  while (route[0] !== start) route.unshift(previous.get(route[0]!)!);
  return route;
}

function routeDistance(graph: RegionGraph, nodeIds: readonly string[]): number {
  let total = 0;
  for (let index = 1; index < nodeIds.length; index += 1) total += getEdgeBetween(graph, nodeIds[index - 1]!, nodeIds[index]!)!.distanceKm;
  return total;
}

function copyPartySeed(seed: PartySeed): PartySeed {
  return {
    ...seed,
    composition: { ...seed.composition },
    knownRouteIds: [...seed.knownRouteIds],
    cargo: { ...seed.cargo },
  };
}

function copyWorldEconomySeed(seed: WorldEconomySeed): WorldEconomySeed {
  const goods = seed.goodsCatalog.goods.map((item) => ({ ...item, tags: [...item.tags] }));
  const profiles = seed.locationEconomyConfig.profiles.map((profile) => ({
    locationId: profile.locationId,
    productionPerDay: { ...profile.productionPerDay },
    consumptionPerDay: { ...profile.consumptionPerDay },
    storageCaps: { ...profile.storageCaps },
  }));
  return {
    goodsCatalog: {
      goods,
      goodsById: new Map(goods.map((item) => [item.id, item])),
    },
    partyCargoConfig: { ...seed.partyCargoConfig },
    locationEconomyConfig: {
      profiles,
      profilesByLocationId: new Map(profiles.map((profile) => [profile.locationId, profile])),
    },
    locations: seed.locations.map((location) => ({
      ...location,
      resources: { ...location.resources },
    })),
  };
}

function createParties(
  graph: RegionGraph,
  partySeeds: readonly PartySeed[],
  goodsCatalog: GoodsCatalog | null,
): Map<string, PartyRuntimeState> {
  const parties = new Map<string, PartyRuntimeState>();
  for (const seed of partySeeds) {
    if (seed.id.length === 0) {
      throw new WorldSimulationConfigurationError("Party id must not be empty.");
    }
    if (seed.displayName.length === 0 || seed.managerActorId.length === 0) {
      throw new WorldSimulationConfigurationError(
        `Party ${seed.id} display name and manager actor id must not be empty.`,
      );
    }
    if (parties.has(seed.id)) {
      throw new WorldSimulationConfigurationError(`Party id is duplicated: ${seed.id}.`);
    }
    if (!graph.nodesById.has(seed.nodeId)) {
      throw new WorldSimulationConfigurationError(
        `Party ${seed.id} references missing node ${seed.nodeId}.`,
      );
    }
    for (const routeId of seed.knownRouteIds) {
      if (!graph.edgesById.has(routeId)) {
        throw new WorldSimulationConfigurationError(
          `Party ${seed.id} knows missing route ${routeId}.`,
        );
      }
    }
    validatePartyComposition(seed.id, seed.composition);
    const cargo = createGoodsStore(seed.cargo, goodsCatalog, `Party ${seed.id} cargo`);
    parties.set(seed.id, {
      id: seed.id,
      displayName: seed.displayName,
      managerActorId: seed.managerActorId,
      seedNodeId: seed.nodeId,
      composition: { ...seed.composition },
      cargo,
      knownRouteIds: new Set(seed.knownRouteIds),
      observedWaypointIds: new Set(),
      observedLandmarkIds: new Set(),
      location: { status: "idle", nodeId: seed.nodeId, position: [...graph.nodesById.get(seed.nodeId)!.position] },
      movementOrder: null,
      movementGeneration: 0,
      nextMovementTickOrdinal: 0,
      pendingMovementTickEventId: null,
    });
  }
  return parties;
}

function createLocations(
  graph: RegionGraph,
  economySeed: WorldEconomySeed | null,
): Map<string, LocationRuntimeState> {
  const locations = new Map<string, LocationRuntimeState>();
  if (economySeed === null) return locations;
  for (const seed of economySeed.locations) {
    if (seed.id.length === 0) {
      throw new WorldSimulationConfigurationError("Location id must not be empty.");
    }
    if (locations.has(seed.id)) {
      throw new WorldSimulationConfigurationError(`Location id is duplicated: ${seed.id}.`);
    }
    if (!graph.nodesById.has(seed.nodeId)) {
      throw new WorldSimulationConfigurationError(
        `Location ${seed.id} references missing node ${seed.nodeId}.`,
      );
    }
    if (seed.displayName.length === 0 || seed.managerActorId.length === 0) {
      throw new WorldSimulationConfigurationError(
        `Location ${seed.id} display name and manager actor id must not be empty.`,
      );
    }
    const profile = economySeed.locationEconomyConfig.profilesByLocationId.get(seed.id);
    if (profile === undefined) {
      throw new WorldSimulationConfigurationError(`Location ${seed.id} has no economy profile.`);
    }
    locations.set(seed.id, {
      id: seed.id,
      displayName: seed.displayName,
      managerActorId: seed.managerActorId,
      nodeId: seed.nodeId,
      resources: createGoodsStore(
        seed.resources,
        economySeed.goodsCatalog,
        `Location ${seed.id} resources`,
      ),
    });
    for (const [goodsId, amount] of Object.entries(seed.resources)) {
      const cap = profile.storageCaps[goodsId];
      if (cap === undefined || amount > cap) {
        throw new WorldSimulationConfigurationError(
          `Location ${seed.id} initial ${goodsId} amount ${amount} exceeds or lacks its storage cap.`,
        );
      }
    }
  }
  for (const profile of economySeed.locationEconomyConfig.profiles) {
    if (!locations.has(profile.locationId)) {
      throw new WorldSimulationConfigurationError(
        `Economy profile ${profile.locationId} has no location seed.`,
      );
    }
  }
  return locations;
}

function createGoodsStore(
  quantities: Readonly<Record<string, number>>,
  goodsCatalog: GoodsCatalog | null,
  label: string,
): Map<string, number> {
  const store = new Map<string, number>();
  for (const [goodsId, amount] of Object.entries(quantities)) {
    if (goodsCatalog === null || !goodsCatalog.goodsById.has(goodsId)) {
      throw new WorldSimulationConfigurationError(`${label} references unknown goods ${goodsId}.`);
    }
    if (!Number.isSafeInteger(amount) || amount < 0) {
      throw new WorldSimulationConfigurationError(
        `${label} ${goodsId} must be a non-negative safe integer.`,
      );
    }
    if (amount > 0) store.set(goodsId, amount);
  }
  return store;
}

function validateInitialCargoCapacities(
  parties: ReadonlyMap<string, PartyRuntimeState>,
  economySeed: WorldEconomySeed | null,
): void {
  if (economySeed === null) return;
  for (const party of parties.values()) {
    const capacity = calculatePartyCargoCapacity(party.composition, economySeed.partyCargoConfig);
    const used = calculateCargoUsedBulk(party.cargo, economySeed.goodsCatalog);
    if (used > capacity) {
      throw new WorldSimulationConfigurationError(
        `Party ${party.id} initial cargo uses ${used} bulk but capacity is ${capacity}.`,
      );
    }
  }
}

function copyRouteWaypoint(waypoint: RegionRouteWaypoint): RegionRouteWaypoint {
  return {
    ...waypoint,
    position: [...waypoint.position],
    terrainAreaIds: [...waypoint.terrainAreaIds],
    landmarkIds: [...waypoint.landmarkIds],
    landmarkTags: [...waypoint.landmarkTags],
  };
}

function copyLandmark(landmark: RegionLandmark): RegionLandmark {
  return { ...landmark, position: [...landmark.position] };
}

function copyWorldSimulationEvent(event: WorldSimulationEvent): WorldSimulationEvent {
  if (event.eventType === "worldsim_route_waypoint_observed") {
    return {
      ...event,
      terrainAreaIds: [...event.terrainAreaIds],
      landmarkIds: [...event.landmarkIds],
      landmarkTags: [...event.landmarkTags],
    };
  }
  if (event.eventType === "location_economy_ticked") {
    return { ...event, resourceChanges: { ...event.resourceChanges } };
  }
  return { ...event };
}

function validatePartyComposition(partyId: string, composition: PartyComposition): void {
  const counts: ReadonlyArray<readonly [string, number]> = [
    ["footCount", composition.footCount],
    ["horseCount", composition.horseCount],
    ["wagonCount", composition.wagonCount],
    ["packAnimalCount", composition.packAnimalCount],
    ["guardCount", composition.guardCount],
  ];
  for (const [fieldName, count] of counts) {
    if (!Number.isSafeInteger(count) || count < 0) {
      throw new WorldSimulationConfigurationError(
        `Party ${partyId} composition ${fieldName} must be a non-negative safe integer.`,
      );
    }
  }
}

function applyCasualties(composition: PartyComposition, casualties: number): PartyComposition {
  let remaining = casualties;
  const guardLoss = Math.min(composition.guardCount, remaining); remaining -= guardLoss;
  const footLoss = Math.min(composition.footCount, remaining); remaining -= footLoss;
  const horseLoss = Math.min(composition.horseCount, remaining);
  return { ...composition, guardCount: composition.guardCount - guardLoss, footCount: composition.footCount - footLoss, horseCount: composition.horseCount - horseLoss };
}

function applyCharacterCasualties(composition: PartyComposition, casualties: number): PartyComposition {
  return { ...composition, footCount: Math.max(0, composition.footCount - casualties), guardCount: Math.max(0, composition.guardCount - Math.min(composition.guardCount, casualties)) };
}

function securityRejected(errorCode: Extract<SecurityCommandResult, { accepted: false }>["errorCode"], message: string): SecurityCommandResult {
  return { accepted: false, idempotentReplay: false, errorCode, message };
}

function securityUnavailable(): SecurityCommandResult { return securityRejected("INVALID_COMMAND", "RouteSecurity is not configured."); }

function spatialRejected(errorCode: Extract<SpatialCommandResult, { accepted: false }>["errorCode"], message: string): SpatialCommandResult { return { accepted: false, idempotentReplay: false, errorCode, message }; }

function distortedReportCenter(center: Vec2, radiusKm: number, distortionPermille: number, key: string, coordinateKmScale: number): Vec2 {
  if (distortionPermille <= 0) return [...center];
  let hash = 2166136261;
  for (let index = 0; index < key.length; index += 1) { hash ^= key.charCodeAt(index); hash = Math.imul(hash, 16777619); }
  const angle = ((hash >>> 0) % 3600) / 3600 * Math.PI * 2, offsetCoordinateUnits = radiusKm * Math.min(1000, distortionPermille) / 1000 / coordinateKmScale;
  return [center[0] + Math.cos(angle) * offsetCoordinateUnits, center[1] + Math.sin(angle) * offsetCoordinateUnits];
}

function defaultSpatialConfig() { return { coordinateKmScale: 5, roadSpeedPermille: 1200, trackSpeedPermille: 850, terrainSpeedPermille: { forest: 650, hills: 700, river_valley: 900 }, burdenSpeedFloorPermille: 500, winterSpeedPermille: 800, nightVisibilityPermille: 500, baseVisibilityKm: 3, maxSearchSteps: 12 }; }

function readSpatialPlan(intent: ScheduledEventIntent): SpatialTravelPlan | SpatialSearchPlan {
  if (intent.payload === null || Array.isArray(intent.payload) || typeof intent.payload !== "object") throw new WorldSimulationConfigurationError(`Spatial event ${intent.eventId} payload is invalid.`);
  const plan = (intent.payload as Record<string, SerializableValue>).plan;
  if (plan === null || Array.isArray(plan) || typeof plan !== "object") throw new WorldSimulationConfigurationError(`Spatial event ${intent.eventId} plan is invalid.`);
  const value = plan as Record<string, SerializableValue>;
  if (typeof value.commandId !== "string" || typeof value.partyId !== "string" || typeof value.distanceKm !== "number" || !Number.isFinite(value.distanceKm)) throw new WorldSimulationConfigurationError(`Spatial event ${intent.eventId} plan fields are invalid.`);
  return structuredClone(plan) as unknown as SpatialTravelPlan | SpatialSearchPlan;
}

function movementTickPayload(intent: ScheduledEventIntent): { readonly generation: number; readonly ordinal: number } {
  if (intent.payload === null || Array.isArray(intent.payload) || typeof intent.payload !== "object") throw new WorldSimulationConfigurationError(`Movement event ${intent.eventId} payload is invalid.`);
  const { generation, ordinal } = intent.payload as Record<string, SerializableValue>;
  if (!Number.isSafeInteger(generation) || (generation as number) < 0 || !Number.isSafeInteger(ordinal) || (ordinal as number) < 0) throw new WorldSimulationConfigurationError(`Movement event ${intent.eventId} payload fields are invalid.`);
  return { generation: generation as number, ordinal: ordinal as number };
}

function createPartySnapshot(
  graph: RegionGraph,
  party: PartyRuntimeState,
  economySeed: WorldEconomySeed | null,
): PartySnapshot {
  const economyCargo = createPartyCargoSnapshot(party, economySeed);
  if (party.location.status === "idle") {
    const node = party.location.nodeId === null ? null : graph.nodesById.get(party.location.nodeId);
    if (party.location.nodeId !== null && node === undefined) throw new WorldSimulationConfigurationError(`Party ${party.id} is at missing node ${party.location.nodeId}.`);
    return {
      id: party.id,
      displayName: party.displayName,
      managerActorId: party.managerActorId,
      seedNodeId: party.seedNodeId,
      status: "idle",
      currentNodeId: node?.id ?? null,
      position: [...party.location.position],
      composition: { ...party.composition },
      knownRouteIds: [...party.knownRouteIds],
      observedWaypointIds: [...party.observedWaypointIds].sort(),
      observedLandmarkIds: [...party.observedLandmarkIds].sort(),
      ...economyCargo,
      travel: null,
      spatialTravel: null,
      movementOrder: party.movementOrder === null ? null : { ...party.movementOrder },
      movementGeneration: party.movementGeneration,
      nextMovementTickOrdinal: party.nextMovementTickOrdinal,
      pendingMovementTickEventId: party.pendingMovementTickEventId,
    };
  }

  const travel = party.location;
  if ("spatial" in travel) {
    const ratio = travel.distanceKm === 0 ? 1 : travel.progressKm / travel.distanceKm;
    return { id: party.id, displayName: party.displayName, managerActorId: party.managerActorId, seedNodeId: party.seedNodeId, status: "traveling", currentNodeId: null, position: pointAlongPolyline(travel.path, ratio * polylineDistance(travel.path)), composition: { ...party.composition }, knownRouteIds: [...party.knownRouteIds], observedWaypointIds: [...party.observedWaypointIds].sort(), observedLandmarkIds: [...party.observedLandmarkIds].sort(), ...economyCargo, travel: null, spatialTravel: { journeyId: travel.journeyId, kind: travel.kind, origin: [...travel.origin], destination: [...travel.destination], path: travel.path.map((item) => [...item]), distanceKm: travel.distanceKm, progressKm: travel.progressKm, speedKmPerDay: travel.speedKmPerDay, targetWorldObjectId: travel.targetWorldObjectId }, movementOrder: party.movementOrder === null ? null : { ...party.movementOrder }, movementGeneration: party.movementGeneration, nextMovementTickOrdinal: party.nextMovementTickOrdinal, pendingMovementTickEventId: party.pendingMovementTickEventId };
  }
  const edge = graph.edgesById.get(travel.edgeId);
  if (edge === undefined) {
    throw new WorldSimulationConfigurationError(
      `Party ${party.id} is traveling on missing route ${travel.edgeId}.`,
    );
  }
  return {
    id: party.id,
    displayName: party.displayName,
    managerActorId: party.managerActorId,
    seedNodeId: party.seedNodeId,
    status: "traveling",
    currentNodeId: null,
    position: interpolateTravelPosition(graph, edge, travel),
    composition: { ...party.composition },
    knownRouteIds: [...party.knownRouteIds],
    observedWaypointIds: [...party.observedWaypointIds].sort(),
    observedLandmarkIds: [...party.observedLandmarkIds].sort(),
    ...economyCargo,
    travel: {
      edgeId: travel.edgeId,
      originNodeId: travel.originNodeId,
      destinationNodeId: travel.destinationNodeId,
      distanceKm: travel.distanceKm,
      progressKm: travel.progressKm,
      speedKmPerDay: travel.speedKmPerDay,
    },
    spatialTravel: null,
    movementOrder: party.movementOrder === null ? null : { ...party.movementOrder },
    movementGeneration: party.movementGeneration,
    nextMovementTickOrdinal: party.nextMovementTickOrdinal,
    pendingMovementTickEventId: party.pendingMovementTickEventId,
  };
}

function createPartyCargoSnapshot(
  party: PartyRuntimeState,
  economySeed: WorldEconomySeed | null,
): Pick<PartySnapshot, "cargo" | "cargoCapacityBulk" | "cargoUsedBulk"> {
  if (economySeed === null) {
    return { cargo: {}, cargoCapacityBulk: null, cargoUsedBulk: null };
  }
  return {
    cargo: Object.fromEntries(party.cargo),
    cargoCapacityBulk: calculatePartyCargoCapacity(party.composition, economySeed.partyCargoConfig),
    cargoUsedBulk: calculateCargoUsedBulk(party.cargo, economySeed.goodsCatalog),
  };
}

function createLocationSnapshot(location: LocationRuntimeState): LocationSnapshot {
  return {
    id: location.id,
    displayName: location.displayName,
    managerActorId: location.managerActorId,
    nodeId: location.nodeId,
    resources: Object.fromEntries(location.resources),
  };
}

function interpolateTravelPosition(
  graph: RegionGraph,
  edge: RegionGraphEdge,
  travel: TravelingPartyState,
): Vec2 {
  const origin = graph.nodesById.get(travel.originNodeId);
  const destination = graph.nodesById.get(travel.destinationNodeId);
  if (origin === undefined || destination === undefined) {
    throw new WorldSimulationConfigurationError(
      `Route ${edge.id} travel endpoints are missing from graph ${graph.id}.`,
    );
  }

  const followsAuthoredDirection = edge.originNodeId === travel.originNodeId;
  const routeAnchors = followsAuthoredDirection
    ? edge.routeWaypoints.map((waypoint) => ({
        distanceKm: waypoint.distanceFromStartKm,
        position: waypoint.position,
      }))
    : [...edge.routeWaypoints].reverse().map((waypoint) => ({
        distanceKm: edge.distanceKm - waypoint.distanceFromStartKm,
        position: waypoint.position,
      }));
  const anchors = [
    { distanceKm: 0, position: origin.position },
    ...routeAnchors,
    { distanceKm: edge.distanceKm, position: destination.position },
  ];

  for (let index = 1; index < anchors.length; index += 1) {
    const previous = anchors[index - 1];
    const next = anchors[index];
    if (previous === undefined || next === undefined) continue;
    if (travel.progressKm > next.distanceKm) continue;
    const segmentDistance = next.distanceKm - previous.distanceKm;
    const segmentProgress = segmentDistance === 0
      ? 1
      : (travel.progressKm - previous.distanceKm) / segmentDistance;
    return [
      previous.position[0] + (next.position[0] - previous.position[0]) * segmentProgress,
      previous.position[1] + (next.position[1] - previous.position[1]) * segmentProgress,
    ];
  }
  return destination.position;
}

function rejected(errorCode: MovePartyErrorCode, message: string): CommandResult {
  return { accepted: false, errorCode, message };
}

function rejectedTransfer(
  errorCode: TransferGoodsErrorCode,
  message: string,
): TransferGoodsResult {
  return { accepted: false, errorCode, message };
}

function supplyRejected(
  errorCode: Extract<SupplyCommandResult, { readonly accepted: false }>["errorCode"],
  message: string,
): SupplyCommandResult {
  return { accepted: false, errorCode, message };
}

function shortageMemoryIngest(
  governorActorId: string,
  facility: { readonly facilityId: string; readonly hostId: string; readonly ownerId: string },
  goodsId: string,
  scheduledEventId: string,
  observedAtElapsedDays: number,
  knownAtElapsedDays: number,
  staleAfterDays: number,
  kind: "shortage_observation" | "shortage_recovered",
  consequenceTypes: readonly string[],
  amount: number,
): WorldMemoryIngest {
  return {
    ingestId: `shortage:${governorActorId}:${scheduledEventId}:${goodsId}:${kind}`,
    ownerId: governorActorId,
    ownerKind: "actor",
    kind,
    observedAtElapsedDays,
    knownAtElapsedDays,
    staleAfterDays,
    provenance: { sourceType: "direct_observation", sourceId: scheduledEventId, sourceOwnerId: facility.ownerId, nodeId: null },
    payload: { facilityId: facility.facilityId, facilityHostId: facility.hostId, goodsId, amount, consequenceTypes },
  };
}

function requireRestoredNode(source: PartySnapshot): string {
  if (source.currentNodeId === null) {
    throw new WorldSimulationConfigurationError(`Idle snapshot party ${source.id} has no node.`);
  }
  return source.currentNodeId;
}

function tradeFoundationNotConfigured(): TradeHubCommandResult {
  return {
    accepted: false,
    idempotentReplay: false,
    errorCode: "TRADE_FOUNDATION_NOT_CONFIGURED",
    message: "TradeHub foundation is not configured.",
  };
}

function populationUnavailable(): PopulationCommandResult {
  return { accepted: false, idempotentReplay: false, errorCode: "INVALID_COMMAND", message: "PopulationDynamics is not configured." };
}

function calculatePartyCargoCapacity(
  composition: PartyComposition,
  config: PartyCargoConfig,
): number {
  return composition.footCount * config.footCapacityBulk
    + composition.horseCount * config.horseCapacityBulk
    + composition.packAnimalCount * config.packAnimalCapacityBulk
    + composition.wagonCount * config.wagonCapacityBulk;
}

function calculateCargoUsedBulk(
  cargo: ReadonlyMap<string, number>,
  goodsCatalog: GoodsCatalog,
): number {
  let usedBulk = 0;
  for (const [goodsId, amount] of cargo) {
    const goods = goodsCatalog.goodsById.get(goodsId);
    if (goods === undefined) {
      throw new WorldSimulationConfigurationError(`Cargo references unknown goods ${goodsId}.`);
    }
    usedBulk += amount * goods.bulkPerUnit;
  }
  return usedBulk;
}

function setQuantity(store: Map<string, number>, id: string, amount: number): void {
  if (amount === 0) store.delete(id);
  else store.set(id, amount);
}

function completedSimulationDays(elapsedDays: number): number {
  return Math.floor(elapsedDays + 1e-9);
}

function requirePositiveNumber(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
    throw new PartyTravelConfigValidationError(`${fieldName} must be a finite positive number.`);
  }
  return value;
}

function requireNonNegativeNumber(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    throw new PartyTravelConfigValidationError(`${fieldName} must be a finite non-negative number.`);
  }
  return value;
}
