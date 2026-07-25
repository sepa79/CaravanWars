import type { ScheduledEventIntent, SerializableValue } from "./world-clock.js";

export const TRADE_HUBS_COMPONENT = "trade_hubs";
export const TRADE_HUB_MATCH_DUE = "TradeHubMatchDue";
export const TRADE_HUB_ORDER_EXPIRY_DUE = "TradeHubOrderExpiryDue";

export type TradeOrderSide = "buy" | "sell";
export type TradeOrderStatus = "open" | "partially_filled" | "filled" | "cancelled" | "expired";

export interface TradeHubAccountSnapshot {
  readonly accountEntityId: string;
  readonly availableGoods: Readonly<Record<string, number>>;
  readonly escrowGoods: Readonly<Record<string, number>>;
  readonly availableCurrency: number;
  readonly escrowCurrency: number;
}

export interface TradeHubOrderSnapshot {
  readonly orderId: string;
  readonly accountEntityId: string;
  readonly side: TradeOrderSide;
  readonly goodsId: string;
  readonly originalQuantity: number;
  readonly remainingQuantity: number;
  readonly limitPrice: number;
  readonly placementSequence: number;
  readonly status: TradeOrderStatus;
  readonly expiresAtElapsedDays: number | null;
  readonly expiryEventId: string | null;
}

export interface TradeHubCommandSuccess {
  readonly accepted: true;
  readonly idempotentReplay: boolean;
  readonly orderId: string | null;
  readonly scheduledEventIds: readonly string[];
}

export type TradeHubCommandErrorCode =
  | "TRADE_FOUNDATION_NOT_CONFIGURED"
  | "COMMAND_ID_CONFLICT"
  | "NOT_AUTHORIZED"
  | "HUB_NOT_FOUND"
  | "ACCOUNT_NOT_FOUND"
  | "ORDER_NOT_FOUND"
  | "ORDER_NOT_OPEN"
  | "ORDER_OWNER_MISMATCH"
  | "GOODS_NOT_SUPPORTED"
  | "INVALID_AMOUNT"
  | "INVALID_PRICE"
  | "INVALID_EXPIRY"
  | "INSUFFICIENT_HUB_GOODS"
  | "INSUFFICIENT_CURRENCY"
  | "HUB_STORAGE_EXCEEDED"
  | "FACILITY_NOT_CONNECTED"
  | "PHYSICAL_TRANSFER_REJECTED"
  | "SCHEDULING_FAILED";

export interface TradeHubCommandFailure {
  readonly accepted: false;
  readonly idempotentReplay: boolean;
  readonly errorCode: TradeHubCommandErrorCode;
  readonly message: string;
}

export type TradeHubCommandResult = TradeHubCommandSuccess | TradeHubCommandFailure;

export interface ProcessedTradeHubCommandSnapshot {
  readonly commandId: string;
  readonly fingerprint: string;
  readonly result: TradeHubCommandResult;
}

export interface TradeHubSnapshot {
  readonly hubId: string;
  readonly nodeId: string;
  readonly ownerId: string;
  readonly governorActorId: string | null;
  readonly connectedFacilityHostIds: readonly string[];
  readonly storageCaps: Readonly<Record<string, number>>;
  readonly inventory: Readonly<Record<string, number>>;
  readonly accounts: readonly TradeHubAccountSnapshot[];
  readonly orders: readonly TradeHubOrderSnapshot[];
  readonly nextPlacementSequence: number;
  readonly nextScheduledEventOrdinal: number;
  readonly processedCommandIds: readonly ProcessedTradeHubCommandSnapshot[];
  readonly processedScheduledEventIds: readonly string[];
}

export interface TradeHubsSnapshot {
  readonly hubs: readonly TradeHubSnapshot[];
}

export interface TradeHubCommandIdentity {
  readonly commandId: string;
  readonly hubId: string;
}

export interface TransferTradeHubGoodsCommand extends TradeHubCommandIdentity {
  readonly issuerActorId: string;
  readonly accountEntityId: string;
  readonly goodsId: string;
  readonly amount: number;
  readonly direction: "deposit" | "withdraw";
}

export interface PlaceTradeHubOrderCommand extends TradeHubCommandIdentity {
  readonly issuerActorId: string;
  readonly accountEntityId: string;
  readonly orderId: string;
  readonly side: TradeOrderSide;
  readonly goodsId: string;
  readonly quantity: number;
  readonly limitPrice: number;
  readonly expiresAtElapsedDays: number | null;
}

export interface CancelTradeHubOrderCommand extends TradeHubCommandIdentity {
  readonly issuerActorId: string;
  readonly accountEntityId: string;
  readonly orderId: string;
}

