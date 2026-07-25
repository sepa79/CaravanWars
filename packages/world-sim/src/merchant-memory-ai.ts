import type {
  CommandResult,
  TransferGoodsResult,
  WorldCommandEnvelope,
} from "./world-sim.js";
import { WorldSimulation } from "./world-sim.js";

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

export class MerchantMemoryAI {
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

function submit(
  simulation: WorldSimulation,
  action: Exclude<MerchantMemoryAction, "none">,
  command: Exclude<WorldCommandEnvelope, { readonly commandType: "set_facility_operation" }>,
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
