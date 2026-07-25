import {
  FACILITIES_COMPONENT,
  FACILITY_PRODUCTION_TICK_DUE,
  Facilities,
} from "./facilities.js";
import type {
  CohortShortageEffect,
  FacilitiesSnapshot,
  FacilityProductionEvent,
} from "./facilities.js";
import { Governance } from "./governance.js";
import type { GovernanceSnapshot } from "./governance.js";
import {
  TRADE_HUBS_COMPONENT,
  TRADE_HUB_MATCH_DUE,
  TRADE_HUB_ORDER_EXPIRY_DUE,
  TradeHubs,
} from "./trade-hubs.js";
import type {
  CancelTradeHubOrderCommand,
  PlaceTradeHubOrderCommand,
  TradeHubCommand,
  TradeHubCommandFailure,
  TradeHubCommandMutation,
  TradeHubCommandResult,
  TradeHubEvent,
  TradeHubSnapshot,
  TradeHubsSnapshot,
  TransferTradeHubGoodsCommand,
} from "./trade-hubs.js";
import { WorldClock } from "./world-clock.js";
import type {
  ScheduledEventIntent,
  SerializableValue,
  WorldClockSnapshot,
} from "./world-clock.js";

export const RESOURCE_CONSUMPTION_DUE = "ResourceConsumptionDue";
export const RESOURCE_DELIVERY_DUE = "ResourceDeliveryDue";
export const SETTLEMENT_RESOURCES_COMPONENT = "settlement_resources";

export interface ResourceConsumptionPayload extends Record<string, SerializableValue> {
  readonly hostId: string;
  readonly resourceId: string;
  readonly amount: number;
  readonly cohortId: string;
  readonly unrestIncrease: number;
  readonly workforceLoss: number;
  readonly retryDelayDays: number | null;
}

export interface ResourceDeliveryPayload extends Record<string, SerializableValue> {
  readonly hostId: string;
  readonly resourceId: string;
  readonly amount: number;
}

export interface ResourceConsumptionAttemptedEvent {
  readonly eventType: "ResourceConsumptionAttempted";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly hostId: string;
  readonly resourceId: string;
  readonly amount: number;
  readonly outcome: "consumed" | "shortage";
  readonly availableBefore: number | null;
  readonly retryEventId: string | null;
}

export interface ResourceDeliveryAttemptedEvent {
  readonly eventType: "ResourceDeliveryAttempted";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly hostId: string;
  readonly resourceId: string;
  readonly amount: number;
  readonly outcome: "delivered" | "blocked_storage";
}

export type SimulationFoundationEvent =
  | FacilityProductionEvent
  | ResourceConsumptionAttemptedEvent
  | ResourceDeliveryAttemptedEvent
  | TradeHubEvent;

export interface SimulationFoundationDomainSnapshot {
  readonly governance: GovernanceSnapshot;
  readonly facilities: FacilitiesSnapshot;
  readonly events: readonly SimulationFoundationEvent[];
  readonly maxEventsPerAdvance: number;
  readonly tradeHubs: TradeHubsSnapshot | null;
}

export interface SimulationFoundationSnapshot extends SimulationFoundationDomainSnapshot {
  readonly clock: WorldClockSnapshot;
}

export interface SimulationFoundationOptions {
  readonly clock: WorldClock;
  readonly governance: Governance;
  readonly facilities: Facilities;
  readonly maxEventsPerAdvance: number;
  readonly tradeHubs?: TradeHubs | null;
  readonly events?: readonly SimulationFoundationEvent[];
}

export interface FacilityOperationCommand {
  readonly issuerActorId: string;
  readonly facilityId: string;
  readonly operation: "pause" | "resume";
}

export interface TransferFacilityGoodsToTradeHubCommand extends TransferTradeHubGoodsCommand {
  readonly direction: "deposit";
  readonly facilityId: string;
  readonly facilityHostId: string;
}

export type FacilityOperationResult =
  | { readonly accepted: true; readonly scheduledEventId: string | null }
  | {
      readonly accepted: false;
      readonly errorCode: "NOT_AUTHORIZED" | "FOUNDATION_NOT_CONFIGURED";
      readonly message: string;
    };

export class SimulationFoundationValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SimulationFoundationValidationError";
  }
}

export class WorldSimulationFoundation {
  readonly #clock: WorldClock;
  #governance: Governance;
  #facilities: Facilities;
  #tradeHubs: TradeHubs | null;
  readonly #maxEventsPerAdvance: number;
  #events: SimulationFoundationEvent[];
  #resetSnapshot: SimulationFoundationSnapshot | null = null;
  #configurationSealed = false;

