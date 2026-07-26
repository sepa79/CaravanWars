import assert from "node:assert/strict";
import { resolve } from "node:path";
import test from "node:test";

import {
  Facilities,
  Governance,
  MerchantMemoryAI,
  TradeHubs,
  WorldClock,
  WorldMemory,
  WorldSimulation,
  WorldSimulationFoundation,
  loadPartyTravelConfigFile,
  loadRegionGraphFile,
} from "../src/index.js";
import type {
  GoodsCatalog,
  MerchantTradeDecision,
  TradeHubSnapshot,
  WorldCommandEnvelope,
  WorldEconomySeed,
} from "../src/index.js";

test("memory-only merchant observes, buys, transports, and sells across independent TradeHubs", () => {
  const world = createScenario();
  const ai = new MerchantMemoryAI();
  const policy = { goodsId: "grain", quantity: 3, commandIdPrefix: "merchant-run-1" } as const;

  world.advanceDays(0.25);
  accepted(submit(world, {
    commandType: "trade_hub_transfer_facility_goods",
    command: {
      commandId: "supplier-deposit", issuerActorId: "supplier_governor",
      accountEntityId: "supplier", hubId: "hub-a", facilityId: "farm",
      facilityHostId: "farm-host", goodsId: "grain", amount: 6, direction: "deposit",
    },
  }));
  accepted(submit(world, order("supplier-sell", "supplier_governor", "supplier", "hub-a", "sell", 6, 2)));
  accepted(submit(world, order("destination-buy", "buyer_governor", "destination-buyer", "hub-b", "buy", 3, 5)));

  const destinationObservation = observe(world, "observe-b");
  assert.equal(destinationObservation.entries[0]?.provenance.nodeId, "opole");
  accepted(submit(world, {
    commandType: "move_party",
    command: { party_id: "merchant", from_node_id: "opole", to_node_id: "wroclaw" },
  }));
  world.advanceDays(4);
  observe(world, "observe-a");

  let decision = decide(ai, world, policy);
  assert.equal(decision.action, "place_buy");
  accepted(submitDecision(world, decision));
  world.advanceDays(0.01);
  observe(world, "observe-a-after-buy");

  decision = decide(ai, world, policy);
  assert.equal(decision.action, "pickup");
  accepted(submitDecision(world, decision));
  assert.deepEqual(world.partySnapshot("merchant").cargo, { grain: 3 });

  decision = decide(ai, world, policy);
  assert.equal(decision.action, "travel");
  accepted(submitDecision(world, decision));
  world.advanceDays(4);
  assert.equal(world.partySnapshot("merchant").currentNodeId, "opole");

  decision = decide(ai, world, policy);
  assert.equal(decision.action, "deposit");
  accepted(submitDecision(world, decision));
  observe(world, "observe-b-after-deposit");

  decision = decide(ai, world, policy);
  assert.equal(decision.action, "place_sell");
  accepted(submitDecision(world, decision));
  world.advanceDays(0.01);
  const finalObservation = observe(world, "observe-b-after-sale");

  const snapshot = world.snapshot();
  const hubs = snapshot.simulationFoundation!.tradeHubs!.hubs;
  const hubA = hubs.find((hub) => hub.hubId === "hub-a")!;
  const hubB = hubs.find((hub) => hub.hubId === "hub-b")!;
  const merchantAtB = hubB.accounts.find((account) => account.accountEntityId === "merchant")!;
  assert.deepEqual(world.partySnapshot("merchant").cargo, {});
  assert.equal(merchantAtB.availableCurrency, 15);
  assert.deepEqual(hubA.inventory, { grain: 3 });
  assert.deepEqual(hubB.inventory, { grain: 3 });
  assert.equal(finalObservation.entries[0]?.kind, "trade_hub_observation");
  assert.equal(world.worldMemoryView("merchant", "party").entries
    .filter((entry) => entry.kind === "trade_command_result").length, 4);
  assert.equal(world.worldMemoryView("supplier", "actor").entries.some((entry) =>
    entry.provenance.sourceId === "merchant-run-1:sell"), false);
  assert.equal(world.worldMemoryView("unrelated-actor", "actor").entries.length, 0);
});

