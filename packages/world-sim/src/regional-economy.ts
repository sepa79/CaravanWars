import { GovernorAIController } from "./governor-controller.js";
import type { GovernorShortagePolicy } from "./governor-controller.js";
import { LogisticsTaskBoard } from "./logistics-tasks.js";
import type { LogisticsTaskBoardSnapshot, LogisticsTaskSnapshot } from "./logistics-tasks.js";
import { MerchantMemoryAI } from "./merchant-memory-ai.js";
import type { RegionGraph } from "./region-graph.js";
import { WorldSimulation } from "./world-sim.js";
import type { PartyTravelConfig, WorldEconomySeed, WorldSnapshot } from "./world-sim.js";
import { GovernorPopulationController } from "./population-dynamics.js";
import type { GovernorPopulationPolicy } from "./population-dynamics.js";

export interface RegionalFacilityMarketPolicy {
  readonly facilityId: string;
  readonly facilityHostId: string;
  readonly hubId: string;
  readonly sellerAccountEntityId: string;
  readonly issuerActorId: string;
  readonly goodsId: string;
  readonly lotSize: number;
  readonly askPrice: number;
}

export interface RegionalGovernorPolicy {
  readonly governorActorId: string;
  readonly facilityId: string;
  readonly facilityHostId: string;
  readonly destinationNodeId: string;
  readonly executorPartyIds: readonly string[];
  readonly shortagePolicy: GovernorShortagePolicy;
}

export interface RegionalMerchantPolicy {
  readonly partyId: string;
  readonly goodsId: string;
  readonly quantity: number;
}

export interface AutonomousRegionalEconomyConfig {
  readonly configId: string;
  readonly seed: number;
  readonly observationStaleAfterDays: number;
  readonly facilityMarkets: readonly RegionalFacilityMarketPolicy[];
  readonly governors: readonly RegionalGovernorPolicy[];
  readonly merchants: readonly RegionalMerchantPolicy[];
  readonly routeDistanceByKey: Readonly<Record<string, number>>;
  readonly populationGovernors?: readonly { readonly governorActorId: string; readonly settlementId: string; readonly policy: GovernorPopulationPolicy }[];
}

export interface RegionalDecisionRecord {
  readonly sequence: number;
  readonly elapsedDays: number;
  readonly actorId: string;
  readonly reason: string;
  readonly commandType: string | null;
  readonly accepted: boolean | null;
}

export interface RegionalEconomyMetrics {
  readonly elapsedDays: number;
  readonly productionByGoods: Readonly<Record<string, number>>;
  readonly consumptionAttempts: number;
  readonly shortages: number;
  readonly recoveries: number;
  readonly trades: number;
  readonly tradedQuantity: number;
  readonly tradedValue: number;
  readonly transportedCargo: number;
  readonly transportDistanceKm: number;
  readonly unrest: number;
  readonly completedFacilityCycles: number;
  readonly degradedFacilityCycles: number;
  readonly pendingClockEvents: number;
  readonly activeTasks: number;
  readonly terminalTasks: number;
  readonly failedCommands: number;
}

export interface AutonomousRegionalEconomySnapshot {
  readonly schemaVersion: 1;
  readonly config: AutonomousRegionalEconomyConfig;
  readonly world: WorldSnapshot;
  readonly tasks: LogisticsTaskBoardSnapshot;
  readonly decisions: readonly RegionalDecisionRecord[];
  readonly nextDecisionSequence: number;
  readonly actionOrdinals: Readonly<Record<string, number>>;
}

export interface RegionalEconomyDiagnosticSnapshot {
  readonly truthView: true;
  readonly configId: string;
  readonly metrics: RegionalEconomyMetrics;
  readonly settlements: readonly {
    readonly hubId: string;
    readonly nodeId: string;
    readonly inventory: Readonly<Record<string, number>>;
    readonly openOrders: number;
  }[];
  readonly parties: WorldSnapshot["parties"];
  readonly tasks: readonly LogisticsTaskSnapshot[];
  readonly recentDecisions: readonly RegionalDecisionRecord[];
}

