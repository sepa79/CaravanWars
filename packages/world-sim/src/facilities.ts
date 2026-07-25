import type { ScheduledEventIntent } from "./world-clock.js";

export const FACILITY_PRODUCTION_TICK_DUE = "FacilityProductionTickDue";
export const FACILITIES_COMPONENT = "facilities";

export type ResourceQuantities = Readonly<Record<string, number>>;

export interface PopulationCohortSeed {
  readonly cohortId: string;
  readonly population: number;
  readonly availableWorkforce: number;
  readonly unrest: number;
}

export interface FacilityHostSeed {
  readonly hostId: string;
  readonly inventory: ResourceQuantities;
  readonly storageCaps: ResourceQuantities;
  readonly cohorts: readonly PopulationCohortSeed[];
}

export interface FacilityRecipe {
  readonly inputs: ResourceQuantities;
  readonly energyInputs: ResourceQuantities;
  readonly maintenanceInputs: ResourceQuantities;
  readonly outputs: ResourceQuantities;
  readonly workforceRequired: number;
  readonly cycleDays: number;
  readonly blockedRetryDays: number | null;
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
  | FacilityProductionIgnoredEvent;

export interface FacilityTickResult {
  readonly event: FacilityProductionEvent;
  readonly nextIntent: ScheduledEventIntent | null;
}

export interface FacilitySnapshot extends FacilitySeed {}

export interface FacilityHostSnapshot extends FacilityHostSeed {}

export interface FacilitiesSnapshot {
  readonly facilities: readonly FacilitySnapshot[];
  readonly hosts: readonly FacilityHostSnapshot[];
}

export interface CohortShortageEffect {
  readonly cohortId: string;
  readonly unrestIncrease: number;
  readonly workforceLoss: number;
}

export type ResourceConsumptionResult =
  | { readonly outcome: "consumed"; readonly consumed: number }
  | {
      readonly outcome: "shortage";
      readonly available: number;
      readonly required: number;
      readonly cohort: PopulationCohortSeed;
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
}

interface FacilityHostRuntimeState {
  readonly hostId: string;
  readonly inventory: Map<string, number>;
  readonly storageCaps: Readonly<Record<string, number>>;
  readonly cohorts: Map<string, PopulationCohortSeed>;
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

  constructor(facilitySeeds: readonly FacilitySeed[], hostSeeds: readonly FacilityHostSeed[]) {
    this.#hosts = createHosts(hostSeeds);
    this.#facilities = createFacilities(facilitySeeds, this.#hosts);
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
        },
        nextIntent: retry,
      };
    }

    const consumed = mergeQuantities(
      facility.recipe.inputs,
      facility.recipe.energyInputs,
      facility.recipe.maintenanceInputs,
    );
    for (const [resourceId, amount] of Object.entries(consumed)) {
      setQuantity(host.inventory, resourceId, (host.inventory.get(resourceId) ?? 0) - amount);
    }
    for (const [resourceId, amount] of Object.entries(facility.recipe.outputs)) {
      setQuantity(host.inventory, resourceId, (host.inventory.get(resourceId) ?? 0) + amount);
    }
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
    requireNonNegativeNumber(effect.unrestIncrease, "Unrest increase");
    requireNonNegativeInteger(effect.workforceLoss, "Workforce loss");
    const available = host.inventory.get(resourceId) ?? 0;
    if (available >= required) {
      setQuantity(host.inventory, resourceId, available - required);
      return { outcome: "consumed", consumed: required };
    }
    const updated: PopulationCohortSeed = {
      ...cohort,
      unrest: cohort.unrest + effect.unrestIncrease,
      availableWorkforce: Math.max(0, cohort.availableWorkforce - effect.workforceLoss),
    };
    host.cohorts.set(cohort.cohortId, updated);
    return { outcome: "shortage", available, required, cohort: { ...updated } };
  }

  snapshot(): FacilitiesSnapshot {
    return {
      facilities: [...this.#facilities.values()].map((facility) => ({
        ...facility,
        recipe: copyRecipe(facility.recipe),
        processedEventIds: [...facility.processedEventIds],
      })),
      hosts: [...this.#hosts.values()].map((host) => ({
        hostId: host.hostId,
        inventory: Object.fromEntries(host.inventory),
        storageCaps: { ...host.storageCaps },
        cohorts: [...host.cohorts.values()].map((cohort) => ({ ...cohort })),
      })),
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
      cohorts.set(cohort.cohortId, { ...cohort });
    }
    for (const [resourceId, cap] of Object.entries(seed.storageCaps)) {
      requireNonNegativeNumber(cap, `Host ${seed.hostId} storage cap ${resourceId}`);
    }
    hosts.set(seed.hostId, {
      hostId: seed.hostId,
      inventory,
      storageCaps: { ...seed.storageCaps },
      cohorts,
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
    facilities.set(seed.facilityId, {
      ...seed,
      recipe: copyRecipe(seed.recipe),
      processedEventIds: new Set(seed.processedEventIds),
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
  return {
    ...recipe,
    inputs: { ...recipe.inputs },
    energyInputs: { ...recipe.energyInputs },
    maintenanceInputs: { ...recipe.maintenanceInputs },
    outputs: { ...recipe.outputs },
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

function requireNonNegativeInteger(value: number, label: string): void {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new FacilitiesValidationError(`${label} must be a non-negative safe integer.`);
  }
}
