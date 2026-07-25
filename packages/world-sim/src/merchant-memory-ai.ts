import type {
  CommandResult,
  MerchantLocalTradeAffordances,
  TransferGoodsResult,
  WorldCommandEnvelope,
} from "./world-sim.js";
import { WorldSimulation } from "./world-sim.js";
import type { WorldMemoryEntryView, WorldMemoryOwnerView } from "./world-memory.js";

export interface NeedLedgerMemory {
  readonly kind: "need_ledger";
  readonly ownerId: string;
  readonly goodsId: "food";
  readonly locationId: string;
  readonly nodeId: string;
  readonly neededAmount: number;
}

export interface LocationObservationMemory {
  readonly kind: "location_observation";
  readonly ownerId: string;
  readonly nodeId: string;
  readonly observedLocationId: string;
  readonly observedResources: Readonly<Record<string, number>>;
}

export type MerchantMemoryEntry = NeedLedgerMemory | LocationObservationMemory;

export type MerchantMemoryAction = "none" | "withdraw" | "travel" | "deposit";

export interface MerchantMemoryDecision {
  readonly action: MerchantMemoryAction;
  readonly reason: string;
  readonly submittedCommand: WorldCommandEnvelope | null;
  readonly commandResult: CommandResult | TransferGoodsResult | null;
}

export type MerchantTradeAction = "none" | "place_buy" | "pickup" | "travel" | "deposit" | "place_sell";

export interface MerchantTradePolicy {
  readonly goodsId: string;
  readonly quantity: number;
  readonly commandIdPrefix: string;
}

export interface MerchantTradeDecision {
  readonly action: MerchantTradeAction;
  readonly reason: string;
  readonly command: WorldCommandEnvelope | null;
}

