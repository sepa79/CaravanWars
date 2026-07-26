import { calendarAt } from "./facility-profiles.js";
import type { SeasonId } from "./facility-profiles.js";
import type { ScheduledEventIntent, SerializableValue } from "./world-clock.js";
import type { WorldMemoryOwnerView } from "./world-memory.js";

export const POPULATION_SEASON_DUE = "PopulationSeasonDue";
export const POPULATION_MIGRATION_ARRIVAL_DUE = "PopulationMigrationArrivalDue";
export const POPULATION_COMPONENT = "population";

export type LabourSector = "agriculture" | "industry" | "transport" | "military" | "care";

export interface PopulationAgeCohorts {
  readonly children: number;
  readonly workingAdults: number;
  readonly elders: number;
}

export interface LabourAllocation {
  readonly allocationId: string;
  readonly targetEntityId: string;
  readonly sector: LabourSector;
  readonly workers: number;
}

export interface PopulationPolicy {
  readonly foodGoodsId: string;
  readonly foodUnitsPerPersonPerSeasonPermille: number;
  readonly rationingPermille: number;
  readonly reserveTargetUnits: number;
  readonly nutritionLossOnShortagePermille: number;
  readonly nutritionRecoveryPermille: number;
  readonly healthLossFromMalnutritionPermille: number;
  readonly healthRecoveryPermille: number;
  readonly unrestDeltaOnFoodShortage: number;
  readonly baselineBirthsPerAdultYearPermille: number;
  readonly baselineDeathsPerYearPermille: number;
  readonly malnutritionDeathsPerYearPermille: number;
  readonly maturationPerYearPermille: number;
  readonly agingPerYearPermille: number;
  readonly seasonalDiseaseRiskPermille: Readonly<Record<SeasonId, number>>;
  readonly diseaseHealthLossPermille: number;
  readonly diseaseDurationSeasons: number;
  readonly seasonalLabourAvailabilityPermille: Readonly<Record<SeasonId, number>>;
  readonly labourPriority: readonly LabourSector[];
}

export interface PopulationSettlementSeed {
  readonly settlementId: string;
  readonly nodeId: string;
  readonly hostId: string;
  readonly ownerId: string;
  readonly governorActorId: string | null;
  readonly cohorts: PopulationAgeCohorts;
  readonly healthPermille: number;
  readonly nutritionPermille: number;
  readonly unrest: number;
  readonly diseaseState: "none" | "active" | "recovering";
  readonly diseaseSeasonsRemaining: number;
  readonly allocations: readonly LabourAllocation[];
  readonly policy: PopulationPolicy;
  readonly nextEventOrdinal: number;
  readonly pendingSeasonEventId: string | null;
  readonly processedEventIds: readonly string[];
  readonly processedCommandIds: readonly ProcessedPopulationCommand[];
}

export interface PopulationMigrationSnapshot {
  readonly migrationId: string;
  readonly originSettlementId: string;
  readonly destinationSettlementId: string;
  readonly routeId: string;
  readonly people: number;
  readonly status: "traveling" | "arrived";
  readonly arrivalEventId: string;
}

export interface PopulationSnapshot {
  readonly settlements: readonly PopulationSettlementSeed[];
  readonly migrations: readonly PopulationMigrationSnapshot[];
}

export interface ProcessedPopulationCommand {
  readonly commandId: string;
  readonly fingerprint: string;
  readonly result: PopulationCommandResult;
}

export interface AllocateLabourCommand {
  readonly commandId: string;
  readonly issuerActorId: string;
  readonly settlementId: string;
  readonly allocations: readonly LabourAllocation[];
}

export interface StartMigrationCommand {
  readonly commandId: string;
  readonly issuerActorId: string;
  readonly migrationId: string;
  readonly originSettlementId: string;
  readonly destinationSettlementId: string;
  readonly routeId: string;
  readonly people: number;
  readonly travelDays: number;
}

