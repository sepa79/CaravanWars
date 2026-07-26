import type { ScheduledEventIntent } from "./world-clock.js";
import {
  FACILITY_PROFILE_PROCESS_DUE,
  FacilityProfileRuntime,
} from "./facility-profiles.js";
import type {
  FacilityProfileProcessEvent,
  FacilityProfileRuntimeSnapshot,
} from "./facility-profiles.js";

export const FACILITY_PRODUCTION_TICK_DUE = "FacilityProductionTickDue";
export const FACILITIES_COMPONENT = "facilities";

export type ResourceQuantities = Readonly<Record<string, number>>;

export interface PopulationCohortSeed {
  readonly cohortId: string;
  readonly population: number;
  readonly availableWorkforce: number;
  readonly unrest: number;
  readonly conditions?: Readonly<Record<string, number>>;
}

export type ShortageConsequence =
  | { readonly type: "block" }
  | { readonly type: "reduced_output"; readonly outputPermille: number }
  | { readonly type: "retry"; readonly delayDays: number }
  | {
      readonly type: "cohort_delta";
      readonly cohortId: string;
      readonly conditionId: string;
      readonly conditionDelta: number;
      readonly unrestDelta: number;
      readonly workforceDelta: number;
      readonly application: "once_per_episode" | "each_attempt";
    }
  | { readonly type: "none" };

export interface ResourceShortagePolicy {
  readonly resourceId: string;
  readonly consequences: readonly ShortageConsequence[];
}

export interface FacilityHostSeed {
  readonly hostId: string;
  readonly inventory: ResourceQuantities;
  readonly storageCaps: ResourceQuantities;
  readonly cohorts: readonly PopulationCohortSeed[];
  readonly activeCohortShortageKeys?: readonly string[];
}

export interface FacilityRecipe {
  readonly inputs: ResourceQuantities;
  readonly energyInputs: ResourceQuantities;
  readonly maintenanceInputs: ResourceQuantities;
  readonly outputs: ResourceQuantities;
  readonly workforceRequired: number;
  readonly cycleDays: number;
  readonly blockedRetryDays: number | null;
  readonly shortagePolicies: readonly ResourceShortagePolicy[];
}

export interface FacilitySeed {
  readonly facilityId: string;
  readonly facilityType: string;
  readonly hostId: string;
  readonly ownerId: string;
  readonly governorActorId: string | null;
  readonly recipe: FacilityRecipe;
  readonly active: boolean;
  readonly generation: number;
  readonly nextEventOrdinal: number;
  readonly pendingTickEventId: string | null;
  readonly processedEventIds: readonly string[];
  readonly activeShortageResourceIds?: readonly string[];
}

export interface FacilityProductionTickPayload {
  readonly generation: number;
}

export type FacilityBlockedReason =
  | "missing_inputs"
  | "missing_energy"
  | "missing_maintenance"
  | "insufficient_workforce"
  | "output_storage_full";

export interface FacilityProductionTickedEvent {
  readonly eventType: "FacilityProductionTicked";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly facilityId: string;
  readonly generation: number;
  readonly outcome: "completed";
  readonly consumed: ResourceQuantities;
  readonly produced: ResourceQuantities;
  readonly availableWorkforce: number;
  readonly recoveredResourceIds: readonly string[];
}

export interface FacilityProductionBlockedEvent {
  readonly eventType: "FacilityProductionBlocked";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly facilityId: string;
  readonly generation: number;
  readonly outcome: "blocked";
  readonly reason: FacilityBlockedReason;
  readonly retryEventId: string | null;
  readonly missingResourceIds: readonly string[];
  readonly appliedConsequences: readonly ShortageConsequence[];
}

export interface FacilityProductionDegradedEvent {
  readonly eventType: "FacilityProductionDegraded";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly facilityId: string;
  readonly generation: number;
  readonly outcome: "degraded";
  readonly missingResourceIds: readonly string[];
  readonly outputPermille: number;
  readonly consumed: ResourceQuantities;
  readonly produced: ResourceQuantities;
  readonly retryEventId: string | null;
  readonly appliedConsequences: readonly ShortageConsequence[];
}

export interface FacilityProductionRecoveredEvent {
  readonly eventType: "FacilityProductionRecovered";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly facilityId: string;
  readonly generation: number;
  readonly recoveredResourceIds: readonly string[];
}

export interface FacilityProductionIgnoredEvent {
  readonly eventType: "FacilityProductionIgnored";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly facilityId: string;
  readonly generation: number;
  readonly outcome: "ignored";
  readonly reason: "duplicate" | "stale_generation" | "inactive";
}

export type FacilityProductionEvent =
  | FacilityProductionTickedEvent
  | FacilityProductionBlockedEvent
  | FacilityProductionDegradedEvent
  | FacilityProductionIgnoredEvent;

export interface FacilityTickResult {
  readonly event: FacilityProductionEvent;
  readonly recoveryEvent: FacilityProductionRecoveredEvent | null;
  readonly nextIntent: ScheduledEventIntent | null;
}

export interface FacilitySnapshot extends FacilitySeed {}