  constructor(options: SimulationFoundationOptions) {
    if (!Number.isSafeInteger(options.maxEventsPerAdvance) || options.maxEventsPerAdvance <= 0) {
      throw new SimulationFoundationValidationError(
        "maxEventsPerAdvance must be a positive safe integer.",
      );
    }
    this.#clock = options.clock;
    this.#governance = new Governance(options.governance.snapshot());
    const facilitiesSnapshot = options.facilities.snapshot();
    this.#facilities = new Facilities(
      facilitiesSnapshot.facilities,
      facilitiesSnapshot.hosts,
    );
    this.#maxEventsPerAdvance = options.maxEventsPerAdvance;
    this.#tradeHubs = options.tradeHubs === undefined || options.tradeHubs === null
      ? null
      : new TradeHubs(options.tradeHubs.snapshot());
    this.#events = Array.from(structuredClone(options.events ?? []));
  }

  schedule(intent: ScheduledEventIntent): void {
    this.#requireConfigurationOpen();
    this.#clock.schedule(intent);
  }

  usesClock(clock: WorldClock): boolean {
    return this.#clock === clock;
  }

  captureResetState(): void {
    this.#resetSnapshot = this.snapshot();
    this.#configurationSealed = true;
  }

  reset(): void {
    if (this.#resetSnapshot === null) {
      throw new SimulationFoundationValidationError("Foundation reset state was not captured.");
    }
    this.#clock.restore(this.#resetSnapshot.clock);
    this.#governance = new Governance(this.#resetSnapshot.governance);
    this.#facilities = new Facilities(
      this.#resetSnapshot.facilities.facilities,
      this.#resetSnapshot.facilities.hosts,
    );
    this.#tradeHubs = this.#resetSnapshot.tradeHubs === null
      ? null
      : new TradeHubs(this.#resetSnapshot.tradeHubs);
    this.#events = Array.from(structuredClone(this.#resetSnapshot.events));
  }

  scheduleInitialFacilityTick(facilityId: string): ScheduledEventIntent | null {
    this.#requireConfigurationOpen();
    const intent = this.#facilities.initialTickIntent(facilityId, this.#clock.elapsedDays);
    if (intent !== null) this.#clock.schedule(intent);
    return intent;
  }

  executeFacilityOperation(command: FacilityOperationCommand): FacilityOperationResult {
    const authority = this.#governance.authorize({
      issuerActorId: command.issuerActorId,
      managedEntityId: command.facilityId,
      requiredScope: "facility:operate",
      elapsedDays: this.#clock.elapsedDays,
    });
    if (!authority.authorized) {
      return {
        accepted: false,
        errorCode: "NOT_AUTHORIZED",
        message: `Actor ${command.issuerActorId} is not authorized to operate ${command.facilityId}.`,
      };
    }
    if (command.operation === "pause") {
      this.#facilities.pause(command.facilityId);
      return { accepted: true, scheduledEventId: null };
    }
    const intent = this.#facilities.startOrResume(command.facilityId, this.#clock.elapsedDays);
    this.#clock.schedule(intent);
    return { accepted: true, scheduledEventId: intent.eventId };
  }

  preparePartyTradeHubTransfer(command: TransferTradeHubGoodsCommand): TradeHubCommandResult | null {
    const tradeHubs = this.#tradeHubs;
    if (tradeHubs === null) return tradeFoundationMissing();
    const replayed = tradeHubs.replay(command);
    if (replayed !== null) return replayed;
    return this.#authorizeTradeCommand(command, "trade:transfer");
  }

  recordTradeHubPhysicalFailure(
    command: TransferTradeHubGoodsCommand,
    message: string,
  ): TradeHubCommandFailure {
    const tradeHubs = this.#requireTradeHubs();
    return tradeHubs.recordFailure(command, {
      accepted: false,
      idempotentReplay: false,
      errorCode: "PHYSICAL_TRANSFER_REJECTED",
      message,
    });
  }

  executePreparedPartyTradeHubTransfer(
    command: TransferTradeHubGoodsCommand,
  ): TradeHubCommandMutation {
    const mutation = this.#requireTradeHubs().transferGoods(command, this.#clock.elapsedDays);
    this.#recordTradeMutation(mutation);
    return mutation;
  }

  tradeHubNodeId(hubId: string): string | null {
    return this.#tradeHubs?.hubNodeId(hubId) ?? null;
  }

  tradeHubSnapshotsAtNode(nodeId: string): readonly TradeHubSnapshot[] {
    return this.#tradeHubs?.snapshotsAtNode(nodeId) ?? [];
  }

  executeFacilityTradeHubTransfer(
    command: TransferFacilityGoodsToTradeHubCommand,
  ): TradeHubCommandResult {
    const tradeHubs = this.#tradeHubs;
    if (tradeHubs === null) return tradeFoundationMissing();
    const replayed = tradeHubs.replay(command);
    if (replayed !== null) return replayed;
    const authorization = this.#authorizeTradeCommand(command, "trade:transfer", command.facilityId);
    if (authorization !== null) return authorization;
    if (!tradeHubs.isFacilityConnected(command.hubId, command.facilityHostId)) {
      return tradeHubs.recordFailure(command, tradeFailure(
        "FACILITY_NOT_CONNECTED",
        `Facility host ${command.facilityHostId} is not connected to hub ${command.hubId}.`,
      ));
    }
    if (this.#facilities.availableResource(command.facilityHostId, command.goodsId) < command.amount) {
      return tradeHubs.recordFailure(command, tradeFailure(
        "PHYSICAL_TRANSFER_REJECTED",
        `Facility host ${command.facilityHostId} has insufficient ${command.goodsId}.`,
      ));
    }
    const mutation = tradeHubs.transferGoods(command, this.#clock.elapsedDays);
    if (mutation.result.accepted) {
      if (!this.#facilities.withdraw(command.facilityHostId, command.goodsId, command.amount)) {
        throw new SimulationFoundationValidationError("Validated Facility withdrawal failed.");
      }
      this.#recordTradeMutation(mutation);
    }
    return mutation.result;
  }

  executePlaceTradeHubOrder(command: PlaceTradeHubOrderCommand): TradeHubCommandResult {
    const tradeHubs = this.#tradeHubs;
    if (tradeHubs === null) return tradeFoundationMissing();
    const replayed = tradeHubs.replay(command);
    if (replayed !== null) return replayed;
    const authorization = this.#authorizeTradeCommand(command, "trade:order");
    if (authorization !== null) return authorization;
    const before = tradeHubs.snapshot();
    const mutation = tradeHubs.placeOrder(command, this.#clock.elapsedDays);
    if (!mutation.result.accepted) return mutation.result;
    try {
      this.#clock.scheduleAll(mutation.scheduledIntents);
    } catch (error: unknown) {
      this.#tradeHubs = new TradeHubs(before);
      const message = error instanceof Error ? error.message : String(error);
      return this.#tradeHubs.recordFailure(
        command,
        tradeFailure("SCHEDULING_FAILED", `TradeHub scheduling failed: ${message}`),
      );
    }
    this.#recordTradeMutation(mutation);
    return mutation.result;
  }

  executeCancelTradeHubOrder(command: CancelTradeHubOrderCommand): TradeHubCommandResult {
    const tradeHubs = this.#tradeHubs;
    if (tradeHubs === null) return tradeFoundationMissing();
    const replayed = tradeHubs.replay(command);
    if (replayed !== null) return replayed;
    const authorization = this.#authorizeTradeCommand(command, "trade:cancel");
    if (authorization !== null) return authorization;
    const mutation = tradeHubs.cancelOrder(command, this.#clock.elapsedDays);
    this.#recordTradeMutation(mutation);
    return mutation.result;
  }

  advanceDays(
    days: number,
    onTimeAdvanced?: (fromElapsedDays: number, toElapsedDays: number) => void,
  ): void {
    if (!this.#configurationSealed) this.captureResetState();
    this.#clock.advanceDays(days, {
      maxEvents: this.#maxEventsPerAdvance,
      dispatch: (intent) => this.#dispatch(intent),
      ...(onTimeAdvanced === undefined ? {} : { onTimeAdvanced }),
    });
  }

  snapshot(): SimulationFoundationSnapshot {
    return {
      clock: this.#clock.snapshot(),
      ...this.domainSnapshot(),
    };
  }

  domainSnapshot(): SimulationFoundationDomainSnapshot {
    return {
      governance: this.#governance.snapshot(),
      facilities: this.#facilities.snapshot(),
      events: structuredClone(this.#events),
      maxEventsPerAdvance: this.#maxEventsPerAdvance,
      tradeHubs: this.#tradeHubs?.snapshot() ?? null,
    };
  }

  static fromSnapshot(snapshot: SimulationFoundationSnapshot): WorldSimulationFoundation {
    const foundation = new WorldSimulationFoundation({
      clock: WorldClock.fromSnapshot(snapshot.clock),
      governance: new Governance(snapshot.governance),
      facilities: new Facilities(snapshot.facilities.facilities, snapshot.facilities.hosts),
      tradeHubs: snapshot.tradeHubs === null ? null : new TradeHubs(snapshot.tradeHubs),
      maxEventsPerAdvance: snapshot.maxEventsPerAdvance,
      events: snapshot.events,
    });
    foundation.captureResetState();
    return foundation;
  }

  #dispatch(intent: ScheduledEventIntent): readonly ScheduledEventIntent[] {
    if (intent.kind === FACILITY_PRODUCTION_TICK_DUE
      && intent.targetComponent === FACILITIES_COMPONENT) {
      const result = this.#facilities.handleProductionTick(intent, this.#clock.elapsedDays);
      this.#events.push(result.event);
      return result.nextIntent === null ? [] : [result.nextIntent];
    }
    if (intent.kind === RESOURCE_CONSUMPTION_DUE
      && intent.targetComponent === SETTLEMENT_RESOURCES_COMPONENT) {
      return this.#dispatchConsumption(intent);
    }
    if (intent.kind === RESOURCE_DELIVERY_DUE
      && intent.targetComponent === SETTLEMENT_RESOURCES_COMPONENT) {
      return this.#dispatchDelivery(intent);
    }
    if ((intent.kind === TRADE_HUB_MATCH_DUE || intent.kind === TRADE_HUB_ORDER_EXPIRY_DUE)
      && intent.targetComponent === TRADE_HUBS_COMPONENT) {
      const events = this.#requireTradeHubs().handleScheduledIntent(intent, this.#clock.elapsedDays);
      this.#events.push(...events);
      return [];
    }
    throw new SimulationFoundationValidationError(
      `No WorldSim dispatcher for ${intent.targetComponent}/${intent.kind}.`,
    );
  }

  #dispatchConsumption(intent: ScheduledEventIntent): readonly ScheduledEventIntent[] {
    const payload = readConsumptionPayload(intent);
    const effect: CohortShortageEffect = {
      cohortId: payload.cohortId,
      unrestIncrease: payload.unrestIncrease,
      workforceLoss: payload.workforceLoss,
    };
    const result = this.#facilities.consumeForCohort(
      payload.hostId,
      payload.resourceId,
      payload.amount,
      effect,
    );
    const retry = result.outcome === "shortage" && payload.retryDelayDays !== null
      ? createRetryIntent(intent, payload.retryDelayDays)
      : null;
    this.#events.push({
      eventType: "ResourceConsumptionAttempted",
      scheduledEventId: intent.eventId,
      elapsedDays: this.#clock.elapsedDays,
      hostId: payload.hostId,
      resourceId: payload.resourceId,
      amount: payload.amount,
      outcome: result.outcome,
      availableBefore: result.outcome === "shortage" ? result.available : null,
      retryEventId: retry?.eventId ?? null,
    });
    return retry === null ? [] : [retry];
  }

  #dispatchDelivery(intent: ScheduledEventIntent): readonly ScheduledEventIntent[] {
    const payload = readDeliveryPayload(intent);
    const delivered = this.#facilities.deposit(payload.hostId, payload.resourceId, payload.amount);
    this.#events.push({
      eventType: "ResourceDeliveryAttempted",
      scheduledEventId: intent.eventId,
      elapsedDays: this.#clock.elapsedDays,
      hostId: payload.hostId,
      resourceId: payload.resourceId,
      amount: payload.amount,
      outcome: delivered ? "delivered" : "blocked_storage",
    });
    return [];
  }

  #authorizeTradeCommand(
    command: TradeHubCommand,
    scope: string,
    managedEntityId = command.accountEntityId,
  ): TradeHubCommandFailure | null {
    const decision = this.#governance.authorize({
      issuerActorId: command.issuerActorId,
      managedEntityId,
      requiredScope: scope,
      elapsedDays: this.#clock.elapsedDays,
    });
    if (decision.authorized) return null;
    const failure = tradeFailure(
      "NOT_AUTHORIZED",
      `Actor ${command.issuerActorId} is not authorized for ${scope} on ${managedEntityId}.`,
    );
    return this.#requireTradeHubs().recordFailure(command, failure);
  }

  #recordTradeMutation(mutation: TradeHubCommandMutation): void {
    this.#events.push(...mutation.events);
  }

  #requireTradeHubs(): TradeHubs {
    if (this.#tradeHubs === null) {
      throw new SimulationFoundationValidationError("TradeHubs are not configured.");
    }
    return this.#tradeHubs;
  }

  #requireConfigurationOpen(): void {
    if (this.#configurationSealed) {
      throw new SimulationFoundationValidationError(
        "Scheduled setup intents cannot be added after WorldSimulation starts.",
      );
    }
  }
}