export type PopulationCommand = AllocateLabourCommand | StartMigrationCommand;
export type PopulationCommandResult =
  | { readonly accepted: true; readonly idempotentReplay: boolean; readonly scheduledEventId: string | null }
  | { readonly accepted: false; readonly idempotentReplay: boolean; readonly errorCode: "NOT_AUTHORIZED" | "INVALID_COMMAND" | "INSUFFICIENT_PEOPLE" | "INSUFFICIENT_LABOUR" | "DUPLICATE_ACTIVE_MIGRATION" | "COMMAND_ID_CONFLICT" | "SCHEDULING_FAILED"; readonly message: string };

export interface PopulationSeasonPayload extends Record<string, SerializableValue> { readonly ordinal: number }
export interface PopulationMigrationPayload extends Record<string, SerializableValue> { readonly migrationId: string }

export interface PopulationSeasonEvent {
  readonly eventType: "PopulationSeasonAdvanced";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly settlementId: string;
  readonly season: SeasonId;
  readonly year: number;
  readonly populationBefore: number;
  readonly populationAfter: number;
  readonly foodRequired: number;
  readonly foodConsumed: number;
  readonly births: number;
  readonly deaths: number;
  readonly matured: number;
  readonly aged: number;
  readonly diseaseState: PopulationSettlementSeed["diseaseState"];
  readonly healthPermille: number;
  readonly nutritionPermille: number;
  readonly labourAvailable: number;
  readonly unrestDelta: number;
}

export interface PopulationMigrationEvent {
  readonly eventType: "PopulationMigrationStarted" | "PopulationMigrationArrived" | "PopulationEventIgnored";
  readonly scheduledEventId: string | null;
  readonly elapsedDays: number;
  readonly migrationId: string;
  readonly originSettlementId: string;
  readonly destinationSettlementId: string;
  readonly people: number;
  readonly reason: "started" | "arrived" | "duplicate";
}

export type PopulationEvent = PopulationSeasonEvent | PopulationMigrationEvent;

type Mutable<T> = { -readonly [Key in keyof T]: T[Key] };
type SettlementRuntime = Omit<Mutable<PopulationSettlementSeed>, "allocations" | "processedEventIds" | "processedCommandIds"> & {
  allocations: LabourAllocation[];
  processedEventIds: Set<string>;
  processedCommandIds: Map<string, ProcessedPopulationCommand>;
};

export interface PopulationResourcePort {
  readonly available: (hostId: string, goodsId: string) => number;
  readonly consume: (hostId: string, goodsId: string, amount: number) => boolean;
  readonly setWorkforce: (hostId: string, workforce: number) => void;
}

export class PopulationDynamics {
  readonly #settlements = new Map<string, SettlementRuntime>();
  readonly #migrations = new Map<string, PopulationMigrationSnapshot>();

