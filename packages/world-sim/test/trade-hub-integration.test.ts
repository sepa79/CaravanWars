import assert from "node:assert/strict";
import test from "node:test";
import { resolve } from "node:path";

import {
  Facilities,
  Governance,
  TRADE_HUBS_COMPONENT,
  TRADE_HUB_MATCH_DUE,
  TRADE_HUB_ORDER_EXPIRY_DUE,
  TradeHubs,
  WorldClock,
  WorldSimulation,
  WorldSimulationFoundation,
  loadPartyTravelConfigFile,
  loadRegionGraphFile,
} from "../src/index.js";
import type {
  GoodsCatalog,
  TradeHubSnapshot,
  WorldCommandEnvelope,
  WorldEconomySeed,
} from "../src/index.js";

test("Facility goods cross two independent TradeHubs only through physical party transport", () => {
  const { world } = createPhysicalScenario();
  world.advanceDays(0.25);

  assertAccepted(submit(world, "trade_hub_transfer_facility_goods", {
    commandId: "facility-deposit",
    issuerActorId: "settlement_governor",
    accountEntityId: "settlement_account",
    hubId: "hub-a",
    facilityId: "farm",
    facilityHostId: "farm-host",
    goodsId: "grain",
    amount: 6,
    direction: "deposit",
  }));
  assertAccepted(submit(world, "place_trade_hub_order", {
    commandId: "sell-command",
    issuerActorId: "settlement_governor",
    accountEntityId: "settlement_account",
    hubId: "hub-a",
    orderId: "sell-order",
    side: "sell",
    goodsId: "grain",
    quantity: 6,
    limitPrice: 2,
    expiresAtElapsedDays: null,
  }));
  assertAccepted(submit(world, "place_trade_hub_order", {
    commandId: "buy-command",
    issuerActorId: "merchant_actor",
    accountEntityId: "merchant",
    hubId: "hub-a",
    orderId: "buy-order",
    side: "buy",
    goodsId: "grain",
    quantity: 4,
    limitPrice: 2,
    expiresAtElapsedDays: null,
  }));
  world.advanceDays(0.01);

  let foundation = world.snapshot().simulationFoundation!;
  assert.deepEqual(hubById(foundation.tradeHubs!, "hub-a").inventory, { grain: 6 });
  assert.deepEqual(hubById(foundation.tradeHubs!, "hub-b").inventory, {});
  assertAccepted(submit(world, "trade_hub_transfer_party_goods", {
    commandId: "merchant-pickup",
    issuerActorId: "merchant_actor",
    accountEntityId: "merchant",
    partyId: "merchant",
    hubId: "hub-a",
    goodsId: "grain",
    amount: 4,
    direction: "withdraw",
  }));
  assert.equal(world.partySnapshot("merchant").cargo.grain, 4);

  assertAccepted(submit(world, "move_party", {
    party_id: "merchant",
    from_node_id: "wroclaw",
    to_node_id: "opole",
  }));
  world.advanceDays(6);
  assert.equal(world.partySnapshot("merchant").currentNodeId, "opole");
  assertAccepted(submit(world, "trade_hub_transfer_party_goods", {
    commandId: "merchant-deposit-b",
    issuerActorId: "merchant_actor",
    accountEntityId: "merchant",
    partyId: "merchant",
    hubId: "hub-b",
    goodsId: "grain",
    amount: 4,
    direction: "deposit",
  }));

  foundation = world.snapshot().simulationFoundation!;
  assert.deepEqual(hubById(foundation.tradeHubs!, "hub-a").inventory, { grain: 2 });
  assert.deepEqual(hubById(foundation.tradeHubs!, "hub-b").inventory, { grain: 4 });
  assert.deepEqual(world.partySnapshot("merchant").cargo, {});
});