export interface FacilityHostSnapshot extends FacilityHostSeed {}

export interface FacilitiesSnapshot {
  readonly facilities: readonly FacilitySnapshot[];
  readonly hosts: readonly FacilityHostSnapshot[];
  readonly profileRuntime?: FacilityProfileRuntimeSnapshot | null;
}

export interface CohortShortageEffect {
  readonly cohortId: string;
  readonly consequences: readonly ShortageConsequence[];
}

export type ResourceConsumptionResult =
  | {
      readonly outcome: "consumed";
      readonly consumed: number;
      readonly recovered: boolean;
    }
  | {
      readonly outcome: "shortage";
      readonly available: number;
      readonly required: number;
      readonly cohort: PopulationCohortSeed;
      readonly appliedConsequences: readonly ShortageConsequence[];
    };

interface FacilityRuntimeState {
  readonly facilityId: string;
  readonly facilityType: string;
  readonly hostId: string;
  readonly ownerId: string;
  readonly governorActorId: string | null;
  recipe: FacilityRecipe;
  active: boolean;
  generation: number;
  nextEventOrdinal: number;
  pendingTickEventId: string | null;
  readonly processedEventIds: Set<string>;
  readonly activeShortageResourceIds: Set<string>;
}

interface FacilityHostRuntimeState {
  readonly hostId: string;
  readonly inventory: Map<string, number>;
  readonly storageCaps: Readonly<Record<string, number>>;
  readonly cohorts: Map<string, PopulationCohortSeed>;
  readonly activeCohortShortageKeys: Set<string>;
}

export class FacilitiesValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "FacilitiesValidationError";
  }
}

export class Facilities {
  readonly #facilities: Map<string, FacilityRuntimeState>;
  readonly #hosts: Map<string, FacilityHostRuntimeState>;
  readonly #profileRuntime: FacilityProfileRuntime | null;

  constructor(facilitySeeds: readonly FacilitySeed[], hostSeeds: readonly FacilityHostSeed[], profileRuntime: FacilityProfileRuntimeSnapshot | null = null) {
    this.#hosts = createHosts(hostSeeds);
    this.#profileRuntime = profileRuntime === null ? null : new FacilityProfileRuntime(profileRuntime);
    this.#facilities = createFacilities(facilitySeeds, this.#hosts);
  }

  initialProfileIntents(elapsedDays: number): readonly ScheduledEventIntent[] {
    return this.#profileRuntime?.initialIntents(elapsedDays) ?? [];
  }