export type TradeHubCommand =
  | TransferTradeHubGoodsCommand
  | PlaceTradeHubOrderCommand
  | CancelTradeHubOrderCommand;

export interface TradeHubGoodsTransferredEvent {
  readonly eventType: "TradeHubGoodsTransferred";
  readonly commandId: string;
  readonly elapsedDays: number;
  readonly hubId: string;
  readonly accountEntityId: string;
  readonly goodsId: string;
  readonly amount: number;
  readonly direction: "deposit" | "withdraw";
}

export interface TradeHubOrderPlacedEvent {
  readonly eventType: "TradeHubOrderPlaced";
  readonly commandId: string;
  readonly elapsedDays: number;
  readonly hubId: string;
  readonly orderId: string;
}

export interface TradeHubOrderClosedEvent {
  readonly eventType: "TradeHubOrderCancelled" | "TradeHubOrderExpired";
  readonly commandId: string | null;
  readonly scheduledEventId: string | null;
  readonly elapsedDays: number;
  readonly hubId: string;
  readonly orderId: string;
  readonly releasedGoods: number;
  readonly releasedCurrency: number;
}

export interface TradeHubTradeExecutedEvent {
  readonly eventType: "TradeHubTradeExecuted";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly hubId: string;
  readonly goodsId: string;
  readonly buyOrderId: string;
  readonly sellOrderId: string;
  readonly quantity: number;
  readonly unitPrice: number;
  readonly totalPrice: number;
}

export interface TradeHubScheduledIntentIgnoredEvent {
  readonly eventType: "TradeHubScheduledIntentIgnored";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly hubId: string;
  readonly reason: "duplicate" | "order_not_open";
}

export type TradeHubEvent =
  | TradeHubGoodsTransferredEvent
  | TradeHubOrderPlacedEvent
  | TradeHubOrderClosedEvent
  | TradeHubTradeExecutedEvent
  | TradeHubScheduledIntentIgnoredEvent;

export interface TradeHubCommandMutation {
  readonly result: TradeHubCommandResult;
  readonly scheduledIntents: readonly ScheduledEventIntent[];
  readonly events: readonly TradeHubEvent[];
}

interface TradeHubAccountRuntime {
  readonly accountEntityId: string;
  readonly availableGoods: Map<string, number>;
  readonly escrowGoods: Map<string, number>;
  availableCurrency: number;
  escrowCurrency: number;
}

interface TradeHubOrderRuntime extends Omit<TradeHubOrderSnapshot, "status" | "remainingQuantity"> {
  remainingQuantity: number;
  status: TradeOrderStatus;
}

interface TradeHubRuntime {
  readonly hubId: string;
  readonly nodeId: string;
  readonly ownerId: string;
  readonly governorActorId: string | null;
  readonly connectedFacilityHostIds: ReadonlySet<string>;
  readonly storageCaps: Readonly<Record<string, number>>;
  readonly inventory: Map<string, number>;
  readonly accounts: Map<string, TradeHubAccountRuntime>;
  readonly orders: Map<string, TradeHubOrderRuntime>;
  nextPlacementSequence: number;
  nextScheduledEventOrdinal: number;
  readonly processedCommands: Map<string, ProcessedTradeHubCommandSnapshot>;
  readonly processedScheduledEventIds: Set<string>;
}

export class TradeHubValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "TradeHubValidationError";
  }
}

export class TradeHubs {
  readonly #hubs: Map<string, TradeHubRuntime>;