test("remote observation and foreign owner writes are rejected without leaking knowledge", () => {
  const world = createScenario();
  const before = world.snapshot().worldMemory;
  const foreign = world.observeLocalTradeContext({
    observationId: "foreign", observerPartyId: "merchant", ownerId: "supplier",
    ownerKind: "party", accountEntityId: "merchant", staleAfterDays: 2,
  });
  assert.equal(foreign.accepted, false);
  if (foreign.accepted) assert.fail("Expected owner-scope rejection.");
  assert.equal(foreign.errorCode, "OWNER_SCOPE_MISMATCH");
  assert.deepEqual(world.snapshot().worldMemory, before);

  const unauthorized = submit(world, order(
    "intruder-order", "intruder", "merchant", "hub-b", "buy", 1, 1,
  ));
  assert.equal(unauthorized.accepted, false);
  assert.equal(world.worldMemoryView("merchant", "party").entries.length, 0);
  assert.equal(world.worldMemoryView("intruder", "actor").entries.length, 1);

  accepted(submit(world, {
    commandType: "move_party",
    command: { party_id: "merchant", from_node_id: "opole", to_node_id: "wroclaw" },
  }));
  const traveling = world.observeLocalTradeContext({
    observationId: "traveling", observerPartyId: "merchant", ownerId: "merchant",
    ownerKind: "party", accountEntityId: "merchant", staleAfterDays: 2,
  });
  assert.equal(traveling.accepted, false);
  if (traveling.accepted) assert.fail("Expected traveling observer rejection.");
  assert.equal(traveling.errorCode, "PARTY_BUSY");
});

test("MerchantAI rejects stale opportunity memory instead of consulting current hub truth", () => {
  const world = createScenario();
  const ai = new MerchantMemoryAI();
  observe(world, "short-lived", 0.1);
  world.advanceDays(0.1);
  const decision = ai.decideTrade(
    world.worldMemoryView("merchant", "party"),
    world.merchantLocalTradeAffordances("merchant"),
    { goodsId: "grain", quantity: 1, commandIdPrefix: "stale-run" },
  );
  assert.deepEqual(decision, {
    action: "none", reason: "fresh_trade_opportunity_missing", command: null,
  });
});

test("WorldMemory JSON replay preserves the next deterministic merchant decision", () => {
  const world = createScenario();
  observe(world, "saved-observation");
  const saved = JSON.parse(JSON.stringify(world.snapshot().worldMemory));
  const restored = new WorldMemory(saved);
  assert.deepEqual(restored.snapshot(), world.snapshot().worldMemory);
  assert.deepEqual(restored.ownerView("merchant", "party", 0), world.worldMemoryView("merchant", "party"));
  const ai = new MerchantMemoryAI();
  const affordances = world.merchantLocalTradeAffordances("merchant");
  const policy = { goodsId: "grain", quantity: 1, commandIdPrefix: "replay-run" } as const;
  assert.deepEqual(
    ai.decideTrade(restored.ownerView("merchant", "party", 0), affordances, policy),
    ai.decideTrade(world.worldMemoryView("merchant", "party"), affordances, policy),
  );
});