  handleProfileProcess(intent: ScheduledEventIntent, elapsedDays: number): { readonly event: FacilityProfileProcessEvent; readonly nextIntent: ScheduledEventIntent | null } {
    if (intent.kind !== FACILITY_PROFILE_PROCESS_DUE || this.#profileRuntime === null) {
      throw new FacilitiesValidationError(`No Facility profile runtime for ${intent.eventId}.`);
    }
    return this.#profileRuntime.handle(intent, elapsedDays, {
      available: (hostId, goodsId) => this.availableResource(hostId, goodsId),
      canApply: (hostId, consumed, produced) => {
        const host = this.#requireHost(hostId);
        for (const [goodsId, amount] of Object.entries(consumed)) {
          if ((host.inventory.get(goodsId) ?? 0) < amount) return false;
        }
        for (const [goodsId, amount] of Object.entries(produced)) {
          const finalAmount = (host.inventory.get(goodsId) ?? 0) - (consumed[goodsId] ?? 0) + amount;
          if (host.storageCaps[goodsId] === undefined || finalAmount > host.storageCaps[goodsId]!) return false;
        }
        return true;
      },
      apply: (hostId, consumed, produced) => {
        const host = this.#requireHost(hostId);
        for (const [goodsId, amount] of Object.entries(consumed)) setQuantity(host.inventory, goodsId, (host.inventory.get(goodsId) ?? 0) - amount);
        for (const [goodsId, amount] of Object.entries(produced)) setQuantity(host.inventory, goodsId, (host.inventory.get(goodsId) ?? 0) + amount);
      },
    });
  }

  startOrResume(facilityId: string, elapsedDays: number): ScheduledEventIntent {
    const facility = this.#requireFacility(facilityId);
    facility.active = true;
    facility.generation += 1;
    facility.pendingTickEventId = null;
    return this.#createTickIntent(facility, elapsedDays + facility.recipe.cycleDays);
  }

  pause(facilityId: string): void {
    const facility = this.#requireFacility(facilityId);
    facility.active = false;
    facility.generation += 1;
    facility.pendingTickEventId = null;
  }

  reconfigure(
    facilityId: string,
    recipe: FacilityRecipe,
    elapsedDays: number,
  ): ScheduledEventIntent | null {
    validateRecipe(recipe, facilityId);
    const facility = this.#requireFacility(facilityId);
    facility.recipe = copyRecipe(recipe);
    facility.generation += 1;
    facility.pendingTickEventId = null;
    return facility.active
      ? this.#createTickIntent(facility, elapsedDays + facility.recipe.cycleDays)
      : null;
  }

  initialTickIntent(facilityId: string, elapsedDays: number): ScheduledEventIntent | null {
    const facility = this.#requireFacility(facilityId);
    if (facility.pendingTickEventId !== null) return null;
    return facility.active
      ? this.#createTickIntent(facility, elapsedDays + facility.recipe.cycleDays)
      : null;
  }

  handleProductionTick(intent: ScheduledEventIntent, elapsedDays: number): FacilityTickResult {
    if (intent.kind !== FACILITY_PRODUCTION_TICK_DUE
      || intent.targetComponent !== FACILITIES_COMPONENT) {
      throw new FacilitiesValidationError(`Intent ${intent.eventId} is not a Facility tick.`);
    }
    const facility = this.#requireFacility(intent.targetEntityId);
    const generation = readGeneration(intent.payload, intent.eventId);
    if (facility.processedEventIds.has(intent.eventId)) {
      return ignored(intent, elapsedDays, generation, "duplicate");
    }
    facility.processedEventIds.add(intent.eventId);
    if (generation !== facility.generation) {
      return ignored(intent, elapsedDays, generation, "stale_generation");
    }
    if (!facility.active) return ignored(intent, elapsedDays, generation, "inactive");
    if (facility.pendingTickEventId !== intent.eventId) {
      return ignored(intent, elapsedDays, generation, "stale_generation");
    }
    facility.pendingTickEventId = null;

    const host = this.#requireHost(facility.hostId);
    const availableWorkforce = [...host.cohorts.values()]
      .reduce((total, cohort) => total + cohort.availableWorkforce, 0);
    const missingResourceIds = findMissingResourceIds(host, facility.recipe);
    if (missingResourceIds.length > 0) {
      const shortage = evaluateShortage(facility.recipe, missingResourceIds);
      const appliedConsequences = applyShortageConsequences(
        host,
        shortage.consequences,
        facility.activeShortageResourceIds,
        missingResourceIds,
      );
      for (const resourceId of missingResourceIds) facility.activeShortageResourceIds.add(resourceId);
      const retryDelayDays = shortage.retryDelayDays;
      const nextDelay = retryDelayDays ?? (shortage.blocked ? null : facility.recipe.cycleDays);
      const nextIntent = nextDelay === null
        ? null
        : this.#createTickIntent(facility, elapsedDays + nextDelay);
      if (shortage.blocked) {
        return {
          event: {
            eventType: "FacilityProductionBlocked",
            scheduledEventId: intent.eventId,
            elapsedDays,
            facilityId: facility.facilityId,
            generation,
            outcome: "blocked",
            reason: blockedReasonForMissing(facility.recipe, missingResourceIds),
            retryEventId: nextIntent?.eventId ?? null,
            missingResourceIds,
            appliedConsequences,
          },
          recoveryEvent: null,
          nextIntent,
        };
      }
      const consumed = availableRequiredQuantities(host, facility.recipe);
      const produced = scaleQuantities(facility.recipe.outputs, shortage.outputPermille);
      if (!hasOutputCapacity(host, produced)) {
        const retry = facility.recipe.blockedRetryDays === null
          ? null
          : this.#createTickIntent(facility, elapsedDays + facility.recipe.blockedRetryDays);
        return {
          event: {
            eventType: "FacilityProductionBlocked",
            scheduledEventId: intent.eventId,
            elapsedDays,
            facilityId: facility.facilityId,
            generation,
            outcome: "blocked",
            reason: "output_storage_full",
            retryEventId: retry?.eventId ?? null,
            missingResourceIds,
            appliedConsequences,
          },
          recoveryEvent: null,
          nextIntent: retry,
        };
      }
      applyProduction(host, consumed, produced);
      return {
        event: {
          eventType: "FacilityProductionDegraded",
          scheduledEventId: intent.eventId,
          elapsedDays,
          facilityId: facility.facilityId,
          generation,
          outcome: "degraded",
          missingResourceIds,
          outputPermille: shortage.outputPermille,
          consumed,
          produced,
          retryEventId: retryDelayDays === null ? null : nextIntent?.eventId ?? null,
          appliedConsequences,
        },
        recoveryEvent: null,
        nextIntent,
      };
    }
    const blockedReason = determineBlockedReason(host, facility.recipe, availableWorkforce);
    if (blockedReason !== null) {
      const retry = facility.recipe.blockedRetryDays === null
        ? null
        : this.#createTickIntent(facility, elapsedDays + facility.recipe.blockedRetryDays);
      return {
        event: {
          eventType: "FacilityProductionBlocked",
          scheduledEventId: intent.eventId,
          elapsedDays,
          facilityId: facility.facilityId,
          generation,
          outcome: "blocked",
          reason: blockedReason,
          retryEventId: retry?.eventId ?? null,
          missingResourceIds: [],
          appliedConsequences: [],
        },
        recoveryEvent: null,
        nextIntent: retry,
      };
    }

    const consumed = mergeQuantities(
      facility.recipe.inputs,
      facility.recipe.energyInputs,
      facility.recipe.maintenanceInputs,
    );
    applyProduction(host, consumed, facility.recipe.outputs);
    const recoveredResourceIds = [...facility.activeShortageResourceIds].sort();
    facility.activeShortageResourceIds.clear();
    const nextIntent = this.#createTickIntent(facility, elapsedDays + facility.recipe.cycleDays);
    return {
      event: {
        eventType: "FacilityProductionTicked",
        scheduledEventId: intent.eventId,
        elapsedDays,
        facilityId: facility.facilityId,
        generation,
        outcome: "completed",
        consumed,
        produced: { ...facility.recipe.outputs },
        availableWorkforce,
        recoveredResourceIds,
      },
      recoveryEvent: recoveredResourceIds.length === 0 ? null : {
        eventType: "FacilityProductionRecovered",
        scheduledEventId: intent.eventId,
        elapsedDays,
        facilityId: facility.facilityId,
        generation,
        recoveredResourceIds,
      },
      nextIntent,
    };
  }

  deposit(hostId: string, resourceId: string, amount: number): boolean {
    requirePositiveNumber(amount, "Deposit amount");
    const host = this.#requireHost(hostId);
    const current = host.inventory.get(resourceId) ?? 0;
    const cap = host.storageCaps[resourceId];
    if (cap === undefined || current + amount > cap) return false;
    host.inventory.set(resourceId, current + amount);
    return true;
  }

  availableResource(hostId: string, resourceId: string): number {
    return this.#requireHost(hostId).inventory.get(resourceId) ?? 0;
  }

  facilitySnapshot(facilityId: string): FacilitySnapshot {
    const facility = this.#requireFacility(facilityId);
    return this.snapshot().facilities.find((item) => item.facilityId === facility.facilityId)!;
  }

  canDeposit(hostId: string, resourceId: string, amount: number): boolean {
    requirePositiveNumber(amount, "Deposit amount");
    const host = this.#requireHost(hostId);
    const cap = host.storageCaps[resourceId];
    return cap !== undefined && (host.inventory.get(resourceId) ?? 0) + amount <= cap;
  }

  withdraw(hostId: string, resourceId: string, amount: number): boolean {
    requirePositiveNumber(amount, "Withdrawal amount");
    const host = this.#requireHost(hostId);
    const available = host.inventory.get(resourceId) ?? 0;
    if (available < amount) return false;
    setQuantity(host.inventory, resourceId, available - amount);
    return true;
  }

  consumeForCohort(
    hostId: string,
    resourceId: string,
    required: number,
    effect: CohortShortageEffect,
  ): ResourceConsumptionResult {
    requirePositiveNumber(required, "Consumption amount");
    const host = this.#requireHost(hostId);
    const cohort = host.cohorts.get(effect.cohortId);
    if (cohort === undefined) {
      throw new FacilitiesValidationError(`Host ${hostId} has no cohort ${effect.cohortId}.`);
    }
    validateShortageConsequences(effect.consequences, `Cohort ${effect.cohortId} need`);
    const available = host.inventory.get(resourceId) ?? 0;
    const shortageKey = `${effect.cohortId}:${resourceId}`;
    if (available >= required) {
      setQuantity(host.inventory, resourceId, available - required);
      const recovered = host.activeCohortShortageKeys.delete(shortageKey);
      return { outcome: "consumed", consumed: required, recovered };
    }
    const alreadyActive = host.activeCohortShortageKeys.has(shortageKey);
    const applied = applyCohortNeedConsequences(host, effect, alreadyActive);
    host.activeCohortShortageKeys.add(shortageKey);
    return {
      outcome: "shortage",
      available,
      required,
      cohort: { ...host.cohorts.get(cohort.cohortId)!, conditions: { ...host.cohorts.get(cohort.cohortId)!.conditions } },
      appliedConsequences: applied,
    };
  }

  snapshot(): FacilitiesSnapshot {
    return {
      facilities: [...this.#facilities.values()].map((facility) => ({
        ...facility,
        recipe: copyRecipe(facility.recipe),
        processedEventIds: [...facility.processedEventIds],
        activeShortageResourceIds: [...facility.activeShortageResourceIds].sort(),
      })),
      hosts: [...this.#hosts.values()].map((host) => ({
        hostId: host.hostId,
        inventory: Object.fromEntries(host.inventory),
        storageCaps: { ...host.storageCaps },
        cohorts: [...host.cohorts.values()].map((cohort) => ({
          ...cohort,
          conditions: { ...cohort.conditions },
        })),
        activeCohortShortageKeys: [...host.activeCohortShortageKeys].sort(),
      })),
      profileRuntime: this.#profileRuntime?.snapshot() ?? null,
    };
  }

  #createTickIntent(facility: FacilityRuntimeState, dueElapsedDays: number): ScheduledEventIntent {
    const eventId = `${facility.facilityId}:g${facility.generation}:tick:${facility.nextEventOrdinal}`;
    facility.nextEventOrdinal += 1;
    facility.pendingTickEventId = eventId;
    return {
      eventId,
      kind: FACILITY_PRODUCTION_TICK_DUE,
      dueElapsedDays,
      targetComponent: FACILITIES_COMPONENT,
      targetEntityId: facility.facilityId,
      payload: { generation: facility.generation },
    };
  }

  #requireFacility(facilityId: string): FacilityRuntimeState {
    const facility = this.#facilities.get(facilityId);
    if (facility === undefined) throw new FacilitiesValidationError(`Unknown Facility ${facilityId}.`);
    return facility;
  }

  #requireHost(hostId: string): FacilityHostRuntimeState {
    const host = this.#hosts.get(hostId);
    if (host === undefined) throw new FacilitiesValidationError(`Unknown Facility host ${hostId}.`);
    return host;
  }
}