export function resourceConsumptionIntent(
  eventId: string,
  dueElapsedDays: number,
  payload: ResourceConsumptionPayload,
): ScheduledEventIntent<ResourceConsumptionPayload> {
  validateConsumptionPayload(payload, eventId);
  return {
    eventId,
    kind: RESOURCE_CONSUMPTION_DUE,
    dueElapsedDays,
    targetComponent: SETTLEMENT_RESOURCES_COMPONENT,
    targetEntityId: payload.hostId,
    payload: { ...payload },
  };
}

export function resourceDeliveryIntent(
  eventId: string,
  dueElapsedDays: number,
  payload: ResourceDeliveryPayload,
): ScheduledEventIntent<ResourceDeliveryPayload> {
  validateDeliveryPayload(payload, eventId);
  return {
    eventId,
    kind: RESOURCE_DELIVERY_DUE,
    dueElapsedDays,
    targetComponent: SETTLEMENT_RESOURCES_COMPONENT,
    targetEntityId: payload.hostId,
    payload: { ...payload },
  };
}

function createRetryIntent(
  original: ScheduledEventIntent,
  retryDelayDays: number,
): ScheduledEventIntent {
  if (!Number.isFinite(retryDelayDays) || retryDelayDays <= 0) {
    throw new SimulationFoundationValidationError("Retry delay must be finite and positive.");
  }
  return {
    ...original,
    eventId: `${original.eventId}:retry`,
    dueElapsedDays: original.dueElapsedDays + retryDelayDays,
    payload: structuredClone(original.payload),
  };
}