test("remote hub deposit is rejected without mutating party or either hub", () => {
  const { world } = createPhysicalScenario({ merchantCargo: { tools: 2 } });
  const before = world.snapshot();
  const result = submit(world, "trade_hub_transfer_party_goods", {
    commandId: "teleport-attempt",
    issuerActorId: "merchant_actor",
    accountEntityId: "merchant",
    partyId: "merchant",
    hubId: "hub-b",
    goodsId: "tools",
    amount: 2,
    direction: "deposit",
  });
  assert.equal(result.accepted, false);
  assert.deepEqual(world.partySnapshot("merchant").cargo, { tools: 2 });
  const afterHubs = world.snapshot().simulationFoundation!.tradeHubs!;
  const beforeHubs = before.simulationFoundation!.tradeHubs!;
  assert.deepEqual(afterHubs.hubs.map((hub) => hub.inventory), beforeHubs.hubs.map((hub) => hub.inventory));
  assert.deepEqual(afterHubs.hubs.map((hub) => hub.accounts), beforeHubs.hubs.map((hub) => hub.accounts));
  assert.deepEqual(afterHubs.hubs.map((hub) => hub.orders), beforeHubs.hubs.map((hub) => hub.orders));
});

test("Governance rejects an unauthorized TradeHub order without reserving escrow", () => {
  const { world } = createPhysicalScenario();
  const before = world.snapshot().simulationFoundation!.tradeHubs!;
  const result = submit(world, "place_trade_hub_order", {
    commandId: "unauthorized-buy",
    issuerActorId: "unlisted_actor",
    accountEntityId: "merchant",
    hubId: "hub-a",
    orderId: "unauthorized-order",
    side: "buy",
    goodsId: "grain",
    quantity: 2,
    limitPrice: 2,
    expiresAtElapsedDays: null,
  });
  assert.equal(result.accepted, false);
  if (result.accepted) assert.fail("Expected authority rejection.");
  assert.equal(result.errorCode, "NOT_AUTHORIZED");
  const after = world.snapshot().simulationFoundation!.tradeHubs!;
  assert.deepEqual(after.hubs[0]?.accounts, before.hubs[0]?.accounts);
  assert.deepEqual(after.hubs[0]?.orders, before.hubs[0]?.orders);
});

test("WorldClock scheduling failure rolls back order escrow and book mutation", () => {
  const { world } = createPhysicalScenario({ preScheduleTradeEventCollision: true });
  const before = world.snapshot().simulationFoundation!.tradeHubs!;
  const result = submit(world, "place_trade_hub_order", {
    commandId: "colliding-buy",
    issuerActorId: "merchant_actor",
    accountEntityId: "merchant",
    hubId: "hub-a",
    orderId: "colliding-order",
    side: "buy",
    goodsId: "grain",
    quantity: 2,
    limitPrice: 2,
    expiresAtElapsedDays: null,
  });
  assert.equal(result.accepted, false);
  if (result.accepted) assert.fail("Expected scheduling rejection.");
  assert.equal(result.errorCode, "SCHEDULING_FAILED");
  const after = world.snapshot().simulationFoundation!.tradeHubs!;
  assert.deepEqual(after.hubs[0]?.accounts, before.hubs[0]?.accounts);
  assert.deepEqual(after.hubs[0]?.orders, before.hubs[0]?.orders);
});

test("same-time expiry and matching follow WorldClock scheduling sequence", () => {
  const expiryFirst = createScheduledBookFoundation();
  expiryFirst.schedule(tradeIntent("expiry", TRADE_HUB_ORDER_EXPIRY_DUE, { orderId: "sell" }));
  expiryFirst.schedule(tradeIntent("match", TRADE_HUB_MATCH_DUE, { goodsId: "grain" }));
  expiryFirst.advanceDays(1);
  assert.equal(expiryFirst.snapshot().events.some((event) =>
    event.eventType === "TradeHubTradeExecuted"), false);

  const matchFirst = createScheduledBookFoundation();
  matchFirst.schedule(tradeIntent("match", TRADE_HUB_MATCH_DUE, { goodsId: "grain" }));
  matchFirst.schedule(tradeIntent("expiry", TRADE_HUB_ORDER_EXPIRY_DUE, { orderId: "sell" }));
  matchFirst.advanceDays(1);
  assert.equal(matchFirst.snapshot().events.filter((event) =>
    event.eventType === "TradeHubTradeExecuted").length, 1);
});