function createHosts(seeds: readonly FacilityHostSeed[]): Map<string, FacilityHostRuntimeState> {
  const hosts = new Map<string, FacilityHostRuntimeState>();
  for (const seed of seeds) {
    requireId(seed.hostId, "Facility host id");
    if (hosts.has(seed.hostId)) throw new FacilitiesValidationError(`Duplicate host ${seed.hostId}.`);
    const inventory = new Map<string, number>();
    for (const [resourceId, amount] of Object.entries(seed.inventory)) {
      requireNonNegativeNumber(amount, `Host ${seed.hostId} inventory ${resourceId}`);
      const cap = seed.storageCaps[resourceId];
      if (cap === undefined || amount > cap) {
        throw new FacilitiesValidationError(`Host ${seed.hostId} inventory ${resourceId} exceeds cap.`);
      }
      inventory.set(resourceId, amount);
    }
    const cohorts = new Map<string, PopulationCohortSeed>();
    for (const cohort of seed.cohorts) {
      requireId(cohort.cohortId, "Cohort id");
      if (cohorts.has(cohort.cohortId)) {
        throw new FacilitiesValidationError(`Duplicate cohort ${cohort.cohortId}.`);
      }
      requireNonNegativeInteger(cohort.population, `Cohort ${cohort.cohortId} population`);
      requireNonNegativeInteger(
        cohort.availableWorkforce,
        `Cohort ${cohort.cohortId} workforce`,
      );
      if (cohort.availableWorkforce > cohort.population) {
        throw new FacilitiesValidationError(`Cohort ${cohort.cohortId} workforce exceeds population.`);
      }
      requireNonNegativeNumber(cohort.unrest, `Cohort ${cohort.cohortId} unrest`);
      const conditions = cohort.conditions ?? {};
      for (const [conditionId, value] of Object.entries(conditions)) {
        requireId(conditionId, `Cohort ${cohort.cohortId} condition id`);
        requireFiniteNumber(value, `Cohort ${cohort.cohortId} condition ${conditionId}`);
      }
      cohorts.set(cohort.cohortId, { ...cohort, conditions: { ...conditions } });
    }
    for (const [resourceId, cap] of Object.entries(seed.storageCaps)) {
      requireNonNegativeNumber(cap, `Host ${seed.hostId} storage cap ${resourceId}`);
    }
    const activeCohortShortageKeys = seed.activeCohortShortageKeys ?? [];
    if (new Set(activeCohortShortageKeys).size !== activeCohortShortageKeys.length) {
      throw new FacilitiesValidationError(`Host ${seed.hostId} has duplicate cohort shortage keys.`);
    }
    for (const key of activeCohortShortageKeys) requireId(key, `Host ${seed.hostId} cohort shortage key`);
    hosts.set(seed.hostId, {
      hostId: seed.hostId,
      inventory,
      storageCaps: { ...seed.storageCaps },
      cohorts,
      activeCohortShortageKeys: new Set(activeCohortShortageKeys),
    });
  }
  return hosts;
}