export class AutonomousRegionalEconomyRunner {
  readonly #config: AutonomousRegionalEconomyConfig;
  readonly #world: WorldSimulation;
  readonly #tasks: LogisticsTaskBoard;
  readonly #governor = new GovernorAIController();
  readonly #merchant = new MerchantMemoryAI();
  readonly #populationGovernor = new GovernorPopulationController();
  #decisions: RegionalDecisionRecord[];
  #nextDecisionSequence: number;
  readonly #actionOrdinals: Map<string, number>;

  constructor(
    config: AutonomousRegionalEconomyConfig,
    world: WorldSimulation,
    tasks = new LogisticsTaskBoard(),
    decisions: readonly RegionalDecisionRecord[] = [],
    nextDecisionSequence = 0,
    actionOrdinals: Readonly<Record<string, number>> = {},
  ) {
    validateConfig(config);
    this.#config = structuredClone(config);
    this.#world = world;
    this.#tasks = tasks;
    this.#decisions = Array.from(structuredClone(decisions));
    this.#nextDecisionSequence = nextDecisionSequence;
    this.#actionOrdinals = new Map(Object.entries(actionOrdinals));
  }

  static resume(
    graph: RegionGraph,
    travelConfig: PartyTravelConfig,
    economySeed: WorldEconomySeed,
    snapshot: AutonomousRegionalEconomySnapshot,
  ): AutonomousRegionalEconomyRunner {
    if (snapshot.schemaVersion !== 1) throw new Error(`Unsupported regional economy schema ${snapshot.schemaVersion}.`);
    return new AutonomousRegionalEconomyRunner(
      snapshot.config,
      WorldSimulation.fromSnapshot(graph, travelConfig, economySeed, snapshot.world),
      new LogisticsTaskBoard(snapshot.tasks),
      snapshot.decisions,
      snapshot.nextDecisionSequence,
      snapshot.actionOrdinals,
    );
  }

  runDays(days: number): RegionalEconomyMetrics {
    if (!Number.isSafeInteger(days) || days <= 0 || days > 180) throw new Error("runDays must be an integer from 1 to 180.");
    for (let day = 0; day < days; day += 1) this.#runOneDay();
    return this.metrics();
  }

  runControlInterval(days: number): RegionalEconomyMetrics {
    if (!Number.isSafeInteger(days) || days <= 0 || days > 90) throw new Error("control interval must be an integer from 1 to 90 days.");
    this.#runInterval(days);
    return this.metrics();
  }