test("TradeHub save/load produces identical deterministic continuation", () => {
  const original = createScheduledBookFoundation();
  original.schedule(tradeIntent("match", TRADE_HUB_MATCH_DUE, { goodsId: "grain" }));
  original.advanceDays(0.5);
  const restored = WorldSimulationFoundation.fromSnapshot(
    JSON.parse(JSON.stringify(original.snapshot())) as ReturnType<WorldSimulationFoundation["snapshot"]>,
  );

  original.advanceDays(0.5);
  restored.advanceDays(0.5);
  assert.deepEqual(restored.snapshot(), original.snapshot());
});

function createPhysicalScenario(options: {
  merchantCargo?: Readonly<Record<string, number>>;
  preScheduleTradeEventCollision?: boolean;
} = {}): {
  readonly world: WorldSimulation;
} {
  const clock = new WorldClock();
  const facilities = new Facilities([{
    facilityId: "farm",
    facilityType: "fixture_producer",
    hostId: "farm-host",
    ownerId: "settlement",
    governorActorId: "settlement_governor",
    recipe: {
      inputs: {}, energyInputs: {}, maintenanceInputs: {}, outputs: { grain: 6 },
      workforceRequired: 1, cycleDays: 0.25, blockedRetryDays: null, shortagePolicies: [],
    },
    active: true,
    generation: 0,
    nextEventOrdinal: 0,
    pendingTickEventId: null,
    processedEventIds: [],
  }], [{
    hostId: "farm-host",
    inventory: {},
    storageCaps: { grain: 30, tools: 10 },
    cohorts: [{ cohortId: "workers", population: 5, availableWorkforce: 5, unrest: 0 }],
  }]);
  const tradeHubs = new TradeHubs({ hubs: [
    physicalHub("hub-a", "wroclaw", ["farm-host"]),
    physicalHub("hub-b", "opole", []),
  ] });
  const foundation = new WorldSimulationFoundation({
    clock,
    facilities,
    tradeHubs,
    governance: new Governance({
      managedEntities: [
        { entityId: "farm", ownerId: "settlement", governorActorId: "settlement_governor" },
        { entityId: "settlement_account", ownerId: "settlement", governorActorId: "settlement_governor" },
        { entityId: "merchant", ownerId: "merchant", governorActorId: "merchant_actor" },
      ],
      governors: [
        {
          actorId: "settlement_governor", principalId: "settlement", superiorActorId: null,
          roles: ["configured_trader"], authorityScopes: ["trade:transfer", "trade:order", "trade:cancel"],
          controller: "deterministic_policy",
        },
        {
          actorId: "merchant_actor", principalId: "merchant", superiorActorId: null,
          roles: ["configured_merchant"], authorityScopes: ["trade:transfer", "trade:order", "trade:cancel"],
          controller: "human",
        },
      ],
      delegations: [],
    }),
    maxEventsPerAdvance: 1000,
  });
  foundation.scheduleInitialFacilityTick("farm");
  if (options.preScheduleTradeEventCollision === true) {
    foundation.schedule({
      eventId: "hub-a:trade:0",
      kind: TRADE_HUB_MATCH_DUE,
      dueElapsedDays: 1,
      targetComponent: TRADE_HUBS_COMPONENT,
      targetEntityId: "hub-a",
      payload: { goodsId: "grain" },
    });
  }
  const catalog = syntheticCatalog();
  const profiles = [
    { locationId: "wroclaw-location", productionPerDay: {}, consumptionPerDay: {}, storageCaps: { grain: 30, tools: 10 } },
    { locationId: "opole-location", productionPerDay: {}, consumptionPerDay: {}, storageCaps: { grain: 30, tools: 10 } },
  ];
  const economy: WorldEconomySeed = {
    goodsCatalog: catalog,
    partyCargoConfig: { footCapacityBulk: 1, horseCapacityBulk: 0, packAnimalCapacityBulk: 0, wagonCapacityBulk: 20 },
    locationEconomyConfig: {
      profiles,
      profilesByLocationId: new Map(profiles.map((profile) => [profile.locationId, profile])),
    },
    locations: [
      { id: "wroclaw-location", displayName: "A", managerActorId: "settlement_governor", nodeId: "wroclaw", resources: {} },
      { id: "opole-location", displayName: "B", managerActorId: "settlement_governor", nodeId: "opole", resources: {} },
    ],
  };
  return {
    world: new WorldSimulation(
      loadRegionGraphFile(resolve("data/regions/silesia.json")),
      loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json")),
      [{
        id: "merchant", displayName: "Merchant", managerActorId: "merchant_actor", nodeId: "wroclaw",
        composition: { footCount: 1, horseCount: 0, wagonCount: 1, packAnimalCount: 0, guardCount: 0 },
        knownRouteIds: ["wroclaw_opole"], cargo: options.merchantCargo ?? {},
      }],
      economy,
      clock,
      foundation,
    ),
  };
}