function createFacilities(
  seeds: readonly FacilitySeed[],
  hosts: ReadonlyMap<string, FacilityHostRuntimeState>,
): Map<string, FacilityRuntimeState> {
  const facilities = new Map<string, FacilityRuntimeState>();
  for (const seed of seeds) {
    requireId(seed.facilityId, "Facility id");
    requireId(seed.facilityType, `Facility ${seed.facilityId} type`);
    requireId(seed.ownerId, `Facility ${seed.facilityId} owner`);
    if (!hosts.has(seed.hostId)) {
      throw new FacilitiesValidationError(`Facility ${seed.facilityId} has missing host ${seed.hostId}.`);
    }
    if (facilities.has(seed.facilityId)) {
      throw new FacilitiesValidationError(`Duplicate Facility ${seed.facilityId}.`);
    }
    validateRecipe(seed.recipe, seed.facilityId);
    requireNonNegativeInteger(seed.generation, `Facility ${seed.facilityId} generation`);
    requireNonNegativeInteger(seed.nextEventOrdinal, `Facility ${seed.facilityId} event ordinal`);
    if (seed.pendingTickEventId !== null) {
      requireId(seed.pendingTickEventId, `Facility ${seed.facilityId} pending tick id`);
    }
    if (new Set(seed.processedEventIds).size !== seed.processedEventIds.length) {
      throw new FacilitiesValidationError(`Facility ${seed.facilityId} has duplicate processed ids.`);
    }
    const activeShortageResourceIds = seed.activeShortageResourceIds ?? [];
    if (new Set(activeShortageResourceIds).size !== activeShortageResourceIds.length) {
      throw new FacilitiesValidationError(`Facility ${seed.facilityId} has duplicate active shortages.`);
    }
    for (const resourceId of activeShortageResourceIds) requireId(resourceId, "Active shortage resource id");
    facilities.set(seed.facilityId, {
      ...seed,
      recipe: copyRecipe(seed.recipe),
      processedEventIds: new Set(seed.processedEventIds),
      activeShortageResourceIds: new Set(activeShortageResourceIds),
    });
  }
  return facilities;
}