  snapshot(): AutonomousRegionalEconomySnapshot {
    return {
      schemaVersion: 1,
      config: structuredClone(this.#config),
      world: this.#world.snapshot(),
      tasks: this.#tasks.snapshot(),
      decisions: structuredClone(this.#decisions),
      nextDecisionSequence: this.#nextDecisionSequence,
      actionOrdinals: Object.fromEntries(this.#actionOrdinals),
    };
  }

  diagnostics(): RegionalEconomyDiagnosticSnapshot {
    const world = this.#world.snapshot();
    return {
      truthView: true,
      configId: this.#config.configId,
      metrics: this.metrics(),
      settlements: (world.simulationFoundation?.tradeHubs?.hubs ?? []).map((hub) => ({
        hubId: hub.hubId, nodeId: hub.nodeId, inventory: hub.inventory,
        openOrders: hub.orders.filter((order) => order.status === "open" || order.status === "partially_filled").length,
      })),
      parties: world.parties,
      tasks: this.#tasks.snapshot().tasks,
      recentDecisions: this.#decisions.slice(-20),
    };
  }

  partyMapSnapshot(partyId: string) {
    return this.#world.partyMapSnapshot(partyId);
  }

  metrics(): RegionalEconomyMetrics {
    const snapshot = this.#world.snapshot();
    const events = snapshot.simulationFoundation?.events ?? [];
    const tasks = this.#tasks.snapshot().tasks;
    const production: Record<string, number> = {};
    let consumptionAttempts = 0, shortages = 0, recoveries = 0, trades = 0;
    let tradedQuantity = 0, tradedValue = 0, completedFacilityCycles = 0, degradedFacilityCycles = 0;
    for (const event of events) {
      if (event.eventType === "FacilityProductionTicked" || event.eventType === "FacilityProductionDegraded") {
        for (const [goodsId, amount] of Object.entries(event.produced)) production[goodsId] = (production[goodsId] ?? 0) + amount;
        if (event.eventType === "FacilityProductionTicked") completedFacilityCycles += 1;
        else degradedFacilityCycles += 1;
      } else if (event.eventType === "ResourceConsumptionAttempted") {
        consumptionAttempts += 1;
        if (event.outcome === "shortage") shortages += 1;
        if (event.outcome === "recovered") recoveries += 1;
      } else if (event.eventType === "TradeHubTradeExecuted") {
        trades += 1; tradedQuantity += event.quantity; tradedValue += event.totalPrice;
      }
    }
    const unrest = (snapshot.simulationFoundation?.facilities.hosts ?? [])
      .flatMap((host) => host.cohorts).reduce((sum, cohort) => sum + cohort.unrest, 0);
    return {
      elapsedDays: snapshot.clock.elapsedDays,
      productionByGoods: production,
      consumptionAttempts, shortages, recoveries, trades, tradedQuantity, tradedValue,
      transportedCargo: tasks.filter((task) => task.status === "completed").reduce((sum, task) => sum + task.amount, 0),
      transportDistanceKm: this.#decisions.filter((item) => item.accepted === true && item.reason.startsWith("travel:"))
        .reduce((sum, item) => sum + (this.#config.routeDistanceByKey[item.reason.slice(7)] ?? 0), 0),
      unrest, completedFacilityCycles, degradedFacilityCycles,
      pendingClockEvents: snapshot.clock.scheduledEvents.filter((event) => event.status === "pending").length,
      activeTasks: tasks.filter((task) => task.status === "created" || task.status === "accepted" || task.status === "in_progress").length,
      terminalTasks: tasks.filter((task) => task.status === "completed" || task.status === "failed" || task.status === "abandoned").length,
      failedCommands: this.#decisions.filter((item) => item.accepted === false).length,
    };
  }

  #runOneDay(): void {
    this.#runInterval(1);
  }

  #runInterval(days: number): void {
    this.#world.advanceDays(days);
    this.#operateLocalMarkets();
    this.#observeLocalMarkets();
    this.#planGovernorTasks();
    this.#planPopulationLabour();
    this.#executeSupplyTasks();
    this.#runIndependentMerchants();
    this.#world.advanceDays(0.001);
  }

  #operateLocalMarkets(): void {
    for (const policy of this.#config.facilityMarkets) {
      const hub = this.#world.managedTradeHubSnapshot(policy.issuerActorId, policy.sellerAccountEntityId, policy.hubId);
      if (hub?.orders.some((order) => order.accountEntityId === policy.sellerAccountEntityId
        && order.goodsId === policy.goodsId
        && order.side === "sell"
        && (order.status === "open" || order.status === "partially_filled"))) continue;
      const available = this.#world.facilityHostResource(policy.facilityHostId, policy.goodsId);
      const amount = Math.min(available, policy.lotSize);
      if (amount <= 0) continue;
      const ordinal = this.#nextAction(`market:${policy.facilityId}`);
      const transfer = this.#world.submitCommand({ commandType: "trade_hub_transfer_facility_goods", command: {
        commandId: `regional:${policy.facilityId}:deposit:${ordinal}`,
        issuerActorId: policy.issuerActorId, accountEntityId: policy.sellerAccountEntityId,
        hubId: policy.hubId, direction: "deposit", goodsId: policy.goodsId, amount,
        facilityId: policy.facilityId, facilityHostId: policy.facilityHostId,
      }}).result;
      this.#record(policy.issuerActorId, "local_facility_deposit", "trade_hub_transfer_facility_goods", transfer.accepted);
      if (!transfer.accepted) continue;
      const sell = this.#world.submitCommand({ commandType: "place_trade_hub_order", command: {
        commandId: `regional:${policy.facilityId}:sell:${ordinal}`, issuerActorId: policy.issuerActorId,
        accountEntityId: policy.sellerAccountEntityId, hubId: policy.hubId,
        orderId: `regional:${policy.facilityId}:sell-order:${ordinal}`, side: "sell",
        goodsId: policy.goodsId, quantity: amount, limitPrice: policy.askPrice, expiresAtElapsedDays: null,
      }}).result;
      this.#record(policy.issuerActorId, "local_supply_offer", "place_trade_hub_order", sell.accepted);
    }
  }

  #observeLocalMarkets(): void {
    for (const merchant of this.#config.merchants) {
      const party = this.#world.partySnapshot(merchant.partyId);
      if (party.status !== "idle") continue;
      const result = this.#world.observeLocalTradeContext({
        observationId: `regional:${merchant.partyId}:observe:${this.#nextAction(`observe:${merchant.partyId}`)}`,
        observerPartyId: merchant.partyId, ownerId: merchant.partyId, ownerKind: "party",
        accountEntityId: merchant.partyId, staleAfterDays: this.#config.observationStaleAfterDays,
      });
      this.#record(party.managerActorId, result.accepted ? "local_market_observed" : result.errorCode, null, result.accepted);
    }
  }

  #planGovernorTasks(): void {
    for (const policy of this.#config.governors) {
      this.#world.observeGovernorShortages(policy.governorActorId, this.#config.observationStaleAfterDays);
      const base = this.#world.governorSupplyAffordances(policy.governorActorId)
        .filter((item) => item.facilityId === policy.facilityId)
        .map((item) => ({ ...item, executorPartyIds: item.executorPartyIds.filter((id) => policy.executorPartyIds.includes(id)) }));
      const decision = this.#governor.decide(this.#world.worldMemoryView(policy.governorActorId, "actor"), base, policy.shortagePolicy);
      if (decision.action !== "assign_supply_task") {
        this.#record(policy.governorActorId, decision.reason, null, null);
        continue;
      }
      const created = this.#tasks.create({
        taskId: decision.command.taskId, ownerActorId: policy.governorActorId,
        executorPartyId: decision.command.executorPartyId,
        destinationEntityId: decision.command.facilityId,
        destinationNodeId: decision.command.destinationNodeId,
        goodsId: decision.command.goodsId, amount: decision.command.amount,
      }, `${decision.command.commandId}:created`, this.#world.elapsedDays(), "governor_priority");
      if (!created.accepted) {
        this.#record(policy.governorActorId, created.errorCode, null, false);
        continue;
      }
      const result = this.#world.submitCommand({ commandType: "assign_supply_task", command: decision.command }).result;
      this.#record(policy.governorActorId, "supply_task_created", "assign_supply_task", result.accepted);
      if (result.accepted) this.#tasks.transition(created.task.taskId, "accepted", `${decision.command.commandId}:accepted`, this.#world.elapsedDays(), "executor_received_local_order");
      else this.#tasks.transition(created.task.taskId, "failed", `${decision.command.commandId}:failed`, this.#world.elapsedDays(), "assignment_rejected");
    }
  }

  #executeSupplyTasks(): void {
    for (const task of this.#tasks.active()) {
      if (task.status === "accepted") this.#tasks.transition(task.taskId, "in_progress", `${task.taskId}:in-progress`, this.#world.elapsedDays(), "executor_started");
      const current = this.#tasks.snapshot().tasks.find((item) => item.taskId === task.taskId)!;
      if (current.status !== "in_progress") continue;
      this.#executeSupplyTask(current);
    }
  }

  #planPopulationLabour(): void {
    for (const item of this.#config.populationGovernors ?? []) {
      this.#world.observeGovernorPopulation(item.governorActorId, this.#config.observationStaleAfterDays);
      const command = this.#populationGovernor.decide(this.#world.worldMemoryView(item.governorActorId, "actor"), item.settlementId, this.#world.elapsedDays(), item.policy);
      if (command === null) { this.#record(item.governorActorId, "population_observation_missing", null, null); continue; }
      const result = this.#world.submitCommand({ commandType: "allocate_labour", command }).result;
      this.#record(item.governorActorId, result.accepted ? "labour_allocated" : result.errorCode, "allocate_labour", result.accepted);
    }
  }

  #executeSupplyTask(task: LogisticsTaskSnapshot): void {
    const party = this.#world.partySnapshot(task.executorPartyId);
    if (party.status !== "idle" || party.currentNodeId === null) {
      this.#record(party.managerActorId, "task_waiting_for_travel", null, null);
      return;
    }
    const carried = party.cargo[task.goodsId] ?? 0;
    const ordinal = this.#nextAction(`task:${task.taskId}`);
    if (carried > 0) {
      if (party.currentNodeId !== task.destinationNodeId) {
        this.#submitTravel(party.id, party.managerActorId, party.currentNodeId, task.destinationNodeId);
        return;
      }
      const facility = this.#config.governors.find((item) => item.facilityId === task.destinationEntityId)!;
      const result = this.#world.submitCommand({ commandType: "deliver_supply_task", command: {
        commandId: `${task.taskId}:deliver:${ordinal}`, issuerActorId: party.managerActorId,
        taskId: task.taskId, executorPartyId: party.id, facilityId: facility.facilityId,
        facilityHostId: facility.facilityHostId, goodsId: task.goodsId, amount: Math.min(carried, task.amount),
      }}).result;
      this.#record(party.managerActorId, result.accepted ? "supply_delivered" : result.errorCode, "deliver_supply_task", result.accepted);
      if (result.accepted) {
        this.#tasks.transition(task.taskId, "completed", `${task.taskId}:completed`, this.#world.elapsedDays(), "physical_delivery_completed");
        this.#world.submitCommand({ commandType: "report_supply_task", command: {
          commandId: `${task.taskId}:report`, issuerActorId: party.managerActorId, taskId: task.taskId,
          executorPartyId: party.id, recipientActorId: task.ownerActorId, facilityId: task.destinationEntityId,
        }});
      } else {
        this.#tasks.transition(task.taskId, "failed", `${task.taskId}:failed:${ordinal}`, this.#world.elapsedDays(), `attempt_failed:${result.errorCode}`);
      }
      return;
    }
    const source = rememberedSource(this.#world.worldMemoryView(party.id, "party"), task.goodsId);
    if (source === null) {
      if (this.#world.elapsedDays() - task.createdAtElapsedDays >= this.#config.observationStaleAfterDays) {
        this.#tasks.transition(task.taskId, "abandoned", `${task.taskId}:abandoned`, this.#world.elapsedDays(), "stale_source_information");
        this.#record(party.managerActorId, "task_abandoned_stale_information", null, false);
        return;
      }
      this.#record(party.managerActorId, "fresh_source_memory_missing", null, null);
      return;
    }
    if (party.currentNodeId !== source.nodeId) {
      this.#submitTravel(party.id, party.managerActorId, party.currentNodeId, source.nodeId);
      return;
    }
    const local = this.#world.merchantLocalTradeAffordances(party.id).localTradeHubs.find((hub) => hub.hubId === source.hubId);
    if ((local?.account?.availableGoods[task.goodsId] ?? 0) > 0) {
      const result = this.#world.submitCommand({ commandType: "trade_hub_transfer_party_goods", command: {
        commandId: `${task.taskId}:pickup:${ordinal}`, issuerActorId: party.managerActorId,
        accountEntityId: party.id, partyId: party.id, hubId: source.hubId,
        goodsId: task.goodsId, amount: Math.min(local?.account?.availableGoods[task.goodsId] ?? 0, task.amount), direction: "withdraw",
      }}).result;
      this.#record(party.managerActorId, result.accepted ? "task_goods_picked_up" : result.errorCode, "trade_hub_transfer_party_goods", result.accepted);
      return;
    }
    if ((local?.account?.escrowCurrency ?? 0) > 0) {
      this.#record(party.managerActorId, "task_waiting_for_match", null, null);
      return;
    }
    const result = this.#world.submitCommand({ commandType: "place_trade_hub_order", command: {
      commandId: `${task.taskId}:buy:${ordinal}`, issuerActorId: party.managerActorId,
      accountEntityId: party.id, hubId: source.hubId, orderId: `${task.taskId}:buy-order:${ordinal}`,
      side: "buy", goodsId: task.goodsId, quantity: task.amount, limitPrice: source.bestAsk, expiresAtElapsedDays: null,
    }}).result;
    this.#record(party.managerActorId, result.accepted ? "task_buy_placed" : result.errorCode, "place_trade_hub_order", result.accepted);
  }

  #runIndependentMerchants(): void {
    const assigned = new Set(this.#tasks.active().map((task) => task.executorPartyId));
    for (const policy of this.#config.merchants) {
      if (assigned.has(policy.partyId)) continue;
      const affordances = this.#world.merchantLocalTradeAffordances(policy.partyId);
      const ordinal = this.#nextAction(`merchant:${policy.partyId}`);
      const decision = this.#merchant.decideTrade(this.#world.worldMemoryView(policy.partyId, "party"), affordances, {
        goodsId: policy.goodsId, quantity: policy.quantity, commandIdPrefix: `regional:${policy.partyId}:${ordinal}`,
      });
      const result = decision.command === null ? null : this.#world.submitCommand(decision.command).result;
      this.#record(affordances.issuerActorId, decision.reason, decision.command?.commandType ?? null, result?.accepted ?? null);
    }
  }

  #submitTravel(partyId: string, actorId: string, from: string, to: string): void {
    const result = this.#world.submitCommand({ commandType: "move_party", command: { party_id: partyId, from_node_id: from, to_node_id: to } }).result;
    this.#record(actorId, `travel:${routeKey(from, to)}`, "move_party", result.accepted);
  }

  #record(actorId: string, reason: string, commandType: string | null, accepted: boolean | null): void {
    this.#decisions.push({ sequence: this.#nextDecisionSequence, elapsedDays: this.#world.elapsedDays(), actorId, reason, commandType, accepted });
    this.#nextDecisionSequence += 1;
  }

  #nextAction(key: string): number {
    const ordinal = this.#actionOrdinals.get(key) ?? 0;
    this.#actionOrdinals.set(key, ordinal + 1);
    return ordinal;
  }
}

