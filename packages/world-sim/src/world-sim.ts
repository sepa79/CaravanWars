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
import type { WorldClockSnapshot } from "./world-clock.js";
import type {
  FacilityOperationCommand,
  FacilityOperationResult,
  SimulationFoundationDomainSnapshot,
  WorldSimulationFoundation,
} from "./simulation-foundation.js";
import type {
  GoodsCatalog,
  LocationEconomyConfig,
  PartyCargoConfig,
} from "./economy-config.js";

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

export type WorldCommandEnvelope =
  | { readonly commandType: "move_party"; readonly command: MovePartyCommand }
  | { readonly commandType: "transfer_goods"; readonly command: TransferGoodsCommand }
  | { readonly commandType: "set_facility_operation"; readonly command: FacilityOperationCommand };

export type WorldCommandSubmissionResult =
  | { readonly commandType: "move_party"; readonly result: CommandResult }
  | { readonly commandType: "transfer_goods"; readonly result: TransferGoodsResult }
  | { readonly commandType: "set_facility_operation"; readonly result: FacilityOperationResult };

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
  #parties: Map<string, PartyRuntimeState>;
  #locations: Map<string, LocationRuntimeState>;
  #runtimeEvents: WorldSimulationEvent[] = [];

  constructor(
    graph: RegionGraph,
    travelConfig: PartyTravelConfig,
    partySeeds: readonly PartySeed[],
    economySeed: WorldEconomySeed | null,
    clock = new WorldClock(),
    simulationFoundation: WorldSimulationFoundation | null = null,
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
  submitCommand(envelope: WorldCommandEnvelope): WorldCommandSubmissionResult;
  submitCommand(envelope: WorldCommandEnvelope): WorldCommandSubmissionResult {
    if (envelope.commandType === "move_party") {
      return { commandType: "move_party", result: this.#executeMoveParty(envelope.command) };
    }
    if (envelope.commandType === "transfer_goods") {
      return { commandType: "transfer_goods", result: this.#executeTransferGoods(envelope.command) };
    }
    return {
      commandType: "set_facility_operation",
      result: this.#simulationFoundation?.executeFacilityOperation(envelope.command) ?? {
        accepted: false,
        errorCode: "FOUNDATION_NOT_CONFIGURED",
        message: "World simulation foundation is not configured.",
      },
    };
  }

  partySnapshot(partyId: string): PartySnapshot {
    const party = this.#parties.get(partyId);
    if (party === undefined) throw new WorldSimulationQueryError(`Party ${partyId} does not exist.`);
    return createPartySnapshot(this.#graph, party, this.#economySeed);
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
  }

  snapshot(): WorldSnapshot {
    return {
      clock: this.#clock.snapshot(),
      simulationFoundation: this.#simulationFoundation?.domainSnapshot() ?? null,
      parties: [...this.#parties.values()].map((party) =>
        createPartySnapshot(this.#graph, party, this.#economySeed)),
      locations: [...this.#locations.values()].map(createLocationSnapshot),
      runtimeEvents: this.#runtimeEvents.map(copyWorldSimulationEvent),
    };
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
