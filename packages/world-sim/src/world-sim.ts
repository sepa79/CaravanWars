import { readFileSync } from "node:fs";

import { getEdgeBetween } from "./region-graph.js";
import type {
  RegionGraph,
  RegionGraphEdge,
  RegionLandmark,
  RegionRouteWaypoint,
  Vec2,
} from "./region-graph.js";
import { WorldClock } from "./world-clock.js";
import { Facilities } from "./facilities.js";
import { Governance } from "./governance.js";
import { TradeHubs } from "./trade-hubs.js";
import type { WorldClockSnapshot } from "./world-clock.js";
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
  | "ROUTE_UNKNOWN";

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
  | { readonly commandType: "report_supply_task"; readonly command: ReportSupplyTaskCommand };

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
  | { readonly commandType: "report_supply_task"; readonly result: SupplyCommandResult };

export interface PartyTravelSnapshot {
  readonly edgeId: string;
  readonly originNodeId: string;
  readonly destinationNodeId: string;
  readonly distanceKm: number;
  readonly progressKm: number;
  readonly speedKmPerDay: number;
}

export interface PartySnapshot {
  readonly id: string;
  readonly displayName: string;
  readonly managerActorId: string;
  readonly status: "idle" | "traveling";
  readonly currentNodeId: string | null;
  readonly position: Vec2;
  readonly composition: PartyComposition;
  readonly knownRouteIds: readonly string[];
  readonly observedWaypointIds: readonly string[];
  readonly observedLandmarkIds: readonly string[];
  readonly cargo: Readonly<Record<string, number>>;
  readonly cargoCapacityBulk: number | null;
  readonly cargoUsedBulk: number | null;
  readonly travel: PartyTravelSnapshot | null;
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
}

interface IdlePartyState {
  readonly status: "idle";
  readonly nodeId: string;
}

interface TravelingPartyState {
  readonly status: "traveling";
  readonly edgeId: string;
  readonly originNodeId: string;
  readonly destinationNodeId: string;
  readonly distanceKm: number;
  readonly speedKmPerDay: number;
  progressKm: number;
}

type PartyLocationState = IdlePartyState | TravelingPartyState;

interface PartyRuntimeState {
  readonly id: string;
  readonly displayName: string;
  readonly managerActorId: string;
  readonly composition: PartyComposition;
  readonly cargo: Map<string, number>;
  readonly knownRouteIds: ReadonlySet<string>;
  readonly observedWaypointIds: Set<string>;
  readonly observedLandmarkIds: Set<string>;
  location: PartyLocationState;
}

interface LocationRuntimeState {
  readonly id: string;
  readonly displayName: string;
  readonly managerActorId: string;
  readonly nodeId: string;
  readonly resources: Map<string, number>;
}

