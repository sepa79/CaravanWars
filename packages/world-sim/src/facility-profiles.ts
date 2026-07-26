import type { ScheduledEventIntent, SerializableValue } from "./world-clock.js";

export const FACILITY_PROFILE_PROCESS_DUE = "FacilityProfileProcessDue";
export const DAYS_PER_YEAR = 360;

export type SeasonId = "winter" | "spring" | "summer" | "autumn";
export type ProcessCadence = "continuous" | "periodic" | "seasonal" | "multistage";
export type EvidenceConfidence = "low" | "medium" | "high";

export interface EvidenceRange {
  readonly minimum: number;
  readonly maximum: number;
  readonly confidence: EvidenceConfidence;
  readonly provenance: string;
}

export interface FacilityProfileLayers {
  readonly biology: Readonly<Record<string, SerializableValue>>;
  readonly technology: Readonly<Record<string, SerializableValue>>;
  readonly managementEnvironment: Readonly<Record<string, SerializableValue>>;
}

export interface ProfileProcessStage {
  readonly stageId: string;
  readonly durationDays: number;
  readonly allowedSeasons: readonly SeasonId[];
  readonly inputs: Readonly<Record<string, number>>;
  readonly outputs: Readonly<Record<string, number>>;
  readonly lossPermille: number;
  readonly workforceRequired?: number;
  readonly nextStageId: string;
}

export interface FacilityProfileProcess {
  readonly processId: string;
  readonly cadence: ProcessCadence;
  readonly initialStageId: string;
  readonly stages: readonly ProfileProcessStage[];
}

export interface FacilityProfileDefinition {
  readonly profileId: string;
  readonly layers: FacilityProfileLayers;
  readonly evidence: Readonly<Record<string, EvidenceRange>>;
  readonly processes: readonly FacilityProfileProcess[];
}

export interface AnimalCohort {
  readonly cohortId: string;
  readonly speciesId: "poultry" | "pig" | "cattle";
  readonly lifeStage: string;
  readonly count: number;
  readonly ageDays: number;
  readonly breedingSharePermille: number;
  readonly milkToYoungSharePermille: number;
  readonly tractionSharePermille: number;
}

export interface FacilityProfileInstanceSeed {
  readonly facilityId: string;
  readonly hostId: string;
  readonly profileId: string;
  readonly visualSkinId: string;
  readonly processStages?: Readonly<Record<string, string>>;
  readonly pendingEventIds?: Readonly<Record<string, string | null>>;
  readonly nextEventOrdinal?: number;
  readonly processedEventIds?: readonly string[];
  readonly animalCohorts?: readonly AnimalCohort[];
  readonly winterFeedRequired?: number;
}

export interface FacilityProfileInstanceSnapshot extends FacilityProfileInstanceSeed {
  readonly processStages: Readonly<Record<string, string>>;
  readonly pendingEventIds?: Readonly<Record<string, string | null>>;
  readonly nextEventOrdinal: number;
  readonly processedEventIds: readonly string[];
  readonly animalCohorts: readonly AnimalCohort[];
  readonly winterFeedRequired: number;
}

export interface FacilityProfileRuntimeSnapshot {
  readonly definitions: readonly FacilityProfileDefinition[];
  readonly instances: readonly FacilityProfileInstanceSnapshot[];
}

export interface ProfileCalendarDate {
  readonly elapsedDay: number;
  readonly year: number;
  readonly dayOfYear: number;
  readonly season: SeasonId;
}

export interface FacilityProfileProcessPayload extends Record<string, SerializableValue> {
  readonly processId: string;
  readonly stageId: string;
}

export interface FacilityProfileProcessEvent {
  readonly eventType: "FacilityProfileProcessCompleted" | "FacilityProfileProcessBlocked" | "FacilityProfileProcessSkipped";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly facilityId: string;
  readonly profileId: string;
  readonly processId: string;
  readonly stageId: string;
  readonly season: SeasonId;
  readonly consumed: Readonly<Record<string, number>>;
  readonly produced: Readonly<Record<string, number>>;
  readonly losses: Readonly<Record<string, number>>;
  readonly reason: "completed" | "missing_inputs" | "insufficient_workforce" | "output_storage_full" | "outside_season" | "duplicate" | "stale";
}

interface RuntimeInstance {
  readonly facilityId: string;
  readonly hostId: string;
  readonly profileId: string;
  readonly visualSkinId: string;
  readonly processStages: Map<string, string>;
  readonly pendingEventIds: Map<string, string | null>;
  nextEventOrdinal: number;
  readonly processedEventIds: Set<string>;
  animalCohorts: AnimalCohort[];
  readonly winterFeedRequired: number;
}