function rememberedSource(memory: ReturnType<WorldSimulation["worldMemoryView"]>, goodsId: string): { hubId: string; nodeId: string; bestAsk: number } | null {
  const sources = memory.entries.filter((entry) => entry.kind === "trade_hub_observation" && entry.freshness === "fresh")
    .flatMap((entry) => {
      const hubId = entry.payload.hubId, nodeId = entry.payload.nodeId, market = entry.payload.market;
      if (typeof hubId !== "string" || typeof nodeId !== "string" || !Array.isArray(market)) return [];
      const row = market.find((item) => item !== null && typeof item === "object" && !Array.isArray(item) && item.goodsId === goodsId);
      const bestAsk = row !== undefined && typeof row === "object" && row !== null && "bestAsk" in row ? row.bestAsk : null;
      return Number.isSafeInteger(bestAsk) && (bestAsk as number) > 0 ? [{ hubId, nodeId, bestAsk: bestAsk as number, sequence: entry.sequence }] : [];
    }).sort((a, b) => a.bestAsk - b.bestAsk || a.sequence - b.sequence);
  return sources[0] ?? null;
}

export function routeKey(left: string, right: string): string {
  return left < right ? `${left}|${right}` : `${right}|${left}`;
}

function validateConfig(config: AutonomousRegionalEconomyConfig): void {
  if (config.configId.length === 0 || !Number.isSafeInteger(config.seed)) throw new Error("Regional config requires id and integer seed.");
  if (!Number.isFinite(config.observationStaleAfterDays) || config.observationStaleAfterDays <= 0) throw new Error("Observation aging must be positive.");
  JSON.stringify(config);
}