interface AuthoredPartyTravelConfig {
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
    validateInitialCargoCapacities(this.#parties, this.#economySeed);
    this.#worldMemory = new WorldMemory(worldMemory.snapshot());
    this.#initialWorldMemorySnapshot = this.#worldMemory.snapshot();
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
      facilities: new Facilities(domain.facilities.facilities, domain.facilities.hosts),
      tradeHubs: domain.tradeHubs === null ? null : new TradeHubs(domain.tradeHubs),
      maxEventsPerAdvance: domain.maxEventsPerAdvance,
      events: domain.events,
    });
    const seeds = snapshot.parties.map((party) => ({
      id: party.id,
      displayName: party.displayName,
      managerActorId: party.managerActorId,
      nodeId: party.currentNodeId ?? party.travel?.originNodeId ?? "",
      composition: party.composition,
      knownRouteIds: party.knownRouteIds,
      cargo: party.cargo,
    }));
    const simulation = new WorldSimulation(
      graph, travelConfig, seeds, economySeed, clock, foundation, new WorldMemory(snapshot.worldMemory),
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
  submitCommand(envelope: WorldCommandEnvelope): WorldCommandSubmissionResult;
  submitCommand(envelope: WorldCommandEnvelope): WorldCommandSubmissionResult {
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

  merchantLocalTradeAffordances(partyId: string): MerchantLocalTradeAffordances {
    const party = this.#parties.get(partyId);
    if (party === undefined) throw new WorldSimulationQueryError(`Party ${partyId} does not exist.`);
    const snapshot = createPartySnapshot(this.#graph, party, this.#economySeed);
    const hubs = party.location.status === "idle"
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

  #executeMoveParty(command: MovePartyCommand): CommandResult {
    const party = this.#parties.get(command.party_id);
    if (party === undefined) {
      return rejected("PARTY_NOT_FOUND", `Party ${command.party_id} does not exist.`);
    }
    if (party.location.status === "traveling") {
      return rejected("PARTY_BUSY", `Party ${party.id} is already traveling.`);
    }
    if (!this.#graph.nodesById.has(command.from_node_id)) {
      return rejected("NODE_NOT_FOUND", `Origin node ${command.from_node_id} does not exist.`);
    }
    if (!this.#graph.nodesById.has(command.to_node_id)) {
      return rejected("NODE_NOT_FOUND", `Destination node ${command.to_node_id} does not exist.`);
    }
    if (party.location.nodeId !== command.from_node_id) {
      return rejected(
        "ORIGIN_MISMATCH",
        `Party ${party.id} is at ${party.location.nodeId}, not ${command.from_node_id}.`,
      );
    }

    const edge = getEdgeBetween(this.#graph, command.from_node_id, command.to_node_id);
    if (edge === undefined) {
      return rejected(
        "ROUTE_NOT_FOUND",
        `No route connects ${command.from_node_id} and ${command.to_node_id}.`,
      );
    }
    if (!party.knownRouteIds.has(edge.id)) {
      return rejected("ROUTE_UNKNOWN", `Party ${party.id} does not know route ${edge.id}.`);
    }

    party.location = {
      status: "traveling",
      edgeId: edge.id,
      originNodeId: command.from_node_id,
      destinationNodeId: command.to_node_id,
      distanceKm: edge.distanceKm,
      speedKmPerDay: calculatePartyTravelSpeed(party.composition, this.#travelConfig),
      progressKm: 0,
    };
    this.#observeRoute(party, edge, command.from_node_id, command.to_node_id);
    return { accepted: true };
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
        this.#advanceContinuousState(fromElapsedDays, toElapsedDays);
      });
      return;
    }
    const previousElapsedDays = this.#clock.elapsedDays;
    this.#clock.advanceDays(days);
    this.#advanceContinuousState(previousElapsedDays, this.#clock.elapsedDays);
  }

  #advanceContinuousState(previousElapsedDays: number, currentElapsedDays: number): void {
    const elapsedFullDays = completedSimulationDays(currentElapsedDays)
      - completedSimulationDays(previousElapsedDays);
    if (elapsedFullDays > 0) this.#advanceLocationEconomy(elapsedFullDays);
    const days = currentElapsedDays - previousElapsedDays;
    for (const party of this.#parties.values()) {
      if (party.location.status !== "traveling") continue;
      const travel = party.location;
      travel.progressKm = Math.min(
        travel.distanceKm,
        travel.progressKm + travel.speedKmPerDay * days,
      );
      if (travel.progressKm + 1e-9 >= travel.distanceKm) {
        travel.progressKm = travel.distanceKm;
        party.location = { status: "idle", nodeId: travel.destinationNodeId };
      }
    }
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
    };
  }

  #restoreRuntimeSnapshot(snapshot: WorldSnapshot): void {
    for (const source of snapshot.parties) {
      const party = this.#parties.get(source.id);
      if (party === undefined) throw new WorldSimulationConfigurationError(`Snapshot party ${source.id} is missing from seed.`);
      party.cargo.clear();
      for (const [goodsId, amount] of Object.entries(source.cargo)) party.cargo.set(goodsId, amount);
      party.location = source.travel === null
        ? { status: "idle", nodeId: requireRestoredNode(source) }
        : {
            status: "traveling",
            edgeId: source.travel.edgeId,
            originNodeId: source.travel.originNodeId,
            destinationNodeId: source.travel.destinationNodeId,
            distanceKm: source.travel.distanceKm,
            speedKmPerDay: source.travel.speedKmPerDay,
            progressKm: source.travel.progressKm,
          };
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

    const knownEdges = this.#graph.edges.filter((edge) => party.knownRouteIds.has(edge.id));
    const knownNodeIds = new Set<string>();
    for (const edge of knownEdges) {
      knownNodeIds.add(edge.originNodeId);
      knownNodeIds.add(edge.targetNodeId);
    }
    if (party.location.status === "idle") knownNodeIds.add(party.location.nodeId);
    else {
      knownNodeIds.add(party.location.originNodeId);
      knownNodeIds.add(party.location.destinationNodeId);
    }

    return {
      mode: "party",
      observerPartyId: partyId,
      region: {
        id: this.#graph.id,
        displayName: this.#graph.displayName,
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
    };
  }

  #observeRoute(
    party: PartyRuntimeState,
    edge: RegionGraphEdge,
    originNodeId: string,
    destinationNodeId: string,
  ): void {
    for (const waypoint of edge.routeWaypoints) {
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
      composition: { ...seed.composition },
      cargo,
      knownRouteIds: new Set(seed.knownRouteIds),
      observedWaypointIds: new Set(),
      observedLandmarkIds: new Set(),
      location: { status: "idle", nodeId: seed.nodeId },
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

function createPartySnapshot(
  graph: RegionGraph,
  party: PartyRuntimeState,
  economySeed: WorldEconomySeed | null,
): PartySnapshot {
  const economyCargo = createPartyCargoSnapshot(party, economySeed);
  if (party.location.status === "idle") {
    const node = graph.nodesById.get(party.location.nodeId);
    if (node === undefined) {
      throw new WorldSimulationConfigurationError(
        `Party ${party.id} is at missing node ${party.location.nodeId}.`,
      );
    }
    return {
      id: party.id,
      displayName: party.displayName,
      managerActorId: party.managerActorId,
      status: "idle",
      currentNodeId: node.id,
      position: node.position,
      composition: { ...party.composition },
      knownRouteIds: [...party.knownRouteIds],
      observedWaypointIds: [...party.observedWaypointIds].sort(),
      observedLandmarkIds: [...party.observedLandmarkIds].sort(),
      ...economyCargo,
      travel: null,
    };
  }

  const travel = party.location;
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