  constructor(snapshot: TradeHubsSnapshot) {
    this.#hubs = new Map();
    for (const seed of snapshot.hubs) {
      const hub = createHub(seed);
      if (this.#hubs.has(hub.hubId)) throw new TradeHubValidationError(`Duplicate hub ${hub.hubId}.`);
      this.#hubs.set(hub.hubId, hub);
    }
  }

  replay(command: TradeHubCommand): TradeHubCommandResult | null {
    validateCommandIdentity(command);
    const hub = this.#hubs.get(command.hubId);
    if (hub === undefined) return null;
    const processed = hub.processedCommands.get(command.commandId);
    if (processed === undefined) return null;
    if (processed.fingerprint !== fingerprint(command)) {
      return failure("COMMAND_ID_CONFLICT", `Command id ${command.commandId} has another payload.`, false);
    }
    return { ...processed.result, idempotentReplay: true };
  }

  recordFailure(command: TradeHubCommand, result: TradeHubCommandFailure): TradeHubCommandFailure {
    const hub = this.#hubs.get(command.hubId);
    if (hub !== undefined && result.errorCode !== "COMMAND_ID_CONFLICT") {
      recordCommand(hub, command, result);
    }
    return result;
  }

  transferGoods(
    command: TransferTradeHubGoodsCommand,
    elapsedDays: number,
  ): TradeHubCommandMutation {
    const replayed = this.replay(command);
    if (replayed !== null) return mutation(replayed);
    const hub = this.#hubs.get(command.hubId);
    if (hub === undefined) return this.#reject(command, "HUB_NOT_FOUND", `Unknown hub ${command.hubId}.`);
    const account = hub.accounts.get(command.accountEntityId);
    if (account === undefined) {
      return this.#reject(command, "ACCOUNT_NOT_FOUND", `Unknown account ${command.accountEntityId}.`);
    }
    if (!isPositiveSafeInteger(command.amount)) {
      return this.#reject(command, "INVALID_AMOUNT", "TradeHub amount must be a positive safe integer.");
    }
    const cap = hub.storageCaps[command.goodsId];
    if (cap === undefined) {
      return this.#reject(command, "GOODS_NOT_SUPPORTED", `Hub ${hub.hubId} does not store ${command.goodsId}.`);
    }
    if (command.direction === "deposit") {
      if ((hub.inventory.get(command.goodsId) ?? 0) + command.amount > cap) {
        return this.#reject(command, "HUB_STORAGE_EXCEEDED", `Hub ${hub.hubId} storage is full.`);
      }
      add(account.availableGoods, command.goodsId, command.amount);
      add(hub.inventory, command.goodsId, command.amount);
    } else {
      if ((account.availableGoods.get(command.goodsId) ?? 0) < command.amount) {
        return this.#reject(
          command,
          "INSUFFICIENT_HUB_GOODS",
          `Account ${account.accountEntityId} has insufficient available ${command.goodsId}.`,
        );
      }
      add(account.availableGoods, command.goodsId, -command.amount);
      add(hub.inventory, command.goodsId, -command.amount);
    }
    const result = success(null, []);
    recordCommand(hub, command, result);
    return {
      result,
      scheduledIntents: [],
      events: [{
        eventType: "TradeHubGoodsTransferred",
        commandId: command.commandId,
        elapsedDays,
        hubId: hub.hubId,
        accountEntityId: account.accountEntityId,
        goodsId: command.goodsId,
        amount: command.amount,
        direction: command.direction,
      }],
    };
  }

  placeOrder(command: PlaceTradeHubOrderCommand, elapsedDays: number): TradeHubCommandMutation {
    const replayed = this.replay(command);
    if (replayed !== null) return mutation(replayed);
    const hub = this.#hubs.get(command.hubId);
    if (hub === undefined) return this.#reject(command, "HUB_NOT_FOUND", `Unknown hub ${command.hubId}.`);
    const account = hub.accounts.get(command.accountEntityId);
    if (account === undefined) {
      return this.#reject(command, "ACCOUNT_NOT_FOUND", `Unknown account ${command.accountEntityId}.`);
    }
    if (hub.orders.has(command.orderId)) {
      return this.#reject(command, "COMMAND_ID_CONFLICT", `Order id ${command.orderId} already exists.`);
    }
    if (hub.storageCaps[command.goodsId] === undefined) {
      return this.#reject(command, "GOODS_NOT_SUPPORTED", `Hub ${hub.hubId} does not trade ${command.goodsId}.`);
    }
    if (!isPositiveSafeInteger(command.quantity)) {
      return this.#reject(command, "INVALID_AMOUNT", "Order quantity must be a positive safe integer.");
    }
    if (!isPositiveSafeInteger(command.limitPrice)) {
      return this.#reject(command, "INVALID_PRICE", "Limit price must be a positive safe integer.");
    }
    if (command.expiresAtElapsedDays !== null
      && (!Number.isFinite(command.expiresAtElapsedDays)
        || command.expiresAtElapsedDays <= elapsedDays)) {
      return this.#reject(command, "INVALID_EXPIRY", "Order expiry must be later than current time.");
    }
    const scheduledEventCount = command.expiresAtElapsedDays === null ? 1 : 2;
    if (hub.nextPlacementSequence >= Number.MAX_SAFE_INTEGER
      || hub.nextScheduledEventOrdinal + scheduledEventCount > Number.MAX_SAFE_INTEGER) {
      return this.#reject(command, "SCHEDULING_FAILED", "TradeHub sequence is exhausted.");
    }
    const requiredCurrency = safeProduct(command.quantity, command.limitPrice, "Order escrow");
    if (command.side === "sell") {
      if ((account.availableGoods.get(command.goodsId) ?? 0) < command.quantity) {
        return this.#reject(command, "INSUFFICIENT_HUB_GOODS", "Sell order lacks deposited goods.");
      }
      add(account.availableGoods, command.goodsId, -command.quantity);
      add(account.escrowGoods, command.goodsId, command.quantity);
    } else {
      if (account.availableCurrency < requiredCurrency) {
        return this.#reject(command, "INSUFFICIENT_CURRENCY", "Buy order lacks local currency.");
      }
      account.availableCurrency -= requiredCurrency;
      account.escrowCurrency += requiredCurrency;
    }

    const expiryIntent = command.expiresAtElapsedDays === null
      ? null
      : createScheduledIntent(hub, TRADE_HUB_ORDER_EXPIRY_DUE, command.expiresAtElapsedDays, {
          orderId: command.orderId,
        });
    const matchIntent = createScheduledIntent(hub, TRADE_HUB_MATCH_DUE, elapsedDays, {
      goodsId: command.goodsId,
    });
    const order: TradeHubOrderRuntime = {
      orderId: command.orderId,
      accountEntityId: command.accountEntityId,
      side: command.side,
      goodsId: command.goodsId,
      originalQuantity: command.quantity,
      remainingQuantity: command.quantity,
      limitPrice: command.limitPrice,
      placementSequence: hub.nextPlacementSequence,
      status: "open",
      expiresAtElapsedDays: command.expiresAtElapsedDays,
      expiryEventId: expiryIntent?.eventId ?? null,
    };
    hub.nextPlacementSequence += 1;
    hub.orders.set(order.orderId, order);
    const intents = expiryIntent === null ? [matchIntent] : [expiryIntent, matchIntent];
    const result = success(order.orderId, intents.map((intent) => intent.eventId));
    recordCommand(hub, command, result);
    return {
      result,
      scheduledIntents: intents,
      events: [{
        eventType: "TradeHubOrderPlaced",
        commandId: command.commandId,
        elapsedDays,
        hubId: hub.hubId,
        orderId: order.orderId,
      }],
    };
  }