export class MerchantMemoryAI {
  decideTrade(
    memory: WorldMemoryOwnerView,
    affordances: MerchantLocalTradeAffordances,
    policy: MerchantTradePolicy,
  ): MerchantTradeDecision {
    if (memory.ownerId !== affordances.party.id || memory.ownerKind !== "party") {
      return noTradeAction("memory_owner_mismatch");
    }
    if (affordances.party.status !== "idle" || affordances.party.currentNodeId === null) {
      return noTradeAction("party_busy");
    }
    if (!Number.isSafeInteger(policy.quantity) || policy.quantity <= 0 || policy.commandIdPrefix.length === 0) {
      return noTradeAction("invalid_policy");
    }
    const observations = memory.entries
      .filter((entry) => entry.kind === "trade_hub_observation" && entry.freshness === "fresh")
      .map(parseTradeObservation)
      .filter((entry): entry is TradeObservation => entry !== null);
    const opportunity = selectOpportunity(observations, policy.goodsId);
    if (opportunity === null) return noTradeAction("fresh_trade_opportunity_missing");

    const local = affordances.localTradeHubs.find((hub) => hub.hubId === opportunity.source.hubId)
      ?? affordances.localTradeHubs.find((hub) => hub.hubId === opportunity.destination.hubId);
    const carried = affordances.party.cargo[policy.goodsId] ?? 0;
    if (carried > 0) {
      if (affordances.party.currentNodeId !== opportunity.destination.nodeId) {
        return {
          action: "travel",
          reason: "carry_goods_to_remembered_buyer",
          command: {
            commandType: "move_party",
            command: {
              party_id: affordances.party.id,
              from_node_id: affordances.party.currentNodeId,
              to_node_id: opportunity.destination.nodeId,
            },
          },
        };
      }
      if (local?.hubId !== opportunity.destination.hubId) return noTradeAction("destination_hub_not_local");
      return {
        action: "deposit",
        reason: "deposit_at_remembered_destination",
        command: {
          commandType: "trade_hub_transfer_party_goods",
          command: {
            commandId: `${policy.commandIdPrefix}:deposit`,
            issuerActorId: affordances.issuerActorId,
            accountEntityId: affordances.accountEntityId,
            partyId: affordances.party.id,
            hubId: opportunity.destination.hubId,
            goodsId: policy.goodsId,
            amount: Math.min(carried, policy.quantity),
            direction: "deposit",
          },
        },
      };
    }

    if (local?.hubId === opportunity.destination.hubId
      && (local.account?.availableGoods[policy.goodsId] ?? 0) > 0) {
      return {
        action: "place_sell",
        reason: "sell_to_remembered_local_bid",
        command: {
          commandType: "place_trade_hub_order",
          command: {
            commandId: `${policy.commandIdPrefix}:sell`,
            issuerActorId: affordances.issuerActorId,
            accountEntityId: affordances.accountEntityId,
            hubId: opportunity.destination.hubId,
            orderId: `${policy.commandIdPrefix}:sell-order`,
            side: "sell",
            goodsId: policy.goodsId,
            quantity: Math.min(local.account?.availableGoods[policy.goodsId] ?? 0, policy.quantity),
            limitPrice: opportunity.destination.bestBid,
            expiresAtElapsedDays: null,
          },
        },
      };
    }

    if (affordances.party.currentNodeId !== opportunity.source.nodeId) {
      return noTradeAction("source_hub_not_local");
    }
    if (local?.hubId !== opportunity.source.hubId || local.account === null) {
      return noTradeAction("source_account_unavailable");
    }
    const purchased = local.account.availableGoods[policy.goodsId] ?? 0;
    if (purchased > 0) {
      return {
        action: "pickup",
        reason: "collect_purchased_goods",
        command: {
          commandType: "trade_hub_transfer_party_goods",
          command: {
            commandId: `${policy.commandIdPrefix}:pickup`,
            issuerActorId: affordances.issuerActorId,
            accountEntityId: affordances.accountEntityId,
            partyId: affordances.party.id,
            hubId: opportunity.source.hubId,
            goodsId: policy.goodsId,
            amount: Math.min(purchased, policy.quantity),
            direction: "withdraw",
          },
        },
      };
    }
    if (local.account.escrowCurrency > 0) return noTradeAction("awaiting_buy_match");
    return {
      action: "place_buy",
      reason: "buy_from_remembered_local_ask",
      command: {
        commandType: "place_trade_hub_order",
        command: {
          commandId: `${policy.commandIdPrefix}:buy`,
          issuerActorId: affordances.issuerActorId,
          accountEntityId: affordances.accountEntityId,
          hubId: opportunity.source.hubId,
          orderId: `${policy.commandIdPrefix}:buy-order`,
          side: "buy",
          goodsId: policy.goodsId,
          quantity: policy.quantity,
          limitPrice: opportunity.source.bestAsk,
          expiresAtElapsedDays: null,
        },
      },
    };
  }

  process(
    simulation: WorldSimulation,
    partyId: string,
    memoryEntries: readonly MerchantMemoryEntry[],
  ): MerchantMemoryDecision {
    const party = simulation.partySnapshot(partyId);
    if (party.status !== "idle" || party.currentNodeId === null) {
      return noAction("party_busy");
    }

    const ownedMemory = memoryEntries.filter((entry) => entry.ownerId === partyId);
    const need = ownedMemory.find((entry): entry is NeedLedgerMemory =>
      entry.kind === "need_ledger" && entry.goodsId === "food" && entry.neededAmount > 0);
    if (need === undefined) return noAction("food_need_memory_missing");

    const carriedFood = party.cargo.food ?? 0;
    if (carriedFood > 0) {
      if (party.currentNodeId === need.nodeId) {
        return submit(simulation, "deposit", {
          commandType: "transfer_goods",
          command: {
            party_id: partyId,
            location_id: need.locationId,
            goods_id: "food",
            amount: Math.min(carriedFood, need.neededAmount),
            direction: "deposit_to_location",
          },
        });
      }
      return submit(simulation, "travel", {
        commandType: "move_party",
        command: {
          party_id: partyId,
          from_node_id: party.currentNodeId,
          to_node_id: need.nodeId,
        },
      });
    }

    const source = ownedMemory.find((entry): entry is LocationObservationMemory =>
      entry.kind === "location_observation"
      && entry.nodeId === party.currentNodeId
      && (entry.observedResources.food ?? 0) > 0);
    if (source === undefined) return noAction("local_food_source_memory_missing");
    if (party.cargoCapacityBulk === null || party.cargoUsedBulk === null) {
      return noAction("economy_not_configured");
    }
    const freeBulk = party.cargoCapacityBulk - party.cargoUsedBulk;
    const amount = Math.min(
      Math.floor(freeBulk),
      source.observedResources.food ?? 0,
      need.neededAmount,
    );
    if (amount <= 0) return noAction("no_food_capacity");
    return submit(simulation, "withdraw", {
      commandType: "transfer_goods",
      command: {
        party_id: partyId,
        location_id: source.observedLocationId,
        goods_id: "food",
        amount,
        direction: "withdraw_from_location",
      },
    });
  }
}