test("Governor delegates a remembered supply task and party delivers physical cargo then reports", () => {
  const world = createScenario();
  world.advanceDays(0.25);
  accepted(submit(world, { commandType: "trade_hub_transfer_facility_goods", command: { commandId: "seed-deposit", issuerActorId: "supplier_governor", accountEntityId: "supplier", hubId: "hub-a", direction: "deposit", goodsId: "grain", amount: 2, facilityId: "farm", facilityHostId: "farm-host" } }));
  accepted(submit(world, order("seed-sell", "supplier_governor", "supplier", "hub-a", "sell", 2, 1)));
  accepted(submit(world, { commandType: "move_party", command: { party_id: "merchant", from_node_id: "opole", to_node_id: "wroclaw" } }));
  world.advanceDays(4);
  const assignment = { commandId: "assign-1", issuerActorId: "supplier_governor", taskId: "task-1", executorPartyId: "merchant", facilityId: "farm", facilityHostId: "farm-host", destinationNodeId: "wroclaw", goodsId: "grain", amount: 2 };
  const unauthorized = submit(world, { commandType: "assign_supply_task", command: { ...assignment, commandId: "assign-foreign", issuerActorId: "buyer_governor" } });
  assert.equal(unauthorized.accepted, false);
  assert.equal(world.worldMemoryView("merchant", "party").entries.some((entry) => entry.payload.commandId === "assign-foreign"), false);
  accepted(submit(world, { commandType: "assign_supply_task", command: assignment }));
  accepted(submit(world, order("task-buy", "merchant_actor", "merchant", "hub-a", "buy", 2, 1)));
  world.advanceDays(0.01);
  accepted(submit(world, { commandType: "trade_hub_transfer_party_goods", command: { commandId: "task-pickup", issuerActorId: "merchant_actor", accountEntityId: "merchant", partyId: "merchant", hubId: "hub-a", direction: "withdraw", goodsId: "grain", amount: 2 } }));
  const delivery = { commandType: "deliver_supply_task", command: { commandId: "deliver-1", issuerActorId: "merchant_actor", taskId: "task-1", executorPartyId: "merchant", facilityId: "farm", facilityHostId: "farm-host", goodsId: "grain", amount: 2 } } as const;
  accepted(submit(world, delivery));
  const replay = submit(world, delivery);
  assert.equal(replay.accepted && "idempotentReplay" in replay && replay.idempotentReplay, true);
  accepted(submit(world, { commandType: "report_supply_task", command: { commandId: "report-1", issuerActorId: "merchant_actor", taskId: "task-1", executorPartyId: "merchant", recipientActorId: "supplier_governor", facilityId: "farm" } }));
  assert.equal(world.worldMemoryView("supplier_governor", "actor").entries.at(-1)?.provenance.sourceType, "report");
  assert.equal(world.worldMemoryView("unrelated", "actor").entries.length, 0);
});

function decide(
  ai: MerchantMemoryAI,
  world: WorldSimulation,
  policy: { readonly goodsId: string; readonly quantity: number; readonly commandIdPrefix: string },
): MerchantTradeDecision {
  return ai.decideTrade(
    world.worldMemoryView("merchant", "party"),
    world.merchantLocalTradeAffordances("merchant"),
    policy,
  );
}

function observe(world: WorldSimulation, observationId: string, staleAfterDays = 20) {
  const result = world.observeLocalTradeContext({
    observationId, observerPartyId: "merchant", ownerId: "merchant", ownerKind: "party",
    accountEntityId: "merchant", staleAfterDays,
  });
  assert.equal(result.accepted, true);
  return result;
}

function submitDecision(world: WorldSimulation, decision: MerchantTradeDecision) {
  assert.notEqual(decision.command, null);
  return submit(world, decision.command!);
}

function submit(world: WorldSimulation, envelope: WorldCommandEnvelope) {
  return world.submitCommand(envelope).result;
}

function accepted(result: { readonly accepted: boolean }): void {
  assert.equal(result.accepted, true);
}

function order(
  commandId: string,
  issuerActorId: string,
  accountEntityId: string,
  hubId: string,
  side: "buy" | "sell",
  quantity: number,
  limitPrice: number,
): Extract<WorldCommandEnvelope, { readonly commandType: "place_trade_hub_order" }> {
  return {
    commandType: "place_trade_hub_order",
    command: {
      commandId, issuerActorId, accountEntityId, hubId, orderId: `${commandId}-order`,
      side, goodsId: "grain", quantity, limitPrice, expiresAtElapsedDays: null,
    },
  };
}