function validateRecipe(recipe: FacilityRecipe, facilityId: string): void {
  validateQuantities(recipe.inputs, `${facilityId} inputs`);
  validateQuantities(recipe.energyInputs, `${facilityId} energy inputs`);
  validateQuantities(recipe.maintenanceInputs, `${facilityId} maintenance inputs`);
  validateQuantities(recipe.outputs, `${facilityId} outputs`);
  requireNonNegativeNumber(recipe.workforceRequired, `${facilityId} workforce`);
  requirePositiveNumber(recipe.cycleDays, `${facilityId} cycle days`);
  if (recipe.blockedRetryDays !== null) {
    requirePositiveNumber(recipe.blockedRetryDays, `${facilityId} retry days`);
  }
  const requiredResourceIds = new Set([
    ...Object.keys(recipe.inputs),
    ...Object.keys(recipe.energyInputs),
    ...Object.keys(recipe.maintenanceInputs),
  ]);
  const policies = recipe.shortagePolicies;
  const seen = new Set<string>();
  for (const policy of policies) {
    requireId(policy.resourceId, `${facilityId} shortage resource`);
    if (!requiredResourceIds.has(policy.resourceId)) {
      throw new FacilitiesValidationError(`${facilityId} shortage policy references undeclared ${policy.resourceId}.`);
    }
    if (seen.has(policy.resourceId)) {
      throw new FacilitiesValidationError(`${facilityId} has duplicate shortage policy for ${policy.resourceId}.`);
    }
    seen.add(policy.resourceId);
    validateShortageConsequences(policy.consequences, `${facilityId}/${policy.resourceId}`);
  }
  for (const resourceId of requiredResourceIds) {
    if (!seen.has(resourceId)) {
      throw new FacilitiesValidationError(`${facilityId} has no shortage policy for ${resourceId}.`);
    }
  }
}

function determineBlockedReason(
  host: FacilityHostRuntimeState,
  recipe: FacilityRecipe,
  availableWorkforce: number,
): FacilityBlockedReason | null {
  if (!hasQuantities(host.inventory, recipe.inputs)) return "missing_inputs";
  if (!hasQuantities(host.inventory, recipe.energyInputs)) return "missing_energy";
  if (!hasQuantities(host.inventory, recipe.maintenanceInputs)) return "missing_maintenance";
  if (availableWorkforce < recipe.workforceRequired) return "insufficient_workforce";
  for (const [resourceId, amount] of Object.entries(recipe.outputs)) {
    const cap = host.storageCaps[resourceId];
    if (cap === undefined || (host.inventory.get(resourceId) ?? 0) + amount > cap) {
      return "output_storage_full";
    }
  }
  return null;
}

function findMissingResourceIds(
  host: FacilityHostRuntimeState,
  recipe: FacilityRecipe,
): readonly string[] {
  const required = mergeQuantities(recipe.inputs, recipe.energyInputs, recipe.maintenanceInputs);
  return Object.entries(required)
    .filter(([resourceId, amount]) => (host.inventory.get(resourceId) ?? 0) < amount)
    .map(([resourceId]) => resourceId)
    .sort();
}

function blockedReasonForMissing(
  recipe: FacilityRecipe,
  missingResourceIds: readonly string[],
): FacilityBlockedReason {
  if (missingResourceIds.some((resourceId) => resourceId in recipe.inputs)) return "missing_inputs";
  if (missingResourceIds.some((resourceId) => resourceId in recipe.energyInputs)) return "missing_energy";
  return "missing_maintenance";
}

function evaluateShortage(
  recipe: FacilityRecipe,
  missingResourceIds: readonly string[],
): {
  readonly blocked: boolean;
  readonly outputPermille: number;
  readonly retryDelayDays: number | null;
  readonly consequences: readonly ShortageConsequence[];
} {
  const policies = new Map((recipe.shortagePolicies ?? []).map((policy) => [policy.resourceId, policy]));
  const defaultConsequences: readonly ShortageConsequence[] = [{ type: "block" }, { type: "none" }];
  const consequences: readonly ShortageConsequence[] = missingResourceIds.flatMap((resourceId) =>
    policies.get(resourceId)?.consequences ?? defaultConsequences);
  const outputPermilles = consequences.flatMap((consequence) =>
    consequence.type === "reduced_output" ? [consequence.outputPermille] : []);
  const retryDelays = consequences.flatMap((consequence) =>
    consequence.type === "retry" ? [consequence.delayDays] : []);
  return {
    blocked: consequences.some((consequence) => consequence.type === "block")
      || outputPermilles.length === 0,
    outputPermille: outputPermilles.length === 0 ? 0 : Math.min(...outputPermilles),
    retryDelayDays: retryDelays.length === 0 ? null : Math.min(...retryDelays),
    consequences,
  };
}