  constructor(snapshot: PopulationSnapshot) {
    for (const seed of snapshot.settlements) {
      validateSettlement(seed);
      if (this.#settlements.has(seed.settlementId)) throw new Error(`Duplicate population settlement ${seed.settlementId}.`);
      this.#settlements.set(seed.settlementId, { ...structuredClone(seed), allocations: Array.from(structuredClone(seed.allocations)), processedEventIds: new Set(seed.processedEventIds), processedCommandIds: new Map(seed.processedCommandIds.map((item) => [item.commandId, structuredClone(item)])) });
    }
    for (const migration of snapshot.migrations) {
      if (this.#migrations.has(migration.migrationId)) throw new Error(`Duplicate migration ${migration.migrationId}.`);
      this.#migrations.set(migration.migrationId, structuredClone(migration));
    }
  }

  initialIntents(elapsedDays: number): readonly ScheduledEventIntent[] {
    const intents: ScheduledEventIntent[] = [];
    for (const settlement of this.#settlements.values()) if (settlement.pendingSeasonEventId === null) intents.push(this.#seasonIntent(settlement, elapsedDays + 90));
    return intents;
  }

  handleSeason(intent: ScheduledEventIntent, elapsedDays: number, port: PopulationResourcePort): { readonly event: PopulationSeasonEvent; readonly nextIntent: ScheduledEventIntent | null } {
    const settlement = this.#requireSettlement(intent.targetEntityId);
    if (settlement.processedEventIds.has(intent.eventId) || settlement.pendingSeasonEventId !== intent.eventId) return { event: ignoredSeason(intent, elapsedDays, settlement), nextIntent: null };
    settlement.processedEventIds.add(intent.eventId); settlement.pendingSeasonEventId = null;
    const date = calendarAt(elapsedDays), before = total(settlement.cohorts);
    const foodRequired = Math.max(0, Math.ceil(before * settlement.policy.foodUnitsPerPersonPerSeasonPermille * settlement.policy.rationingPermille / 1_000_000));
    const availableBeyondReserve = Math.max(0, port.available(settlement.hostId, settlement.policy.foodGoodsId) - settlement.policy.reserveTargetUnits);
    const foodConsumed = Math.min(foodRequired, availableBeyondReserve);
    if (foodConsumed > 0 && !port.consume(settlement.hostId, settlement.policy.foodGoodsId, foodConsumed)) throw new Error("Validated population food consumption failed.");
    const shortage = foodConsumed < foodRequired;
    settlement.nutritionPermille = clampPermille(settlement.nutritionPermille + (shortage ? -settlement.policy.nutritionLossOnShortagePermille : settlement.policy.nutritionRecoveryPermille));
    const malnourished = settlement.nutritionPermille < 700;
    settlement.healthPermille = clampPermille(settlement.healthPermille + (malnourished ? -settlement.policy.healthLossFromMalnutritionPermille : settlement.policy.healthRecoveryPermille));
    advanceDisease(settlement, date.season, date.year);
    const annual = date.season === "winter";
    const births = annual ? Math.floor(settlement.cohorts.workingAdults * settlement.policy.baselineBirthsPerAdultYearPermille / 1000) : 0;
    const mortalityPermille = annual ? settlement.policy.baselineDeathsPerYearPermille + (malnourished ? settlement.policy.malnutritionDeathsPerYearPermille : 0) : 0;
    const deaths = annual ? Math.min(before, Math.floor(before * mortalityPermille / 1000)) : 0;
    const matured = annual ? Math.min(settlement.cohorts.children, Math.floor(settlement.cohorts.children * settlement.policy.maturationPerYearPermille / 1000)) : 0;
    const aged = annual ? Math.min(settlement.cohorts.workingAdults, Math.floor(settlement.cohorts.workingAdults * settlement.policy.agingPerYearPermille / 1000)) : 0;
    settlement.cohorts = applyDemography(settlement.cohorts, births, deaths, matured, aged);
    const labourAvailable = calculateLabour(settlement, date.season);
    settlement.allocations = trimAllocations(settlement.allocations, labourAvailable, settlement.policy.labourPriority);
    port.setWorkforce(settlement.hostId, labourAvailable);
    const unrestDelta = shortage ? settlement.policy.unrestDeltaOnFoodShortage : 0;
    settlement.unrest = Math.max(0, settlement.unrest + unrestDelta);
    const nextIntent = this.#seasonIntent(settlement, elapsedDays + 90);
    return { event: { eventType: "PopulationSeasonAdvanced", scheduledEventId: intent.eventId, elapsedDays, settlementId: settlement.settlementId, season: date.season, year: date.year, populationBefore: before, populationAfter: total(settlement.cohorts), foodRequired, foodConsumed, births, deaths, matured, aged, diseaseState: settlement.diseaseState, healthPermille: settlement.healthPermille, nutritionPermille: settlement.nutritionPermille, labourAvailable, unrestDelta }, nextIntent };
  }

  handleMigrationArrival(intent: ScheduledEventIntent, elapsedDays: number): PopulationMigrationEvent {
    const payload = readMigrationPayload(intent.payload), migration = this.#migrations.get(payload.migrationId);
    if (migration === undefined || migration.status === "arrived") return { eventType: "PopulationEventIgnored", scheduledEventId: intent.eventId, elapsedDays, migrationId: payload.migrationId, originSettlementId: migration?.originSettlementId ?? "unknown", destinationSettlementId: migration?.destinationSettlementId ?? "unknown", people: migration?.people ?? 0, reason: "duplicate" };
    const destination = this.#requireSettlement(migration.destinationSettlementId);
    destination.cohorts = { ...destination.cohorts, workingAdults: destination.cohorts.workingAdults + migration.people };
    this.#migrations.set(migration.migrationId, { ...migration, status: "arrived" });
    return { eventType: "PopulationMigrationArrived", scheduledEventId: intent.eventId, elapsedDays, migrationId: migration.migrationId, originSettlementId: migration.originSettlementId, destinationSettlementId: migration.destinationSettlementId, people: migration.people, reason: "arrived" };
  }

  allocate(command: AllocateLabourCommand, elapsedDays: number, authorized: boolean): PopulationCommandResult {
    const settlement = this.#requireSettlement(command.settlementId), replay = replayCommand(settlement, command);
    if (replay !== null) return replay;
    if (!authorized) return recordCommand(settlement, command, failure("NOT_AUTHORIZED", "Actor is not authorized to allocate settlement labour."));
    try { validateAllocations(command.allocations); } catch (error) { return recordCommand(settlement, command, failure("INVALID_COMMAND", error instanceof Error ? error.message : String(error))); }
    const available = calculateLabour(settlement, calendarAt(elapsedDays).season);
    if (command.allocations.reduce((sum, item) => sum + item.workers, 0) > available) return recordCommand(settlement, command, failure("INSUFFICIENT_LABOUR", `Requested labour exceeds available ${available}.`));
    settlement.allocations = Array.from(structuredClone(command.allocations));
    return recordCommand(settlement, command, { accepted: true, idempotentReplay: false, scheduledEventId: null });
  }

  startMigration(command: StartMigrationCommand, elapsedDays: number, authorized: boolean): { readonly result: PopulationCommandResult; readonly intent: ScheduledEventIntent | null; readonly event: PopulationMigrationEvent | null } {
    const origin = this.#requireSettlement(command.originSettlementId), replay = replayCommand(origin, command);
    if (replay !== null) return { result: replay, intent: null, event: null };
    if (!authorized) return { result: recordCommand(origin, command, failure("NOT_AUTHORIZED", "Actor is not authorized to start migration.")), intent: null, event: null };
    if (!Number.isSafeInteger(command.people) || command.people <= 0 || !Number.isFinite(command.travelDays) || command.travelDays <= 0 || command.destinationSettlementId === command.originSettlementId) return { result: recordCommand(origin, command, failure("INVALID_COMMAND", "Migration requires positive people/travel time and another destination.")), intent: null, event: null };
    this.#requireSettlement(command.destinationSettlementId);
    if (this.#migrations.has(command.migrationId)) return { result: recordCommand(origin, command, failure("DUPLICATE_ACTIVE_MIGRATION", `Migration ${command.migrationId} already exists.`)), intent: null, event: null };
    if (origin.cohorts.workingAdults < command.people) return { result: recordCommand(origin, command, failure("INSUFFICIENT_PEOPLE", "Origin lacks working-age migrants.")), intent: null, event: null };
    const eventId = `migration:${command.migrationId}:arrival`;
    origin.cohorts = { ...origin.cohorts, workingAdults: origin.cohorts.workingAdults - command.people };
    this.#migrations.set(command.migrationId, { migrationId: command.migrationId, originSettlementId: command.originSettlementId, destinationSettlementId: command.destinationSettlementId, routeId: command.routeId, people: command.people, status: "traveling", arrivalEventId: eventId });
    const result = recordCommand(origin, command, { accepted: true, idempotentReplay: false, scheduledEventId: eventId });
    return { result, intent: { eventId, kind: POPULATION_MIGRATION_ARRIVAL_DUE, dueElapsedDays: elapsedDays + command.travelDays, targetComponent: POPULATION_COMPONENT, targetEntityId: command.destinationSettlementId, payload: { migrationId: command.migrationId } }, event: { eventType: "PopulationMigrationStarted", scheduledEventId: eventId, elapsedDays, migrationId: command.migrationId, originSettlementId: command.originSettlementId, destinationSettlementId: command.destinationSettlementId, people: command.people, reason: "started" } };
  }

  allocationFor(targetEntityId: string): number { let result = 0; for (const settlement of this.#settlements.values()) for (const allocation of settlement.allocations) if (allocation.targetEntityId === targetEntityId) result += allocation.workers; return result; }
  recordMigrationFailure(command: StartMigrationCommand, result: Extract<PopulationCommandResult, { accepted: false }>): PopulationCommandResult { return recordCommand(this.#requireSettlement(command.originSettlementId), command, result); }
  settlement(settlementId: string): PopulationSettlementSeed { return this.snapshot().settlements.find((item) => item.settlementId === settlementId)!; }
  snapshot(): PopulationSnapshot { return { settlements: [...this.#settlements.values()].map((item) => ({ ...structuredClone(item), allocations: structuredClone(item.allocations), processedEventIds: [...item.processedEventIds], processedCommandIds: [...item.processedCommandIds.values()].map((entry) => structuredClone(entry)) })), migrations: [...this.#migrations.values()].map((item) => structuredClone(item)) }; }
  restore(snapshot: PopulationSnapshot): void { const restored = new PopulationDynamics(snapshot); this.#settlements.clear(); this.#migrations.clear(); for (const [id, item] of restored.#settlements) this.#settlements.set(id, item); for (const [id, item] of restored.#migrations) this.#migrations.set(id, item); }
  #seasonIntent(settlement: SettlementRuntime, dueElapsedDays: number): ScheduledEventIntent<PopulationSeasonPayload> { const ordinal = settlement.nextEventOrdinal; const eventId = `${settlement.settlementId}:population:${ordinal}`; settlement.nextEventOrdinal += 1; settlement.pendingSeasonEventId = eventId; return { eventId, kind: POPULATION_SEASON_DUE, dueElapsedDays, targetComponent: POPULATION_COMPONENT, targetEntityId: settlement.settlementId, payload: { ordinal } }; }
  #requireSettlement(id: string): SettlementRuntime { const result = this.#settlements.get(id); if (result === undefined) throw new Error(`Unknown population settlement ${id}.`); return result; }
}

export interface GovernorPopulationPolicy { readonly seasonalTargets: Readonly<Record<SeasonId, readonly { readonly targetEntityId: string; readonly sector: LabourSector; readonly workers: number }[]>> }
export class GovernorPopulationController {
  decide(memory: WorldMemoryOwnerView, settlementId: string, elapsedDays: number, policy: GovernorPopulationPolicy): AllocateLabourCommand | null {
    const observation = [...memory.entries].reverse().find((entry) => entry.kind === "population_observation" && entry.freshness === "fresh" && entry.payload.settlementId === settlementId);
    if (observation === undefined) return null;
    const targets = policy.seasonalTargets[calendarAt(elapsedDays).season];
    return { commandId: `population:${memory.ownerId}:${settlementId}:${observation.entryId}`, issuerActorId: memory.ownerId, settlementId, allocations: targets.map((item, index) => ({ allocationId: `${settlementId}:${index}`, ...item })) };
  }
}

export interface PopulationMigrationPolicy {
  readonly originSettlementId: string;
  readonly destinationSettlementId: string;
  readonly routeId: string;
  readonly travelDays: number;
  readonly people: number;
  readonly originNutritionThresholdPermille: number;
  readonly destinationProspectMarginPermille: number;
  readonly maximumRememberedRouteRiskPermille: number;
}

export class PopulationMigrationController {
  decide(memory: WorldMemoryOwnerView, elapsedDays: number, policy: PopulationMigrationPolicy): StartMigrationCommand | null {
    const observations = memory.entries.filter((entry) => entry.kind === "population_observation" && entry.freshness === "fresh");
    const origin = [...observations].reverse().find((entry) => entry.payload.settlementId === policy.originSettlementId);
    const destination = [...observations].reverse().find((entry) => entry.payload.settlementId === policy.destinationSettlementId);
    if (origin === undefined || destination === undefined) return null;
    const originNutrition = origin.payload.nutritionPermille, destinationNutrition = destination.payload.nutritionPermille;
    if (typeof originNutrition !== "number" || typeof destinationNutrition !== "number" || originNutrition >= policy.originNutritionThresholdPermille || destinationNutrition < originNutrition + policy.destinationProspectMarginPermille) return null;
    const routeRisk = [...memory.entries].reverse().find((entry) => entry.kind === "route_security_observation" && entry.payload.routeId === policy.routeId && entry.freshness === "fresh")?.payload.riskPermille;
    if (typeof routeRisk === "number" && routeRisk > policy.maximumRememberedRouteRiskPermille) return null;
    return { commandId: `migration:${memory.ownerId}:${origin.entryId}:${destination.entryId}:${Math.floor(elapsedDays)}`, issuerActorId: memory.ownerId, migrationId: `migration:${policy.originSettlementId}:${policy.destinationSettlementId}:${origin.entryId}`, originSettlementId: policy.originSettlementId, destinationSettlementId: policy.destinationSettlementId, routeId: policy.routeId, people: policy.people, travelDays: policy.travelDays };
  }
}

function advanceDisease(settlement: SettlementRuntime, season: SeasonId, year: number): void { if (settlement.diseaseState === "active") { settlement.diseaseSeasonsRemaining -= 1; settlement.healthPermille = clampPermille(settlement.healthPermille - settlement.policy.diseaseHealthLossPermille); if (settlement.diseaseSeasonsRemaining <= 0) settlement.diseaseState = "recovering"; return; } if (settlement.diseaseState === "recovering") { settlement.diseaseState = "none"; return; } const roll = stableRoll(`${settlement.settlementId}:${year}:${season}`); if (roll < settlement.policy.seasonalDiseaseRiskPermille[season]) { settlement.diseaseState = "active"; settlement.diseaseSeasonsRemaining = settlement.policy.diseaseDurationSeasons; settlement.healthPermille = clampPermille(settlement.healthPermille - settlement.policy.diseaseHealthLossPermille); } }
function stableRoll(value: string): number { let hash = 2166136261; for (let index = 0; index < value.length; index += 1) { hash ^= value.charCodeAt(index); hash = Math.imul(hash, 16777619); } return (hash >>> 0) % 1000; }
function calculateLabour(settlement: SettlementRuntime, season: SeasonId): number { return Math.floor(settlement.cohorts.workingAdults * settlement.healthPermille * settlement.nutritionPermille * settlement.policy.seasonalLabourAvailabilityPermille[season] / 1_000_000_000); }
function trimAllocations(items: readonly LabourAllocation[], available: number, priorities: readonly LabourSector[]): LabourAllocation[] { let remaining = available; return [...items].sort((a, b) => priorities.indexOf(a.sector) - priorities.indexOf(b.sector) || (a.allocationId < b.allocationId ? -1 : a.allocationId > b.allocationId ? 1 : 0)).flatMap((item) => { const workers = Math.min(item.workers, remaining); remaining -= workers; return workers <= 0 ? [] : [{ ...item, workers }]; }); }
function applyDemography(cohorts: PopulationAgeCohorts, births: number, deaths: number, matured: number, aged: number): PopulationAgeCohorts { let remainingDeaths = deaths; const elderDeaths = Math.min(cohorts.elders, remainingDeaths); remainingDeaths -= elderDeaths; const childDeaths = Math.min(cohorts.children - matured, remainingDeaths); remainingDeaths -= childDeaths; const adultDeaths = Math.min(cohorts.workingAdults - aged + matured, remainingDeaths); return { children: Math.max(0, cohorts.children + births - matured - childDeaths), workingAdults: Math.max(0, cohorts.workingAdults + matured - aged - adultDeaths), elders: Math.max(0, cohorts.elders + aged - elderDeaths) }; }
function total(cohorts: PopulationAgeCohorts): number { return cohorts.children + cohorts.workingAdults + cohorts.elders; }
function clampPermille(value: number): number { return Math.max(0, Math.min(1000, Math.round(value))); }
function validateSettlement(seed: PopulationSettlementSeed): void { for (const value of Object.values(seed.cohorts)) if (!Number.isSafeInteger(value) || value < 0) throw new Error(`Invalid population cohort on ${seed.settlementId}.`); for (const value of [seed.healthPermille, seed.nutritionPermille]) if (!Number.isSafeInteger(value) || value < 0 || value > 1000) throw new Error(`Invalid health/nutrition on ${seed.settlementId}.`); validateAllocations(seed.allocations); JSON.stringify(seed); }
function validateAllocations(items: readonly LabourAllocation[]): void { const ids = new Set<string>(); for (const item of items) { if (item.allocationId.length === 0 || item.targetEntityId.length === 0 || ids.has(item.allocationId) || !["agriculture", "industry", "transport", "military", "care"].includes(item.sector) || !Number.isSafeInteger(item.workers) || item.workers < 0) throw new Error("Invalid or duplicate labour allocation."); ids.add(item.allocationId); } }
function canonical(value: unknown): string { if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`; if (value !== null && typeof value === "object") return `{${Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).map(([key, item]) => `${JSON.stringify(key)}:${canonical(item)}`).join(",")}}`; return JSON.stringify(value); }
function replayCommand(settlement: SettlementRuntime, command: PopulationCommand): PopulationCommandResult | null { const known = settlement.processedCommandIds.get(command.commandId); if (known === undefined) return null; return known.fingerprint === canonical(command) ? { ...known.result, idempotentReplay: true } : failure("COMMAND_ID_CONFLICT", `Population command id ${command.commandId} has another payload.`); }
function recordCommand(settlement: SettlementRuntime, command: PopulationCommand, result: PopulationCommandResult): PopulationCommandResult { settlement.processedCommandIds.set(command.commandId, { commandId: command.commandId, fingerprint: canonical(command), result: structuredClone(result) }); return result; }
function failure(errorCode: Extract<PopulationCommandResult, { accepted: false }>["errorCode"], message: string): PopulationCommandResult { return { accepted: false, idempotentReplay: false, errorCode, message }; }
function readMigrationPayload(value: SerializableValue): PopulationMigrationPayload { if (value === null || Array.isArray(value) || typeof value !== "object") throw new Error("Invalid migration payload."); const record = value as Readonly<Record<string, SerializableValue>>; if (typeof record.migrationId !== "string") throw new Error("Invalid migration payload."); return { migrationId: record.migrationId }; }
function ignoredSeason(intent: ScheduledEventIntent, elapsedDays: number, settlement: SettlementRuntime): PopulationSeasonEvent { const date = calendarAt(elapsedDays), population = total(settlement.cohorts); return { eventType: "PopulationSeasonAdvanced", scheduledEventId: intent.eventId, elapsedDays, settlementId: settlement.settlementId, season: date.season, year: date.year, populationBefore: population, populationAfter: population, foodRequired: 0, foodConsumed: 0, births: 0, deaths: 0, matured: 0, aged: 0, diseaseState: settlement.diseaseState, healthPermille: settlement.healthPermille, nutritionPermille: settlement.nutritionPermille, labourAvailable: calculateLabour(settlement, date.season), unrestDelta: 0 }; }