function readConsumptionPayload(intent: ScheduledEventIntent): ResourceConsumptionPayload {
  const payload = requireRecord(intent.payload, intent.eventId) as Partial<ResourceConsumptionPayload>;
  validateConsumptionPayload(payload, intent.eventId);
  return payload as ResourceConsumptionPayload;
}

function readDeliveryPayload(intent: ScheduledEventIntent): ResourceDeliveryPayload {
  const payload = requireRecord(intent.payload, intent.eventId) as Partial<ResourceDeliveryPayload>;
  validateDeliveryPayload(payload, intent.eventId);
  return payload as ResourceDeliveryPayload;
}

function validateConsumptionPayload(
  payload: Partial<ResourceConsumptionPayload>,
  eventId: string,
): asserts payload is ResourceConsumptionPayload {
  requireString(payload.hostId, `${eventId}.hostId`);
  requireString(payload.resourceId, `${eventId}.resourceId`);
  requirePositive(payload.amount, `${eventId}.amount`);
  requireString(payload.cohortId, `${eventId}.cohortId`);
  requireNonNegative(payload.unrestIncrease, `${eventId}.unrestIncrease`);
  requireNonNegative(payload.workforceLoss, `${eventId}.workforceLoss`);
  if (payload.retryDelayDays !== null) {
    requirePositive(payload.retryDelayDays, `${eventId}.retryDelayDays`);
  }
}