function applyShortageConsequences(
  host: FacilityHostRuntimeState,
  consequences: readonly ShortageConsequence[],
  activeResourceIds: ReadonlySet<string>,
  missingResourceIds: readonly string[],
): readonly ShortageConsequence[] {
  const episodeAlreadyActive = missingResourceIds.every((resourceId) => activeResourceIds.has(resourceId));
  const applied: ShortageConsequence[] = [];
  for (const consequence of consequences) {
    if (consequence.type !== "cohort_delta") continue;
    if (consequence.application === "once_per_episode" && episodeAlreadyActive) continue;
    const cohort = host.cohorts.get(consequence.cohortId);
    if (cohort === undefined) {
      throw new FacilitiesValidationError(`Host ${host.hostId} has no cohort ${consequence.cohortId}.`);
    }
    const conditions = { ...(cohort.conditions ?? {}) };
    conditions[consequence.conditionId] = (conditions[consequence.conditionId] ?? 0)
      + consequence.conditionDelta;
    host.cohorts.set(cohort.cohortId, {
      ...cohort,
      conditions,
      unrest: Math.max(0, cohort.unrest + consequence.unrestDelta),
      availableWorkforce: Math.max(
        0,
        Math.min(cohort.population, cohort.availableWorkforce + consequence.workforceDelta),
      ),
    });
    applied.push({ ...consequence });
  }
  return applied;
}

function applyCohortNeedConsequences(
  host: FacilityHostRuntimeState,
  effect: CohortShortageEffect,
  alreadyActive: boolean,
): readonly ShortageConsequence[] {
  const cohort = host.cohorts.get(effect.cohortId)!;
  const applied: ShortageConsequence[] = [];
  let updated = cohort;
  for (const consequence of effect.consequences) {
    if (consequence.type !== "cohort_delta") continue;
    if (consequence.cohortId !== effect.cohortId) {
      throw new FacilitiesValidationError(
        `Cohort need ${effect.cohortId} cannot mutate ${consequence.cohortId}.`,
      );
    }
    if (alreadyActive && consequence.application === "once_per_episode") continue;
    const conditions = { ...(updated.conditions ?? {}) };
    conditions[consequence.conditionId] = (conditions[consequence.conditionId] ?? 0)
      + consequence.conditionDelta;
    updated = {
      ...updated,
      conditions,
      unrest: Math.max(0, updated.unrest + consequence.unrestDelta),
      availableWorkforce: Math.max(
        0,
        Math.min(updated.population, updated.availableWorkforce + consequence.workforceDelta),
      ),
    };
    applied.push({ ...consequence });
  }
  host.cohorts.set(effect.cohortId, updated);
  return applied;
}

function availableRequiredQuantities(
  host: FacilityHostRuntimeState,
  recipe: FacilityRecipe,
): ResourceQuantities {
  const required = mergeQuantities(recipe.inputs, recipe.energyInputs, recipe.maintenanceInputs);
  return Object.fromEntries(Object.entries(required)
    .filter(([resourceId, amount]) => (host.inventory.get(resourceId) ?? 0) >= amount));
}

function scaleQuantities(quantities: ResourceQuantities, permille: number): ResourceQuantities {
  return Object.fromEntries(Object.entries(quantities)
    .map(([resourceId, amount]) => [resourceId, Math.floor(amount * permille / 1000)] as const)
    .filter(([, amount]) => amount > 0));
}

function hasOutputCapacity(host: FacilityHostRuntimeState, outputs: ResourceQuantities): boolean {
  return Object.entries(outputs).every(([resourceId, amount]) => {
    const cap = host.storageCaps[resourceId];
    return cap !== undefined && (host.inventory.get(resourceId) ?? 0) + amount <= cap;
  });
}

function applyProduction(
  host: FacilityHostRuntimeState,
  consumed: ResourceQuantities,
  produced: ResourceQuantities,
): void {
  for (const [resourceId, amount] of Object.entries(consumed)) {
    setQuantity(host.inventory, resourceId, (host.inventory.get(resourceId) ?? 0) - amount);
  }
  for (const [resourceId, amount] of Object.entries(produced)) {
    setQuantity(host.inventory, resourceId, (host.inventory.get(resourceId) ?? 0) + amount);
  }
}