interface TradeObservation {
  readonly sequence: number;
  readonly hubId: string;
  readonly nodeId: string;
  readonly prices: ReadonlyMap<string, { readonly bestBid: number | null; readonly bestAsk: number | null }>;
}

function parseTradeObservation(entry: WorldMemoryEntryView): TradeObservation | null {
  const { hubId, nodeId, market } = entry.payload;
  if (typeof hubId !== "string" || typeof nodeId !== "string" || !Array.isArray(market)) return null;
  const prices = new Map<string, { bestBid: number | null; bestAsk: number | null }>();
  for (const item of market) {
    if (item === null || Array.isArray(item) || typeof item !== "object") return null;
    const goodsId = item.goodsId;
    const bestBid = item.bestBid;
    const bestAsk = item.bestAsk;
    if (typeof goodsId !== "string") return null;
    if (bestBid !== null && (!Number.isSafeInteger(bestBid) || bestBid <= 0)) return null;
    if (bestAsk !== null && (!Number.isSafeInteger(bestAsk) || bestAsk <= 0)) return null;
    prices.set(goodsId, { bestBid: bestBid as number | null, bestAsk: bestAsk as number | null });
  }
  return { sequence: entry.sequence, hubId, nodeId, prices };
}

function selectOpportunity(
  observations: readonly TradeObservation[],
  goodsId: string,
): { readonly source: TradeObservation & { readonly bestAsk: number }; readonly destination: TradeObservation & { readonly bestBid: number } } | null {
  const latest = new Map<string, TradeObservation>();
  for (const observation of observations) latest.set(observation.hubId, observation);
  const sources = [...latest.values()]
    .flatMap((observation) => {
      const bestAsk = observation.prices.get(goodsId)?.bestAsk;
      return bestAsk === null || bestAsk === undefined ? [] : [{ ...observation, bestAsk }];
    })
    .sort((a, b) => a.bestAsk - b.bestAsk || a.sequence - b.sequence);
  const destinations = [...latest.values()]
    .flatMap((observation) => {
      const bestBid = observation.prices.get(goodsId)?.bestBid;
      return bestBid === null || bestBid === undefined ? [] : [{ ...observation, bestBid }];
    })
    .sort((a, b) => b.bestBid - a.bestBid || a.sequence - b.sequence);
  for (const source of sources) {
    for (const destination of destinations) {
      if (source.hubId !== destination.hubId && destination.bestBid > source.bestAsk) {
        return { source, destination };
      }
    }
  }
  return null;
}

function noTradeAction(reason: string): MerchantTradeDecision {
  return { action: "none", reason, command: null };
}

function submit(
  simulation: WorldSimulation,
  action: Exclude<MerchantMemoryAction, "none">,
  command: Extract<WorldCommandEnvelope, { readonly commandType: "move_party" | "transfer_goods" }>,
): MerchantMemoryDecision {
  const commandResult = command.commandType === "move_party"
    ? simulation.submitCommand(command).result
    : simulation.submitCommand(command).result;
  return {
    action,
    reason: commandResult.accepted ? "command_accepted" : "command_rejected",
    submittedCommand: command,
    commandResult,
  };
}

function noAction(reason: string): MerchantMemoryDecision {
  return { action: "none", reason, submittedCommand: null, commandResult: null };
}