function validateDeliveryPayload(
  payload: Partial<ResourceDeliveryPayload>,
  eventId: string,
): asserts payload is ResourceDeliveryPayload {
  requireString(payload.hostId, `${eventId}.hostId`);
  requireString(payload.resourceId, `${eventId}.resourceId`);
  requirePositive(payload.amount, `${eventId}.amount`);
}

function requireRecord(value: unknown, eventId: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new SimulationFoundationValidationError(`Event ${eventId} payload must be an object.`);
  }
  return value as Record<string, unknown>;
}

function requireString(value: unknown, path: string): asserts value is string {
  if (typeof value !== "string" || value.length === 0) {
    throw new SimulationFoundationValidationError(`${path} must be a non-empty string.`);
  }
}

function requirePositive(value: unknown, path: string): asserts value is number {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
    throw new SimulationFoundationValidationError(`${path} must be finite and positive.`);
  }
}

function requireNonNegative(value: unknown, path: string): asserts value is number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    throw new SimulationFoundationValidationError(`${path} must be finite and non-negative.`);
  }
}

function tradeFoundationMissing(): TradeHubCommandFailure {
  return tradeFailure(
    "TRADE_FOUNDATION_NOT_CONFIGURED",
    "TradeHub foundation is not configured.",
  );
}

function tradeFailure(
  errorCode: TradeHubCommandFailure["errorCode"],
  message: string,
): TradeHubCommandFailure {
  return { accepted: false, idempotentReplay: false, errorCode, message };
}