export interface ProfileMutationPort {
  readonly available: (hostId: string, goodsId: string) => number;
  readonly workforceAvailable: (facilityId: string) => number;
  readonly canApply: (hostId: string, consumed: Readonly<Record<string, number>>, produced: Readonly<Record<string, number>>) => boolean;
  readonly apply: (hostId: string, consumed: Readonly<Record<string, number>>, produced: Readonly<Record<string, number>>) => void;
}

export class FacilityProfileRuntime {
  readonly #definitions = new Map<string, FacilityProfileDefinition>();
  readonly #instances = new Map<string, RuntimeInstance>();

  constructor(snapshot: FacilityProfileRuntimeSnapshot) {
    for (const definition of snapshot.definitions) {
      validateDefinition(definition);
      if (this.#definitions.has(definition.profileId)) throw new Error(`Duplicate profile ${definition.profileId}.`);
      this.#definitions.set(definition.profileId, structuredClone(definition));
    }
    for (const seed of snapshot.instances) {
      requireId(seed.facilityId, "facilityId"); requireId(seed.hostId, "hostId");
      if (!Number.isSafeInteger(seed.nextEventOrdinal) || seed.nextEventOrdinal < 0) throw new Error(`Invalid profile event ordinal for ${seed.facilityId}.`);
      if (new Set(seed.processedEventIds).size !== seed.processedEventIds.length) throw new Error(`Duplicate processed profile event id on ${seed.facilityId}.`);
      for (const id of seed.processedEventIds) requireId(id, "processed profile event id");
      for (const value of Object.values(seed.pendingEventIds ?? {})) if (value !== null) requireId(value, "pending profile event id");
      for (const cohort of seed.animalCohorts) validateAnimalCohort(cohort);
      if (this.#instances.has(seed.facilityId)) throw new Error(`Duplicate profiled Facility ${seed.facilityId}.`);
      const definition = this.#requireDefinition(seed.profileId);
      const stages = new Map(Object.entries(seed.processStages));
      const pending = new Map(Object.entries(seed.pendingEventIds ?? {}));
      for (const process of definition.processes) {
        const stageId = stages.get(process.processId) ?? process.initialStageId;
        requireStage(process, stageId);
        stages.set(process.processId, stageId);
        if (!pending.has(process.processId)) pending.set(process.processId, null);
      }
      this.#instances.set(seed.facilityId, {
        facilityId: seed.facilityId, hostId: seed.hostId, profileId: seed.profileId,
        visualSkinId: requireId(seed.visualSkinId, "visualSkinId"), processStages: stages,
        pendingEventIds: pending,
        nextEventOrdinal: seed.nextEventOrdinal, processedEventIds: new Set(seed.processedEventIds),
        animalCohorts: Array.from(structuredClone(seed.animalCohorts)), winterFeedRequired: nonNegative(seed.winterFeedRequired, "winter feed"),
      });
    }
  }

  initialIntents(elapsedDays: number): readonly ScheduledEventIntent[] {
    return [...this.#instances.values()].flatMap((instance) => {
      const definition = this.#requireDefinition(instance.profileId);
      return definition.processes.filter((process) => instance.pendingEventIds.get(process.processId) === null)
        .map((process) => this.#intent(instance, process, elapsedDays + requireStage(process, instance.processStages.get(process.processId)!).durationDays));
    });
  }

