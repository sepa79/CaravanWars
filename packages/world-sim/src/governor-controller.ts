import type { WorldMemoryEntryView, WorldMemoryOwnerView } from "./world-memory.js";

export interface GovernorShortagePolicy {
  readonly consequenceWeights: Readonly<Record<string, number>>;
}

export interface GovernorSupplyAffordance {
  readonly facilityId: string;
  readonly facilityHostId: string;
  readonly destinationNodeId: string;
  readonly executorPartyIds: readonly string[];
}

export interface AssignSupplyTaskCommand {
  readonly commandId: string;
  readonly issuerActorId: string;
  readonly taskId: string;
  readonly executorPartyId: string;
  readonly facilityId: string;
  readonly facilityHostId: string;
  readonly destinationNodeId: string;
  readonly goodsId: string;
  readonly amount: number;
}

export type GovernorDecision =
  | { readonly action: "none"; readonly reason: "NO_KNOWN_SHORTAGE" | "NO_LEGAL_AFFORDANCE" }
  | { readonly action: "assign_supply_task"; readonly command: AssignSupplyTaskCommand };

export class GovernorAIController {
  decide(
    memory: WorldMemoryOwnerView,
    affordances: readonly GovernorSupplyAffordance[],
    policy: GovernorShortagePolicy,
  ): GovernorDecision {
    const candidates = memory.entries
      .filter((entry) => entry.freshness === "fresh" && entry.kind === "shortage_observation")
      .filter((entry) => !hasLaterRecovery(memory, entry))
      .map((entry) => shortageCandidate(entry, policy))
      .filter((item): item is NonNullable<typeof item> => item !== null)
      .sort((left, right) => right.weight - left.weight || left.entry.sequence - right.entry.sequence);
    if (candidates.length === 0) return { action: "none", reason: "NO_KNOWN_SHORTAGE" };
    for (const candidate of candidates) {
      const affordance = affordances.find((item) => item.facilityId === candidate.facilityId);
      const executorPartyId = affordance?.executorPartyIds[0];
      if (affordance === undefined || executorPartyId === undefined) continue;
      return {
        action: "assign_supply_task",
        command: {
          commandId: `governor:${memory.ownerId}:shortage:${candidate.entry.entryId}`,
          issuerActorId: memory.ownerId,
          taskId: `supply:${candidate.entry.entryId}`,
          executorPartyId,
          facilityId: affordance.facilityId,
          facilityHostId: affordance.facilityHostId,
          destinationNodeId: affordance.destinationNodeId,
          goodsId: candidate.goodsId,
          amount: candidate.amount,
        },
      };
    }
    return { action: "none", reason: "NO_LEGAL_AFFORDANCE" };
  }
}

function hasLaterRecovery(memory: WorldMemoryOwnerView, shortage: WorldMemoryEntryView): boolean {
  return memory.entries.some((entry) => entry.kind === "shortage_recovered"
    && entry.sequence > shortage.sequence
    && entry.payload.facilityId === shortage.payload.facilityId
    && entry.payload.goodsId === shortage.payload.goodsId);
}

function shortageCandidate(entry: WorldMemoryEntryView, policy: GovernorShortagePolicy): {
  entry: WorldMemoryEntryView;
  facilityId: string;
  goodsId: string;
  amount: number;
  weight: number;
} | null {
  const facilityId = entry.payload.facilityId;
  const goodsId = entry.payload.goodsId;
  const amount = entry.payload.amount;
  const consequenceTypes = entry.payload.consequenceTypes;
  if (typeof facilityId !== "string" || typeof goodsId !== "string"
    || typeof amount !== "number" || !Number.isSafeInteger(amount) || amount <= 0
    || !Array.isArray(consequenceTypes)) return null;
  const weight = consequenceTypes.reduce((sum, type) =>
    sum + (typeof type === "string" ? (policy.consequenceWeights[type] ?? 0) : 0), 0);
  return { entry, facilityId, goodsId, amount, weight };
}
