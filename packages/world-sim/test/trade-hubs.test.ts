import assert from "node:assert/strict";
import test from "node:test";

import { TradeHubs } from "../src/index.js";
import type {
  PlaceTradeHubOrderCommand,
  TradeHubSnapshot,
  TradeHubsSnapshot,
  TransferTradeHubGoodsCommand,
} from "../src/index.js";

test("two TradeHub instances never share warehouse inventory", () => {
  const hubs = createTradeHubs();
  const deposit = hubs.transferGoods(transfer("deposit-a", "hub-a", "seller", "grain", 5), 0);
  assert.equal(deposit.result.accepted, true);

  const snapshot = hubs.snapshot();
  assert.deepEqual(snapshot.hubs[0]?.inventory, { grain: 5 });
  assert.deepEqual(snapshot.hubs[1]?.inventory, {});
  const remoteWithdraw = hubs.transferGoods(
    transfer("withdraw-b", "hub-b", "seller", "grain", 1, "withdraw"),
    0,
  );
  assert.equal(remoteWithdraw.result.accepted, false);
  assert.deepEqual(hubs.snapshot().hubs[1]?.inventory, {});
});

test("sell order without a physical deposit is rejected atomically", () => {
  const hubs = createTradeHubs();
  const before = hubs.snapshot();
  const result = hubs.placeOrder(order("sell-1", "hub-a", "seller", "sell", 2, 4), 0);

  assert.equal(result.result.accepted, false);
  if (result.result.accepted) assert.fail("Expected sell rejection.");
  assert.equal(result.result.errorCode, "INSUFFICIENT_HUB_GOODS");
  assert.deepEqual(hubs.snapshot().hubs[0]?.inventory, before.hubs[0]?.inventory);
  assert.deepEqual(hubs.snapshot().hubs[0]?.orders, []);
});

test("cancellation releases remaining escrow exactly once and commands are idempotent", () => {
  const hubs = createTradeHubs();
  hubs.transferGoods(transfer("deposit", "hub-a", "seller", "grain", 5), 0);
  hubs.placeOrder(order("sell", "hub-a", "seller", "sell", 5, 4), 0);
  const command = {
    commandId: "cancel-1",
    issuerActorId: "seller_actor",
    accountEntityId: "seller",
    hubId: "hub-a",
    orderId: "sell-order",
  } as const;

  const first = hubs.cancelOrder(command, 0);
  const replay = hubs.cancelOrder(command, 0);
  const secondId = hubs.cancelOrder({ ...command, commandId: "cancel-2" }, 0);

  assert.equal(first.result.accepted, true);
  assert.equal(replay.result.accepted && replay.result.idempotentReplay, true);
  assert.equal(secondId.result.accepted, false);
  assert.deepEqual(hubs.snapshot().hubs[0]?.accounts[0]?.availableGoods, { grain: 5 });
  assert.deepEqual(hubs.snapshot().hubs[0]?.accounts[0]?.escrowGoods, {});
});

test("matching uses price then stable placement order for simultaneous offers", () => {
  const hubs = createTradeHubs();
  hubs.transferGoods(transfer("dep-a", "hub-a", "seller", "grain", 2), 0);
  hubs.transferGoods(transfer("dep-b", "hub-a", "seller-2", "grain", 2), 0);
  const first = hubs.placeOrder(order("sell-a", "hub-a", "seller", "sell", 2, 5), 0);
  const second = hubs.placeOrder(order("sell-b", "hub-a", "seller-2", "sell", 2, 5), 0);
  const buy = hubs.placeOrder(order("buy", "hub-a", "buyer", "buy", 3, 5), 0);

  const matchIntent = buy.scheduledIntents.at(-1)!;
  const events = hubs.handleScheduledIntent(matchIntent, 0);
  assert.deepEqual(events.filter((event) => event.eventType === "TradeHubTradeExecuted")
    .map((event) => event.eventType === "TradeHubTradeExecuted" && [event.sellOrderId, event.quantity]), [
      ["sell-order", 2],
      ["sell-b-order", 1],
    ]);
  assert.equal(first.result.accepted, true);
  assert.equal(second.result.accepted, true);
});

test("partial fills conserve physical goods and account escrow balances", () => {
  const hubs = createTradeHubs();
  hubs.transferGoods(transfer("deposit", "hub-a", "seller", "grain", 10), 0);
  hubs.placeOrder(order("sell", "hub-a", "seller", "sell", 10, 8), 0);
  const buy = hubs.placeOrder(order("buy", "hub-a", "buyer", "buy", 4, 10), 0);
  hubs.handleScheduledIntent(buy.scheduledIntents.at(-1)!, 0);

  const hub = hubs.snapshot().hubs[0]!;
  const seller = hub.accounts.find((account) => account.accountEntityId === "seller")!;
  const buyer = hub.accounts.find((account) => account.accountEntityId === "buyer")!;
  assert.deepEqual(hub.inventory, { grain: 10 });
  assert.deepEqual(seller.escrowGoods, { grain: 6 });
  assert.equal(seller.availableCurrency, 32);
  assert.deepEqual(buyer.availableGoods, { grain: 4 });
  assert.equal(buyer.availableCurrency, 68);
  assert.equal(buyer.escrowCurrency, 0);
  assert.equal(hub.orders.find((item) => item.orderId === "sell-order")?.remainingQuantity, 6);
});