export function validateShortageConsequences(
  value: unknown,
  label: string,
): asserts value is readonly ShortageConsequence[] {
  if (!Array.isArray(value)) throw new FacilitiesValidationError(`${label} consequences must be an array.`);
  for (const item of value) {
    if (item === null || typeof item !== "object" || Array.isArray(item)) {
      throw new FacilitiesValidationError(`${label} consequence must be an object.`);
    }
    const type = (item as { readonly type?: unknown }).type;
    if (type !== "block" && type !== "reduced_output" && type !== "retry"
      && type !== "cohort_delta" && type !== "none") {
      throw new FacilitiesValidationError(`${label} has unknown consequence type ${String(type)}.`);
    }
  }
  const consequences = value as readonly ShortageConsequence[];
  if (consequences.length === 0) throw new FacilitiesValidationError(`${label} consequences must not be empty.`);
  const productionModes = consequences.filter((item) => item.type === "block" || item.type === "reduced_output");
  if (productionModes.length !== 1) {
    throw new FacilitiesValidationError(`${label} requires exactly one block or reduced_output consequence.`);
  }
  const hasNone = consequences.some((item) => item.type === "none");
  const cohortConsequences = consequences.filter((item) => item.type === "cohort_delta");
  if (hasNone === (cohortConsequences.length > 0)) {
    throw new FacilitiesValidationError(`${label} requires either none or cohort_delta social consequences.`);
  }
  if (consequences.filter((item) => item.type === "retry").length > 1) {
    throw new FacilitiesValidationError(`${label} allows at most one retry consequence.`);
  }
  for (const consequence of consequences) {
    if (consequence.type === "reduced_output") {
      if (!Number.isSafeInteger(consequence.outputPermille)
        || consequence.outputPermille <= 0
        || consequence.outputPermille >= 1000) {
        throw new FacilitiesValidationError(`${label} outputPermille must be an integer from 1 to 999.`);
      }
    } else if (consequence.type === "retry") {
      requirePositiveNumber(consequence.delayDays, `${label} retry delay`);
    } else if (consequence.type === "cohort_delta") {
      requireId(consequence.cohortId, `${label} cohort id`);
      requireId(consequence.conditionId, `${label} condition id`);
      requireFiniteNumber(consequence.conditionDelta, `${label} condition delta`);
      requireFiniteNumber(consequence.unrestDelta, `${label} unrest delta`);
      if (!Number.isSafeInteger(consequence.workforceDelta)) {
        throw new FacilitiesValidationError(`${label} workforce delta must be a safe integer.`);
      }
    }
  }
}

function ignored(
  intent: ScheduledEventIntent,
  elapsedDays: number,
  generation: number,
  reason: FacilityProductionIgnoredEvent["reason"],
): FacilityTickResult {
  return {
    event: {
      eventType: "FacilityProductionIgnored",
      scheduledEventId: intent.eventId,
      elapsedDays,
      facilityId: intent.targetEntityId,
      generation,
      outcome: "ignored",
      reason,
    },
    recoveryEvent: null,
    nextIntent: null,
  };
}

function readGeneration(payload: unknown, eventId: string): number {
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new FacilitiesValidationError(`Facility intent ${eventId} payload must be an object.`);
  }
  const generation = (payload as { readonly generation?: unknown }).generation;
  if (!Number.isSafeInteger(generation) || (generation as number) < 0) {
    throw new FacilitiesValidationError(`Facility intent ${eventId} generation is invalid.`);
  }
  return generation as number;
}

function hasQuantities(inventory: ReadonlyMap<string, number>, needed: ResourceQuantities): boolean {
  return Object.entries(needed).every(([id, amount]) => (inventory.get(id) ?? 0) >= amount);
}

function mergeQuantities(...groups: readonly ResourceQuantities[]): ResourceQuantities {
  const merged: Record<string, number> = {};
  for (const group of groups) {
    for (const [id, amount] of Object.entries(group)) merged[id] = (merged[id] ?? 0) + amount;
  }
  return merged;
}

function setQuantity(inventory: Map<string, number>, id: string, amount: number): void {
  if (amount === 0) inventory.delete(id);
  else inventory.set(id, amount);
}

function validateQuantities(quantities: ResourceQuantities, label: string): void {
  for (const [id, amount] of Object.entries(quantities)) {
    requireId(id, label);
    requirePositiveNumber(amount, `${label} ${id}`);
  }
}

function copyRecipe(recipe: FacilityRecipe): FacilityRecipe {
  const copied: FacilityRecipe = {
    ...recipe,
    inputs: { ...recipe.inputs },
    energyInputs: { ...recipe.energyInputs },
    maintenanceInputs: { ...recipe.maintenanceInputs },
    outputs: { ...recipe.outputs },
  };
  if (recipe.shortagePolicies === undefined) return copied;
  return {
    ...copied,
    shortagePolicies: recipe.shortagePolicies.map((policy) => ({
      resourceId: policy.resourceId,
      consequences: policy.consequences.map((consequence) => ({ ...consequence })),
    })),
  };
}

function requireId(value: string, label: string): void {
  if (value.length === 0) throw new FacilitiesValidationError(`${label} must not be empty.`);
}

function requirePositiveNumber(value: number, label: string): void {
  if (!Number.isFinite(value) || value <= 0) {
    throw new FacilitiesValidationError(`${label} must be finite and positive.`);
  }
}

function requireNonNegativeNumber(value: number, label: string): void {
  if (!Number.isFinite(value) || value < 0) {
    throw new FacilitiesValidationError(`${label} must be finite and non-negative.`);
  }
}

function requireFiniteNumber(value: number, label: string): void {
  if (!Number.isFinite(value)) throw new FacilitiesValidationError(`${label} must be finite.`);
}

function requireNonNegativeInteger(value: number, label: string): void {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new FacilitiesValidationError(`${label} must be a non-negative safe integer.`);
  }
}