function physicalHub(hubId: string, nodeId: string, connections: readonly string[]): TradeHubSnapshot {
  return {
    hubId, nodeId, ownerId: `${hubId}-owner`, governorActorId: null,
    connectedFacilityHostIds: connections,
    storageCaps: { grain: 30, tools: 10 }, inventory: {},
    accounts: [
      { accountEntityId: "settlement_account", availableGoods: {}, escrowGoods: {}, availableCurrency: 0, escrowCurrency: 0 },
      { accountEntityId: "merchant", availableGoods: {}, escrowGoods: {}, availableCurrency: 20, escrowCurrency: 0 },
    ],
    orders: [], nextPlacementSequence: 0, nextScheduledEventOrdinal: 0,
    processedCommandIds: [], processedScheduledEventIds: [],
  };
}

function createScheduledBookFoundation(): WorldSimulationFoundation {
  const hub: TradeHubSnapshot = {
    hubId: "hub", nodeId: "wroclaw", ownerId: "owner", governorActorId: null,
    connectedFacilityHostIds: [], storageCaps: { grain: 10, tools: 10 }, inventory: { grain: 5 },
    accounts: [
      { accountEntityId: "seller", availableGoods: {}, escrowGoods: { grain: 5 }, availableCurrency: 0, escrowCurrency: 0 },
      { accountEntityId: "buyer", availableGoods: {}, escrowGoods: {}, availableCurrency: 0, escrowCurrency: 25 },
    ],
    orders: [
      { orderId: "sell", accountEntityId: "seller", side: "sell", goodsId: "grain", originalQuantity: 5, remainingQuantity: 5, limitPrice: 5, placementSequence: 0, status: "open", expiresAtElapsedDays: 1, expiryEventId: "expiry" },
      { orderId: "buy", accountEntityId: "buyer", side: "buy", goodsId: "grain", originalQuantity: 5, remainingQuantity: 5, limitPrice: 5, placementSequence: 1, status: "open", expiresAtElapsedDays: null, expiryEventId: null },
    ],
    nextPlacementSequence: 2, nextScheduledEventOrdinal: 0,
    processedCommandIds: [], processedScheduledEventIds: [],
  };
  return new WorldSimulationFoundation({
    clock: new WorldClock(),
    facilities: new Facilities([], []),
    tradeHubs: new TradeHubs({ hubs: [hub] }),
    governance: new Governance({ managedEntities: [], governors: [], delegations: [] }),
    maxEventsPerAdvance: 10,
  });
}

function tradeIntent(eventId: string, kind: string, payload: Readonly<Record<string, string>>) {
  return { eventId, kind, dueElapsedDays: 1, targetComponent: TRADE_HUBS_COMPONENT, targetEntityId: "hub", payload };
}

function syntheticCatalog(): GoodsCatalog {
  const goods = [
    { id: "grain", displayName: "Grain", category: "fixture", bulkPerUnit: 1, baseValue: 0, perishable: false, tags: [] },
    { id: "tools", displayName: "Tools", category: "fixture", bulkPerUnit: 2, baseValue: 0, perishable: false, tags: [] },
  ] as const;
  return { goods, goodsById: new Map(goods.map((item) => [item.id, item])) };
}

function hubById(snapshot: NonNullable<ReturnType<TradeHubs["snapshot"]>>, hubId: string) {
  return snapshot.hubs.find((hub) => hub.hubId === hubId)!;
}

function submit<T extends WorldCommandEnvelope["commandType"]>(
  world: WorldSimulation,
  commandType: T,
  command: Extract<WorldCommandEnvelope, { readonly commandType: T }>["command"],
) {
  return world.submitCommand({ commandType, command } as WorldCommandEnvelope).result;
}

function assertAccepted(result: { readonly accepted: boolean }): void {
  assert.equal(result.accepted, true);
}