function createScenario(): WorldSimulation {
  const clock = new WorldClock();
  const facilities = new Facilities([{
    facilityId: "farm", facilityType: "fixture_producer", hostId: "farm-host",
    ownerId: "supplier", governorActorId: "supplier_governor",
    recipe: {
      inputs: {}, energyInputs: {}, maintenanceInputs: {}, outputs: { grain: 6 },
      workforceRequired: 1, cycleDays: 0.25, blockedRetryDays: null, shortagePolicies: [],
    },
    active: true, generation: 0, nextEventOrdinal: 0,
    pendingTickEventId: null, processedEventIds: [],
  }], [{
    hostId: "farm-host", inventory: {}, storageCaps: { grain: 30, tools: 10 },
    cohorts: [{ cohortId: "workers", population: 4, availableWorkforce: 4, unrest: 0 }],
  }]);
  const foundation = new WorldSimulationFoundation({
    clock,
    facilities,
    tradeHubs: new TradeHubs({ hubs: [
      hub("hub-a", "wroclaw", ["farm-host"], [
        account("supplier", 0), account("merchant", 20),
      ]),
      hub("hub-b", "opole", [], [
        account("merchant", 0), account("destination-buyer", 100),
      ]),
    ] }),
    governance: new Governance({
      managedEntities: [
        { entityId: "farm", ownerId: "supplier", governorActorId: "supplier_governor" },
        { entityId: "supplier", ownerId: "supplier", governorActorId: "supplier_governor" },
        { entityId: "merchant", ownerId: "merchant", governorActorId: "supplier_governor" },
        { entityId: "destination-buyer", ownerId: "buyer", governorActorId: "buyer_governor" },
      ],
      governors: [
        governor("supplier_governor", "supplier"),
        governor("merchant_actor", "merchant"),
        governor("buyer_governor", "buyer"),
      ],
      delegations: [{ delegationId: "merchant-supply", delegatorActorId: "supplier_governor", delegateActorId: "merchant_actor", authorityScopes: ["facility:supply", "trade:transfer", "trade:order", "trade:cancel"], validFromElapsedDays: 0, validUntilElapsedDays: null }],
    }),
    maxEventsPerAdvance: 100,
  });
  foundation.scheduleInitialFacilityTick("farm");
  const goodsCatalog = syntheticCatalog();
  const profiles = [
    { locationId: "wroclaw-location", productionPerDay: {}, consumptionPerDay: {}, storageCaps: { grain: 30, tools: 10 } },
    { locationId: "opole-location", productionPerDay: {}, consumptionPerDay: {}, storageCaps: { grain: 30, tools: 10 } },
  ];
  const economy: WorldEconomySeed = {
    goodsCatalog,
    partyCargoConfig: { footCapacityBulk: 1, horseCapacityBulk: 0, packAnimalCapacityBulk: 0, wagonCapacityBulk: 20 },
    locationEconomyConfig: { profiles, profilesByLocationId: new Map(profiles.map((profile) => [profile.locationId, profile])) },
    locations: [
      { id: "wroclaw-location", displayName: "A", managerActorId: "supplier_governor", nodeId: "wroclaw", resources: {} },
      { id: "opole-location", displayName: "B", managerActorId: "buyer_governor", nodeId: "opole", resources: {} },
    ],
  };
  return new WorldSimulation(
    loadRegionGraphFile(resolve("data/regions/silesia.json")),
    loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json")),
    [{
      id: "merchant", displayName: "Memory merchant", managerActorId: "merchant_actor", nodeId: "opole",
      composition: { footCount: 1, horseCount: 0, wagonCount: 1, packAnimalCount: 0, guardCount: 0 },
      knownRouteIds: ["wroclaw_opole"], cargo: {},
    }],
    economy,
    clock,
    foundation,
    new WorldMemory(),
  );
}

function hub(
  hubId: string,
  nodeId: string,
  connectedFacilityHostIds: readonly string[],
  accounts: TradeHubSnapshot["accounts"],
): TradeHubSnapshot {
  return {
    hubId, nodeId, ownerId: `${hubId}-owner`, governorActorId: null,
    connectedFacilityHostIds, storageCaps: { grain: 30, tools: 10 }, inventory: {}, accounts,
    orders: [], nextPlacementSequence: 0, nextScheduledEventOrdinal: 0,
    processedCommandIds: [], processedScheduledEventIds: [],
  };
}

function account(accountEntityId: string, availableCurrency: number) {
  return { accountEntityId, availableGoods: {}, escrowGoods: {}, availableCurrency, escrowCurrency: 0 };
}

function governor(actorId: string, principalId: string) {
  return {
    actorId, principalId, superiorActorId: null, roles: ["fixture_trader"],
    authorityScopes: ["trade:transfer", "trade:order", "trade:cancel", "facility:supply", "supply:delegate"],
    controller: "deterministic_policy" as const,
  };
}

function syntheticCatalog(): GoodsCatalog {
  const goods = [
    { id: "grain", displayName: "Grain", category: "fixture", bulkPerUnit: 1, baseValue: 0, perishable: false, tags: [] },
    { id: "tools", displayName: "Tools", category: "fixture", bulkPerUnit: 2, baseValue: 0, perishable: false, tags: [] },
  ];
  return { goods, goodsById: new Map(goods.map((item) => [item.id, item])) };
}