test("capacity failure preserves all TradeHub state", () => {
  const hubs = createTradeHubs(2);
  hubs.transferGoods(transfer("first", "hub-a", "seller", "grain", 2), 0);
  const before = hubs.snapshot();
  const rejected = hubs.transferGoods(transfer("overflow", "hub-a", "seller", "grain", 1), 0);
  assert.equal(rejected.result.accepted, false);
  assert.deepEqual(hubs.snapshot().hubs[0]?.inventory, before.hubs[0]?.inventory);
  assert.deepEqual(hubs.snapshot().hubs[0]?.accounts, before.hubs[0]?.accounts);
});

test("scheduled matching event ids are idempotent", () => {
  const hubs = createTradeHubs();
  hubs.transferGoods(transfer("deposit", "hub-a", "seller", "grain", 2), 0);
  hubs.placeOrder(order("sell", "hub-a", "seller", "sell", 2, 5), 0);
  const buy = hubs.placeOrder(order("buy", "hub-a", "buyer", "buy", 2, 5), 0);
  const intent = buy.scheduledIntents.at(-1)!;

  const first = hubs.handleScheduledIntent(intent, 0);
  const afterFirst = hubs.snapshot();
  const duplicate = hubs.handleScheduledIntent(intent, 0);

  assert.equal(first.filter((event) => event.eventType === "TradeHubTradeExecuted").length, 1);
  assert.equal(duplicate[0]?.eventType, "TradeHubScheduledIntentIgnored");
  assert.deepEqual(hubs.snapshot(), afterFirst);
});

test("reusing a command id with a different payload is rejected without mutation", () => {
  const hubs = createTradeHubs();
  const first = hubs.transferGoods(transfer("same-id", "hub-a", "seller", "grain", 2), 0);
  assert.equal(first.result.accepted, true);
  const before = hubs.snapshot().hubs[0]!;

  const conflict = hubs.transferGoods(transfer("same-id", "hub-a", "seller", "grain", 3), 0);
  assert.equal(conflict.result.accepted, false);
  if (conflict.result.accepted) assert.fail("Expected command id conflict.");
  assert.equal(conflict.result.errorCode, "COMMAND_ID_CONFLICT");
  const after = hubs.snapshot().hubs[0]!;
  assert.deepEqual(after.inventory, before.inventory);
  assert.deepEqual(after.accounts, before.accounts);
  assert.deepEqual(after.orders, before.orders);
});

function createTradeHubs(grainCap = 20): TradeHubs {
  return new TradeHubs({ hubs: [hub("hub-a", "wroclaw", grainCap), hub("hub-b", "opole", 20)] });
}

function hub(hubId: string, nodeId: string, grainCap: number): TradeHubSnapshot {
  return {
    hubId,
    nodeId,
    ownerId: `${hubId}-owner`,
    governorActorId: `${hubId}-governor`,
    connectedFacilityHostIds: hubId === "hub-a" ? ["farm-host"] : [],
    storageCaps: { grain: grainCap, tools: 10 },
    inventory: {},
    accounts: [
      { accountEntityId: "seller", availableGoods: {}, escrowGoods: {}, availableCurrency: 0, escrowCurrency: 0 },
      { accountEntityId: "seller-2", availableGoods: {}, escrowGoods: {}, availableCurrency: 0, escrowCurrency: 0 },
      { accountEntityId: "buyer", availableGoods: {}, escrowGoods: {}, availableCurrency: 100, escrowCurrency: 0 },
    ],
    orders: [],
    nextPlacementSequence: 0,
    nextScheduledEventOrdinal: 0,
    processedCommandIds: [],
    processedScheduledEventIds: [],
  };
}

function transfer(
  commandId: string,
  hubId: string,
  accountEntityId: string,
  goodsId: string,
  amount: number,
  direction: TransferTradeHubGoodsCommand["direction"] = "deposit",
): TransferTradeHubGoodsCommand {
  return { commandId, hubId, issuerActorId: `${accountEntityId}_actor`, accountEntityId, goodsId, amount, direction };
}

function order(
  commandId: string,
  hubId: string,
  accountEntityId: string,
  side: PlaceTradeHubOrderCommand["side"],
  quantity: number,
  limitPrice: number,
): PlaceTradeHubOrderCommand {
  return {
    commandId,
    hubId,
    issuerActorId: `${accountEntityId}_actor`,
    accountEntityId,
    orderId: commandId === "sell-a" || commandId === "sell" ? "sell-order" : `${commandId}-order`,
    side,
    goodsId: "grain",
    quantity,
    limitPrice,
    expiresAtElapsedDays: null,
  };
}