  cancelOrder(command: CancelTradeHubOrderCommand, elapsedDays: number): TradeHubCommandMutation {
    const replayed = this.replay(command);
    if (replayed !== null) return mutation(replayed);
    const hub = this.#hubs.get(command.hubId);
    if (hub === undefined) return this.#reject(command, "HUB_NOT_FOUND", `Unknown hub ${command.hubId}.`);
    const order = hub.orders.get(command.orderId);
    if (order === undefined) return this.#reject(command, "ORDER_NOT_FOUND", `Unknown order ${command.orderId}.`);
    if (order.accountEntityId !== command.accountEntityId) {
      return this.#reject(command, "ORDER_OWNER_MISMATCH", "Order belongs to another account.");
    }
    if (!isOpen(order)) return this.#reject(command, "ORDER_NOT_OPEN", `Order ${order.orderId} is closed.`);
    const closed = closeOrder(hub, order, "cancelled", elapsedDays, command.commandId, null);
    const result = success(order.orderId, []);
    recordCommand(hub, command, result);
    return { result, scheduledIntents: [], events: [closed] };
  }

  handleScheduledIntent(intent: ScheduledEventIntent, elapsedDays: number): readonly TradeHubEvent[] {
    if (intent.targetComponent !== TRADE_HUBS_COMPONENT) {
      throw new TradeHubValidationError(`Intent ${intent.eventId} does not target TradeHubs.`);
    }
    const hub = this.#hubs.get(intent.targetEntityId);
    if (hub === undefined) throw new TradeHubValidationError(`Intent targets unknown hub ${intent.targetEntityId}.`);
    if (hub.processedScheduledEventIds.has(intent.eventId)) {
      return [ignored(intent, elapsedDays, hub.hubId, "duplicate")];
    }
    hub.processedScheduledEventIds.add(intent.eventId);
    if (intent.kind === TRADE_HUB_MATCH_DUE) {
      const goodsId = readStringPayload(intent, "goodsId");
      return matchOrders(hub, goodsId, intent.eventId, elapsedDays);
    }
    if (intent.kind === TRADE_HUB_ORDER_EXPIRY_DUE) {
      const orderId = readStringPayload(intent, "orderId");
      const order = hub.orders.get(orderId);
      if (order === undefined || !isOpen(order)) {
        return [ignored(intent, elapsedDays, hub.hubId, "order_not_open")];
      }
      return [closeOrder(hub, order, "expired", elapsedDays, null, intent.eventId)];
    }
    throw new TradeHubValidationError(`Unsupported TradeHub intent kind ${intent.kind}.`);
  }

  isFacilityConnected(hubId: string, facilityHostId: string): boolean {
    return this.#hubs.get(hubId)?.connectedFacilityHostIds.has(facilityHostId) ?? false;
  }