  handle(intent: ScheduledEventIntent, elapsedDays: number, port: ProfileMutationPort): { readonly event: FacilityProfileProcessEvent; readonly nextIntent: ScheduledEventIntent | null } {
    if (intent.kind !== FACILITY_PROFILE_PROCESS_DUE || intent.targetComponent !== "facilities") throw new Error(`Not a profile process intent: ${intent.eventId}.`);
    const instance = this.#requireInstance(intent.targetEntityId);
    const payload = readPayload(intent.payload);
    const process = this.#requireDefinition(instance.profileId).processes.find((item) => item.processId === payload.processId);
    if (process === undefined) throw new Error(`Unknown process ${payload.processId}.`);
    const stage = requireStage(process, payload.stageId);
    const calendar = calendarAt(elapsedDays);
    if (instance.processedEventIds.has(intent.eventId)) {
      return { event: makeEvent(intent, elapsedDays, instance, process, stage, calendar.season, {}, {}, {}, "duplicate"), nextIntent: null };
    }
    instance.processedEventIds.add(intent.eventId);
    if (instance.pendingEventIds.get(process.processId) !== intent.eventId) {
      return { event: makeEvent(intent, elapsedDays, instance, process, stage, calendar.season, {}, {}, {}, "stale"), nextIntent: null };
    }
    instance.pendingEventIds.set(process.processId, null);
    if (!stage.allowedSeasons.includes(calendar.season)) {
      return { event: makeEvent(intent, elapsedDays, instance, process, stage, calendar.season, {}, {}, {}, "outside_season"), nextIntent: this.#intent(instance, process, elapsedDays + stage.durationDays) };
    }
    if (port.workforceAvailable(instance.facilityId) < (stage.workforceRequired ?? 0)) {
      return { event: makeEvent(intent, elapsedDays, instance, process, stage, calendar.season, {}, {}, {}, "insufficient_workforce"), nextIntent: this.#intent(instance, process, elapsedDays + stage.durationDays) };
    }
    const missing = Object.entries(stage.inputs).some(([goodsId, amount]) => port.available(instance.hostId, goodsId) < amount);
    const gross = stage.outputs;
    const produced = Object.fromEntries(Object.entries(gross).map(([id, amount]) => [id, Math.floor(amount * (1000 - stage.lossPermille) / 1000)]));
    const lossEntries: [string, number][] = Object.entries(gross)
      .map(([id, amount]): [string, number] => [id, amount - (produced[id] ?? 0)])
      .filter((entry) => entry[1] > 0);
    const losses = Object.fromEntries(lossEntries);
    if (missing) {
      return { event: makeEvent(intent, elapsedDays, instance, process, stage, calendar.season, {}, {}, {}, "missing_inputs"), nextIntent: this.#intent(instance, process, elapsedDays + stage.durationDays) };
    }
    if (!port.canApply(instance.hostId, stage.inputs, produced)) {
      return { event: makeEvent(intent, elapsedDays, instance, process, stage, calendar.season, {}, {}, {}, "output_storage_full"), nextIntent: this.#intent(instance, process, elapsedDays + stage.durationDays) };
    }
    port.apply(instance.hostId, stage.inputs, produced);
    instance.processStages.set(process.processId, stage.nextStageId);
    instance.animalCohorts = instance.animalCohorts.map((cohort) => ({ ...cohort, ageDays: cohort.ageDays + stage.durationDays }));
    const nextStage = requireStage(process, stage.nextStageId);
    return { event: makeEvent(intent, elapsedDays, instance, process, stage, calendar.season, stage.inputs, produced, losses, "completed"), nextIntent: this.#intent(instance, process, elapsedDays + nextStage.durationDays) };
  }

  snapshot(): FacilityProfileRuntimeSnapshot {
    return {
      definitions: [...this.#definitions.values()].map((item) => structuredClone(item)),
      instances: [...this.#instances.values()].map((item) => ({
        facilityId: item.facilityId, hostId: item.hostId, profileId: item.profileId,
        visualSkinId: item.visualSkinId, processStages: Object.fromEntries(item.processStages),
        pendingEventIds: Object.fromEntries(item.pendingEventIds),
        nextEventOrdinal: item.nextEventOrdinal, processedEventIds: [...item.processedEventIds],
        animalCohorts: structuredClone(item.animalCohorts), winterFeedRequired: item.winterFeedRequired,
      })),
    };
  }

  #intent(instance: RuntimeInstance, process: FacilityProfileProcess, dueElapsedDays: number): ScheduledEventIntent<FacilityProfileProcessPayload> {
    const stageId = instance.processStages.get(process.processId)!;
    const eventId = `${instance.facilityId}:profile:${process.processId}:${instance.nextEventOrdinal}`;
    instance.nextEventOrdinal += 1;
    instance.pendingEventIds.set(process.processId, eventId);
    return { eventId, kind: FACILITY_PROFILE_PROCESS_DUE, dueElapsedDays, targetComponent: "facilities", targetEntityId: instance.facilityId, payload: { processId: process.processId, stageId } };
  }
  #requireDefinition(id: string): FacilityProfileDefinition { const value = this.#definitions.get(id); if (value === undefined) throw new Error(`Unknown Facility profile ${id}.`); return value; }
  #requireInstance(id: string): RuntimeInstance { const value = this.#instances.get(id); if (value === undefined) throw new Error(`Unknown profiled Facility ${id}.`); return value; }
}

export function calendarAt(elapsedDays: number): ProfileCalendarDate {
  if (!Number.isFinite(elapsedDays) || elapsedDays < 0) throw new Error("Calendar time must be finite and non-negative.");
  const elapsedDay = Math.floor(elapsedDays);
  const dayOfYear = elapsedDay % DAYS_PER_YEAR;
  const season: SeasonId = dayOfYear < 90 ? "winter" : dayOfYear < 180 ? "spring" : dayOfYear < 270 ? "summer" : "autumn";
  return { elapsedDay, year: Math.floor(elapsedDay / DAYS_PER_YEAR) + 1, dayOfYear, season };
}

function validateDefinition(definition: FacilityProfileDefinition): void {
  requireId(definition.profileId, "profileId");
  if (definition.processes.length === 0) throw new Error(`Profile ${definition.profileId} has no processes.`);
  const ids = new Set<string>();
  for (const process of definition.processes) {
    requireId(process.processId, "processId");
    if (ids.has(process.processId)) throw new Error(`Duplicate process ${process.processId}.`);
    ids.add(process.processId);
    requireStage(process, process.initialStageId);
    if (new Set(process.stages.map((stage) => stage.stageId)).size !== process.stages.length) throw new Error(`Duplicate stage in process ${process.processId}.`);
    for (const stage of process.stages) {
      requireId(stage.stageId, "stageId");
      positive(stage.durationDays, "stage duration");
      if (stage.allowedSeasons.length === 0) throw new Error(`Stage ${stage.stageId} has no season.`);
      if (stage.allowedSeasons.some((season) => !["winter", "spring", "summer", "autumn"].includes(season))) throw new Error(`Stage ${stage.stageId} has an invalid season.`);
      if (!Number.isSafeInteger(stage.lossPermille) || stage.lossPermille < 0 || stage.lossPermille > 999) throw new Error(`Invalid loss on ${stage.stageId}.`);
      if (stage.workforceRequired !== undefined && (!Number.isSafeInteger(stage.workforceRequired) || stage.workforceRequired < 0)) throw new Error(`Invalid workforce on ${stage.stageId}.`);
      requireStage(process, stage.nextStageId);
      validateQuantities(stage.inputs); validateQuantities(stage.outputs);
    }
  }
  for (const range of Object.values(definition.evidence)) {
    nonNegative(range.minimum, "evidence minimum");
    if (range.maximum < range.minimum) throw new Error("Evidence maximum precedes minimum.");
    requireId(range.provenance, "evidence provenance");
  }
  JSON.stringify(definition);
}

function requireStage(process: FacilityProfileProcess, stageId: string): ProfileProcessStage { const stage = process.stages.find((item) => item.stageId === stageId); if (stage === undefined) throw new Error(`Process ${process.processId} has no stage ${stageId}.`); return stage; }
function readPayload(value: SerializableValue): FacilityProfileProcessPayload { if (typeof value !== "object" || value === null || Array.isArray(value)) throw new Error("Invalid profile payload."); const p = value as Record<string, SerializableValue>; if (typeof p.processId !== "string" || typeof p.stageId !== "string") throw new Error("Invalid profile payload."); return { processId: p.processId, stageId: p.stageId }; }
function makeEvent(intent: ScheduledEventIntent, elapsedDays: number, instance: RuntimeInstance, process: FacilityProfileProcess, stage: ProfileProcessStage, season: SeasonId, consumed: Readonly<Record<string, number>>, produced: Readonly<Record<string, number>>, losses: Readonly<Record<string, number>>, reason: FacilityProfileProcessEvent["reason"]): FacilityProfileProcessEvent { return { eventType: reason === "completed" ? "FacilityProfileProcessCompleted" : reason === "duplicate" || reason === "stale" ? "FacilityProfileProcessSkipped" : "FacilityProfileProcessBlocked", scheduledEventId: intent.eventId, elapsedDays, facilityId: instance.facilityId, profileId: instance.profileId, processId: process.processId, stageId: stage.stageId, season, consumed: { ...consumed }, produced: { ...produced }, losses: { ...losses }, reason }; }
function validateQuantities(q: Readonly<Record<string, number>>): void { for (const [id, amount] of Object.entries(q)) { requireId(id, "goods id"); nonNegative(amount, "quantity"); } }
function validateAnimalCohort(cohort: AnimalCohort): void { requireId(cohort.cohortId, "animal cohort id"); if (!["poultry", "pig", "cattle"].includes(cohort.speciesId)) throw new Error(`Invalid animal species ${cohort.speciesId}.`); requireId(cohort.lifeStage, "animal life stage"); nonNegative(cohort.count, "animal count"); nonNegative(cohort.ageDays, "animal age"); const shares = [cohort.breedingSharePermille, cohort.milkToYoungSharePermille, cohort.tractionSharePermille]; for (const share of shares) if (!Number.isSafeInteger(share) || share < 0 || share > 1000) throw new Error("Animal allocation must be an integer from 0 to 1000."); if (shares.reduce((sum, share) => sum + share, 0) > 1000) throw new Error("Competing animal allocations cannot exceed 1000 permille."); }
function requireId(value: string, label: string): string { if (value.trim().length === 0) throw new Error(`${label} must not be empty.`); return value; }
function positive(value: number, label: string): number { if (!Number.isFinite(value) || value <= 0) throw new Error(`${label} must be positive.`); return value; }
function nonNegative(value: number, label: string): number { if (!Number.isFinite(value) || value < 0) throw new Error(`${label} must be non-negative.`); return value; }