  hubNodeId(hubId: string): string | null {
    return this.#hubs.get(hubId)?.nodeId ?? null;
  }

  snapshotsAtNode(nodeId: string): readonly TradeHubSnapshot[] {
    return this.snapshot().hubs.filter((hub) => hub.nodeId === nodeId);
  }

  snapshot(): TradeHubsSnapshot {
    return {
      hubs: [...this.#hubs.values()].map((hub) => ({
        hubId: hub.hubId,
        nodeId: hub.nodeId,
        ownerId: hub.ownerId,
        governorActorId: hub.governorActorId,
        connectedFacilityHostIds: [...hub.connectedFacilityHostIds],
        storageCaps: { ...hub.storageCaps },
        inventory: Object.fromEntries(hub.inventory),
        accounts: [...hub.accounts.values()].map((account) => ({
          accountEntityId: account.accountEntityId,
          availableGoods: Object.fromEntries(account.availableGoods),
          escrowGoods: Object.fromEntries(account.escrowGoods),
          availableCurrency: account.availableCurrency,
          escrowCurrency: account.escrowCurrency,
        })),
        orders: [...hub.orders.values()].map((order) => ({ ...order })),
        nextPlacementSequence: hub.nextPlacementSequence,
        nextScheduledEventOrdinal: hub.nextScheduledEventOrdinal,
        processedCommandIds: [...hub.processedCommands.values()].map((item) => structuredClone(item)),
        processedScheduledEventIds: [...hub.processedScheduledEventIds],
      })),
    };
  }

  #reject(
    command: TradeHubCommand,
    code: TradeHubCommandErrorCode,
    message: string,
  ): TradeHubCommandMutation {
    const result = failure(code, message, false);
    this.recordFailure(command, result);
    return mutation(result);
  }
}

function createHub(seed: TradeHubSnapshot): TradeHubRuntime {
  requireId(seed.hubId, "Hub id");
  requireId(seed.nodeId, `Hub ${seed.hubId} node id`);
  requireId(seed.ownerId, `Hub ${seed.hubId} owner id`);
  requireUnique(seed.connectedFacilityHostIds, `Hub ${seed.hubId} Facility connections`);
  validateQuantities(seed.storageCaps, `Hub ${seed.hubId} storage caps`, true);
  validateQuantities(seed.inventory, `Hub ${seed.hubId} inventory`, true);
  const accounts = new Map<string, TradeHubAccountRuntime>();
  for (const account of seed.accounts) {
    requireId(account.accountEntityId, "TradeHub account id");
    if (accounts.has(account.accountEntityId)) {
      throw new TradeHubValidationError(`Duplicate account ${account.accountEntityId}.`);
    }
    validateQuantities(account.availableGoods, `${account.accountEntityId} available goods`, true);
    validateQuantities(account.escrowGoods, `${account.accountEntityId} escrow goods`, true);
    requireNonNegativeSafeInteger(account.availableCurrency, `${account.accountEntityId} currency`);
    requireNonNegativeSafeInteger(account.escrowCurrency, `${account.accountEntityId} escrow currency`);
    accounts.set(account.accountEntityId, {
      accountEntityId: account.accountEntityId,
      availableGoods: new Map(Object.entries(account.availableGoods)),
      escrowGoods: new Map(Object.entries(account.escrowGoods)),
      availableCurrency: account.availableCurrency,
      escrowCurrency: account.escrowCurrency,
    });
  }
  const orders = new Map<string, TradeHubOrderRuntime>();
  const placementSequences = new Set<number>();
  for (const order of seed.orders) {
    validateOrder(order, seed.hubId, accounts, seed.storageCaps);
    if (orders.has(order.orderId)) throw new TradeHubValidationError(`Duplicate order ${order.orderId}.`);
    if (placementSequences.has(order.placementSequence)) {
      throw new TradeHubValidationError(`Duplicate placement sequence ${order.placementSequence}.`);
    }
    placementSequences.add(order.placementSequence);
    orders.set(order.orderId, { ...order });
  }
  requireNonNegativeSafeInteger(seed.nextPlacementSequence, `${seed.hubId} placement sequence`);
  if ([...orders.values()].some((order) => order.placementSequence >= seed.nextPlacementSequence)) {
    throw new TradeHubValidationError(`Hub ${seed.hubId} next placement sequence is not ahead of orders.`);
  }
  requireNonNegativeSafeInteger(seed.nextScheduledEventOrdinal, `${seed.hubId} event ordinal`);
  const processedCommands = new Map<string, ProcessedTradeHubCommandSnapshot>();
  for (const item of seed.processedCommandIds) {
    requireId(item.commandId, "Processed command id");
    if (processedCommands.has(item.commandId)) {
      throw new TradeHubValidationError(`Duplicate processed command ${item.commandId}.`);
    }
    processedCommands.set(item.commandId, structuredClone(item));
  }
  requireUnique(seed.processedScheduledEventIds, `${seed.hubId} processed event ids`);
  const hub: TradeHubRuntime = {
    hubId: seed.hubId,
    nodeId: seed.nodeId,
    ownerId: seed.ownerId,
    governorActorId: seed.governorActorId,
    connectedFacilityHostIds: new Set(seed.connectedFacilityHostIds),
    storageCaps: { ...seed.storageCaps },
    inventory: new Map(Object.entries(seed.inventory)),
    accounts,
    orders,
    nextPlacementSequence: seed.nextPlacementSequence,
    nextScheduledEventOrdinal: seed.nextScheduledEventOrdinal,
    processedCommands,
    processedScheduledEventIds: new Set(seed.processedScheduledEventIds),
  };
  validatePhysicalInventory(hub);
  validateEscrowAgainstOrders(hub);
  let totalCurrency = 0;
  for (const account of hub.accounts.values()) {
    totalCurrency = safeSum(totalCurrency, account.availableCurrency, `Hub ${hub.hubId} currency`);
    totalCurrency = safeSum(totalCurrency, account.escrowCurrency, `Hub ${hub.hubId} currency`);
  }
  return hub;
}

function matchOrders(
  hub: TradeHubRuntime,
  goodsId: string,
  eventId: string,
  elapsedDays: number,
): readonly TradeHubEvent[] {
  const events: TradeHubEvent[] = [];
  while (true) {
    const buy = [...hub.orders.values()]
      .filter((order) => isOpen(order) && order.side === "buy" && order.goodsId === goodsId)
      .sort((left, right) => right.limitPrice - left.limitPrice
        || left.placementSequence - right.placementSequence)[0];
    const sell = [...hub.orders.values()]
      .filter((order) => isOpen(order) && order.side === "sell" && order.goodsId === goodsId)
      .sort((left, right) => left.limitPrice - right.limitPrice
        || left.placementSequence - right.placementSequence)[0];
    if (buy === undefined || sell === undefined || buy.limitPrice < sell.limitPrice) break;
    const quantity = Math.min(buy.remainingQuantity, sell.remainingQuantity);
    const unitPrice = buy.placementSequence < sell.placementSequence
      ? buy.limitPrice
      : sell.limitPrice;
    const totalPrice = safeProduct(quantity, unitPrice, "Trade total");
    const reservedReduction = safeProduct(quantity, buy.limitPrice, "Buy escrow reduction");
    const buyer = hub.accounts.get(buy.accountEntityId)!;
    const seller = hub.accounts.get(sell.accountEntityId)!;

    buyer.escrowCurrency -= reservedReduction;
    buyer.availableCurrency += reservedReduction - totalPrice;
    seller.availableCurrency += totalPrice;
    add(seller.escrowGoods, goodsId, -quantity);
    add(buyer.availableGoods, goodsId, quantity);
    buy.remainingQuantity -= quantity;
    sell.remainingQuantity -= quantity;
    buy.status = buy.remainingQuantity === 0 ? "filled" : "partially_filled";
    sell.status = sell.remainingQuantity === 0 ? "filled" : "partially_filled";
    events.push({
      eventType: "TradeHubTradeExecuted",
      scheduledEventId: eventId,
      elapsedDays,
      hubId: hub.hubId,
      goodsId,
      buyOrderId: buy.orderId,
      sellOrderId: sell.orderId,
      quantity,
      unitPrice,
      totalPrice,
    });
  }
  return events;
}

function closeOrder(
  hub: TradeHubRuntime,
  order: TradeHubOrderRuntime,
  status: "cancelled" | "expired",
  elapsedDays: number,
  commandId: string | null,
  scheduledEventId: string | null,
): TradeHubOrderClosedEvent {
  const account = hub.accounts.get(order.accountEntityId)!;
  let releasedGoods = 0;
  let releasedCurrency = 0;
  if (order.side === "sell") {
    releasedGoods = order.remainingQuantity;
    add(account.escrowGoods, order.goodsId, -releasedGoods);
    add(account.availableGoods, order.goodsId, releasedGoods);
  } else {
    releasedCurrency = safeProduct(order.remainingQuantity, order.limitPrice, "Escrow release");
    account.escrowCurrency -= releasedCurrency;
    account.availableCurrency += releasedCurrency;
  }
  order.status = status;
  return {
    eventType: status === "cancelled" ? "TradeHubOrderCancelled" : "TradeHubOrderExpired",
    commandId,
    scheduledEventId,
    elapsedDays,
    hubId: hub.hubId,
    orderId: order.orderId,
    releasedGoods,
    releasedCurrency,
  };
}

function createScheduledIntent(
  hub: TradeHubRuntime,
  kind: typeof TRADE_HUB_MATCH_DUE | typeof TRADE_HUB_ORDER_EXPIRY_DUE,
  dueElapsedDays: number,
  payload: Readonly<Record<string, SerializableValue>>,
): ScheduledEventIntent {
  const eventId = `${hub.hubId}:trade:${hub.nextScheduledEventOrdinal}`;
  hub.nextScheduledEventOrdinal += 1;
  return {
    eventId,
    kind,
    dueElapsedDays,
    targetComponent: TRADE_HUBS_COMPONENT,
    targetEntityId: hub.hubId,
    payload,
  };
}

function recordCommand(hub: TradeHubRuntime, command: TradeHubCommand, result: TradeHubCommandResult): void {
  hub.processedCommands.set(command.commandId, {
    commandId: command.commandId,
    fingerprint: fingerprint(command),
    result: structuredClone({ ...result, idempotentReplay: false }),
  });
}

function fingerprint(command: TradeHubCommand): string {
  return JSON.stringify(sortSerializable(command as unknown as SerializableValue));
}

function sortSerializable(value: SerializableValue): SerializableValue {
  if (value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(sortSerializable);
  return Object.fromEntries(
    Object.entries(value).sort(([left], [right]) => left < right ? -1 : left > right ? 1 : 0)
      .map(([key, item]) => [key, sortSerializable(item)]),
  );
}

function validatePhysicalInventory(hub: TradeHubRuntime): void {
  const accountTotals = new Map<string, number>();
  for (const account of hub.accounts.values()) {
    for (const [goodsId, amount] of account.availableGoods) add(accountTotals, goodsId, amount);
    for (const [goodsId, amount] of account.escrowGoods) add(accountTotals, goodsId, amount);
  }
  const goodsIds = new Set([...hub.inventory.keys(), ...accountTotals.keys()]);
  for (const goodsId of goodsIds) {
    const inventory = hub.inventory.get(goodsId) ?? 0;
    if (inventory !== (accountTotals.get(goodsId) ?? 0)) {
      throw new TradeHubValidationError(`Hub ${hub.hubId} inventory ${goodsId} is not conserved.`);
    }
    const cap = hub.storageCaps[goodsId];
    if (cap === undefined || inventory > cap) {
      throw new TradeHubValidationError(`Hub ${hub.hubId} inventory ${goodsId} exceeds capacity.`);
    }
  }
}

function validateEscrowAgainstOrders(hub: TradeHubRuntime): void {
  for (const account of hub.accounts.values()) {
    const expectedGoods = new Map<string, number>();
    let expectedCurrency = 0;
    for (const order of hub.orders.values()) {
      if (order.accountEntityId !== account.accountEntityId || !isOpen(order)) continue;
      if (order.side === "sell") add(expectedGoods, order.goodsId, order.remainingQuantity);
      else expectedCurrency += safeProduct(order.remainingQuantity, order.limitPrice, "Loaded escrow");
    }
    if (expectedCurrency !== account.escrowCurrency) {
      throw new TradeHubValidationError(`Account ${account.accountEntityId} currency escrow mismatch.`);
    }
    const goodsIds = new Set([...expectedGoods.keys(), ...account.escrowGoods.keys()]);
    for (const goodsId of goodsIds) {
      if ((expectedGoods.get(goodsId) ?? 0) !== (account.escrowGoods.get(goodsId) ?? 0)) {
        throw new TradeHubValidationError(`Account ${account.accountEntityId} goods escrow mismatch.`);
      }
    }
  }
}

function validateOrder(
  order: TradeHubOrderSnapshot,
  hubId: string,
  accounts: ReadonlyMap<string, TradeHubAccountRuntime>,
  storageCaps: Readonly<Record<string, number>>,
): void {
  requireId(order.orderId, `Hub ${hubId} order id`);
  if (!accounts.has(order.accountEntityId)) throw new TradeHubValidationError(`Order ${order.orderId} has missing account.`);
  requireId(order.goodsId, `Order ${order.orderId} goods id`);
  if (storageCaps[order.goodsId] === undefined) {
    throw new TradeHubValidationError(`Order ${order.orderId} uses unsupported goods.`);
  }
  if (order.side !== "buy" && order.side !== "sell") {
    throw new TradeHubValidationError(`Order ${order.orderId} side is invalid.`);
  }
  if (!["open", "partially_filled", "filled", "cancelled", "expired"].includes(order.status)) {
    throw new TradeHubValidationError(`Order ${order.orderId} status is invalid.`);
  }
  requireNonNegativeSafeInteger(order.remainingQuantity, `Order ${order.orderId} remaining quantity`);
  if (!isPositiveSafeInteger(order.originalQuantity) || order.remainingQuantity > order.originalQuantity) {
    throw new TradeHubValidationError(`Order ${order.orderId} quantities are invalid.`);
  }
  if (!isPositiveSafeInteger(order.limitPrice)) throw new TradeHubValidationError(`Order ${order.orderId} price is invalid.`);
  requireNonNegativeSafeInteger(order.placementSequence, `Order ${order.orderId} placement sequence`);
  if (order.status === "filled" && order.remainingQuantity !== 0) {
    throw new TradeHubValidationError(`Filled order ${order.orderId} has remaining quantity.`);
  }
  if (isOpen(order) && order.remainingQuantity === 0) {
    throw new TradeHubValidationError(`Open order ${order.orderId} has no remaining quantity.`);
  }
}

function readStringPayload(intent: ScheduledEventIntent, key: string): string {
  if (intent.payload === null || typeof intent.payload !== "object" || Array.isArray(intent.payload)) {
    throw new TradeHubValidationError(`Intent ${intent.eventId} payload must be an object.`);
  }
  const value = (intent.payload as Readonly<Record<string, SerializableValue>>)[key];
  if (typeof value !== "string" || value.length === 0) {
    throw new TradeHubValidationError(`Intent ${intent.eventId} payload.${key} is invalid.`);
  }
  return value;
}

function validateCommandIdentity(command: TradeHubCommandIdentity): void {
  requireId(command.commandId, "TradeHub command id");
  requireId(command.hubId, "TradeHub command hub id");
}

function validateQuantities(
  quantities: Readonly<Record<string, number>>,
  label: string,
  allowZero: boolean,
): void {
  for (const [goodsId, amount] of Object.entries(quantities)) {
    requireId(goodsId, label);
    if (!Number.isSafeInteger(amount) || amount < 0 || (!allowZero && amount === 0)) {
      throw new TradeHubValidationError(`${label} ${goodsId} is invalid.`);
    }
  }
}

function requireUnique(values: readonly string[], label: string): void {
  if (new Set(values).size !== values.length) throw new TradeHubValidationError(`${label} contains duplicates.`);
  values.forEach((value) => requireId(value, label));
}

function requireId(value: string, label: string): void {
  if (value.length === 0) throw new TradeHubValidationError(`${label} must not be empty.`);
}

function requireNonNegativeSafeInteger(value: number, label: string): void {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new TradeHubValidationError(`${label} must be a non-negative safe integer.`);
  }
}

function isPositiveSafeInteger(value: number): boolean {
  return Number.isSafeInteger(value) && value > 0;
}

function safeProduct(left: number, right: number, label: string): number {
  const result = left * right;
  if (!Number.isSafeInteger(result) || result < 0) {
    throw new TradeHubValidationError(`${label} exceeds safe integer range.`);
  }
  return result;
}

function safeSum(left: number, right: number, label: string): number {
  const result = left + right;
  if (!Number.isSafeInteger(result) || result < 0) {
    throw new TradeHubValidationError(`${label} exceeds safe integer range.`);
  }
  return result;
}

function add(store: Map<string, number>, id: string, change: number): void {
  const result = (store.get(id) ?? 0) + change;
  if (result < 0 || !Number.isSafeInteger(result)) {
    throw new TradeHubValidationError(`Quantity mutation for ${id} is invalid.`);
  }
  if (result === 0) store.delete(id);
  else store.set(id, result);
}

function isOpen(order: Pick<TradeHubOrderSnapshot, "status">): boolean {
  return order.status === "open" || order.status === "partially_filled";
}

function success(orderId: string | null, scheduledEventIds: readonly string[]): TradeHubCommandSuccess {
  return { accepted: true, idempotentReplay: false, orderId, scheduledEventIds: [...scheduledEventIds] };
}

function failure(
  errorCode: TradeHubCommandErrorCode,
  message: string,
  idempotentReplay: boolean,
): TradeHubCommandFailure {
  return { accepted: false, idempotentReplay, errorCode, message };
}

function mutation(result: TradeHubCommandResult): TradeHubCommandMutation {
  return { result, scheduledIntents: [], events: [] };
}

function ignored(
  intent: ScheduledEventIntent,
  elapsedDays: number,
  hubId: string,
  reason: TradeHubScheduledIntentIgnoredEvent["reason"],
): TradeHubScheduledIntentIgnoredEvent {
  return {
    eventType: "TradeHubScheduledIntentIgnored",
    scheduledEventId: intent.eventId,
    elapsedDays,
    hubId,
    reason,
  };
}
