import type { SerializableValue } from "./world-clock.js";

export type WorldMemoryOwnerKind = "actor" | "party" | "location";
export type WorldMemorySourceType = "direct_observation" | "command_result" | "report" | "rumor";
export type WorldMemoryFreshness = "fresh" | "stale";

export interface WorldMemoryProvenance {
  readonly sourceType: WorldMemorySourceType;
  readonly sourceId: string;
  readonly sourceOwnerId: string | null;
  readonly nodeId: string | null;
}

export interface WorldMemoryIngest {
  readonly ingestId: string;
  readonly ownerId: string;
  readonly ownerKind: WorldMemoryOwnerKind;
  readonly kind: string;
  readonly observedAtElapsedDays: number;
  readonly knownAtElapsedDays: number;
  readonly staleAfterDays: number | null;
  readonly provenance: WorldMemoryProvenance;
  readonly payload: Readonly<Record<string, SerializableValue>>;
}

export interface WorldMemoryEntry extends Omit<WorldMemoryIngest, "ingestId"> {
  readonly entryId: string;
  readonly ingestId: string;
  readonly sequence: number;
}

export interface WorldMemoryEntryView extends WorldMemoryEntry {
  readonly ageDays: number;
  readonly freshness: WorldMemoryFreshness;
}

export interface ProcessedWorldMemoryIngest {
  readonly ingestId: string;
  readonly fingerprint: string;
  readonly entryId: string;
}

export interface WorldMemorySnapshot {
  readonly nextSequence: number;
  readonly entries: readonly WorldMemoryEntry[];
  readonly processedIngests: readonly ProcessedWorldMemoryIngest[];
}

export type WorldMemoryIngestResult =
  | { readonly accepted: true; readonly idempotentReplay: boolean; readonly entry: WorldMemoryEntry }
  | {
      readonly accepted: false;
      readonly idempotentReplay: false;
      readonly errorCode: "INGEST_ID_CONFLICT";
      readonly message: string;
    };

export type WorldMemoryBatchIngestResult =
  | { readonly accepted: true; readonly entries: readonly WorldMemoryEntry[] }
  | {
      readonly accepted: false;
      readonly errorCode: "INGEST_ID_CONFLICT";
      readonly message: string;
    };

export interface WorldMemoryOwnerView {
  readonly ownerId: string;
  readonly ownerKind: WorldMemoryOwnerKind;
  readonly asOfElapsedDays: number;
  readonly entries: readonly WorldMemoryEntryView[];
}

export class WorldMemoryValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "WorldMemoryValidationError";
  }
}

export class WorldMemory {
  #nextSequence: number;
  readonly #entries: WorldMemoryEntry[];
  readonly #entriesById: Map<string, WorldMemoryEntry>;
  readonly #processedIngests: Map<string, ProcessedWorldMemoryIngest>;

  constructor(snapshot: WorldMemorySnapshot = { nextSequence: 0, entries: [], processedIngests: [] }) {
    requireNonNegativeSafeInteger(snapshot.nextSequence, "WorldMemory nextSequence");
    this.#nextSequence = snapshot.nextSequence;
    this.#entries = [];
    this.#entriesById = new Map();
    this.#processedIngests = new Map();

    let previousSequence = -1;
    for (const source of snapshot.entries) {
      validateEntry(source);
      if (source.sequence <= previousSequence) {
        throw new WorldMemoryValidationError("WorldMemory entries must use strictly increasing sequence order.");
      }
      if (source.sequence >= snapshot.nextSequence) {
        throw new WorldMemoryValidationError(`Entry ${source.entryId} sequence exceeds nextSequence.`);
      }
      if (this.#entriesById.has(source.entryId)) {
        throw new WorldMemoryValidationError(`Duplicate WorldMemory entry id ${source.entryId}.`);
      }
      const entry = structuredClone(source);
      this.#entries.push(entry);
      this.#entriesById.set(entry.entryId, entry);
      previousSequence = entry.sequence;
    }
    for (const processed of snapshot.processedIngests) {
      requireId(processed.ingestId, "Processed ingest id");
      requireId(processed.fingerprint, "Processed ingest fingerprint");
      requireId(processed.entryId, "Processed ingest entry id");
      if (this.#processedIngests.has(processed.ingestId)) {
        throw new WorldMemoryValidationError(`Duplicate processed ingest ${processed.ingestId}.`);
      }
      const entry = this.#entriesById.get(processed.entryId);
      if (entry === undefined || entry.ingestId !== processed.ingestId) {
        throw new WorldMemoryValidationError(`Processed ingest ${processed.ingestId} has no matching entry.`);
      }
      if (fingerprint(toIngest(entry)) !== processed.fingerprint) {
        throw new WorldMemoryValidationError(`Processed ingest ${processed.ingestId} fingerprint is invalid.`);
      }
      this.#processedIngests.set(processed.ingestId, { ...processed });
    }
    if (this.#processedIngests.size !== this.#entries.length) {
      throw new WorldMemoryValidationError("Every WorldMemory entry must have one processed ingest record.");
    }
  }

  ingest(input: WorldMemoryIngest): WorldMemoryIngestResult {
    validateIngest(input);
    const inputFingerprint = fingerprint(input);
    const processed = this.#processedIngests.get(input.ingestId);
    if (processed !== undefined) {
      if (processed.fingerprint !== inputFingerprint) {
        return {
          accepted: false,
          idempotentReplay: false,
          errorCode: "INGEST_ID_CONFLICT",
          message: `WorldMemory ingest id ${input.ingestId} has another payload.`,
        };
      }
      return {
        accepted: true,
        idempotentReplay: true,
        entry: structuredClone(this.#entriesById.get(processed.entryId)!),
      };
    }
    if (this.#nextSequence === Number.MAX_SAFE_INTEGER) {
      throw new WorldMemoryValidationError("WorldMemory entry sequence is exhausted.");
    }
    const sequence = this.#nextSequence;
    const entry: WorldMemoryEntry = {
      ...structuredClone(input),
      entryId: `memory:${sequence}`,
      sequence,
    };
    this.#nextSequence += 1;
    this.#entries.push(entry);
    this.#entriesById.set(entry.entryId, entry);
    this.#processedIngests.set(input.ingestId, {
      ingestId: input.ingestId,
      fingerprint: inputFingerprint,
      entryId: entry.entryId,
    });
    return { accepted: true, idempotentReplay: false, entry: structuredClone(entry) };
  }

  ingestAll(inputs: readonly WorldMemoryIngest[]): WorldMemoryBatchIngestResult {
    const batch = new Map<string, string>();
    let newEntryCount = 0;
    for (const input of inputs) {
      validateIngest(input);
      const inputFingerprint = fingerprint(input);
      const batchFingerprint = batch.get(input.ingestId);
      if (batchFingerprint !== undefined && batchFingerprint !== inputFingerprint) {
        return { accepted: false, errorCode: "INGEST_ID_CONFLICT", message: `Batch ingest id ${input.ingestId} has multiple payloads.` };
      }
      if (batchFingerprint === undefined) batch.set(input.ingestId, inputFingerprint);
      const processed = this.#processedIngests.get(input.ingestId);
      if (processed !== undefined && processed.fingerprint !== inputFingerprint) {
        return { accepted: false, errorCode: "INGEST_ID_CONFLICT", message: `WorldMemory ingest id ${input.ingestId} has another payload.` };
      }
      if (processed === undefined && batchFingerprint === undefined) newEntryCount += 1;
    }
    if (this.#nextSequence + newEntryCount > Number.MAX_SAFE_INTEGER) {
      throw new WorldMemoryValidationError("WorldMemory entry sequence is exhausted.");
    }
    const entries: WorldMemoryEntry[] = [];
    for (const input of inputs) {
      const result = this.ingest(input);
      if (!result.accepted) throw new WorldMemoryValidationError("Validated WorldMemory batch changed during synchronous ingest.");
      entries.push(result.entry);
    }
    return { accepted: true, entries };
  }

  ownerView(ownerId: string, ownerKind: WorldMemoryOwnerKind, asOfElapsedDays: number): WorldMemoryOwnerView {
    requireId(ownerId, "WorldMemory owner id");
    if (!(["actor", "party", "location"] as const).includes(ownerKind)) {
      throw new WorldMemoryValidationError(`Unknown WorldMemory owner kind ${String(ownerKind)}.`);
    }
    requireFiniteNonNegative(asOfElapsedDays, "WorldMemory view time");
    return {
      ownerId,
      ownerKind,
      asOfElapsedDays,
      entries: this.#entries
        .filter((entry) => entry.ownerId === ownerId
          && entry.ownerKind === ownerKind
          && entry.knownAtElapsedDays <= asOfElapsedDays)
        .map((entry) => {
          const ageDays = asOfElapsedDays - entry.observedAtElapsedDays;
          return {
            ...structuredClone(entry),
            ageDays,
            freshness: entry.staleAfterDays !== null && ageDays >= entry.staleAfterDays
              ? "stale"
              : "fresh",
          };
        }),
    };
  }

  snapshot(): WorldMemorySnapshot {
    return {
      nextSequence: this.#nextSequence,
      entries: structuredClone(this.#entries),
      processedIngests: [...this.#processedIngests.values()].map((item) => ({ ...item })),
    };
  }
}

function validateEntry(entry: WorldMemoryEntry): void {
  validateIngest(entry);
  requireId(entry.entryId, "WorldMemory entry id");
  requireNonNegativeSafeInteger(entry.sequence, `Entry ${entry.entryId} sequence`);
  if (entry.entryId !== `memory:${entry.sequence}`) {
    throw new WorldMemoryValidationError(`Entry ${entry.entryId} is not derived from its sequence.`);
  }
}

function validateIngest(input: WorldMemoryIngest): void {
  requireId(input.ingestId, "WorldMemory ingest id");
  requireId(input.ownerId, "WorldMemory owner id");
  if (!(["actor", "party", "location"] as const).includes(input.ownerKind)) {
    throw new WorldMemoryValidationError(`Unknown WorldMemory owner kind ${String(input.ownerKind)}.`);
  }
  requireId(input.kind, "WorldMemory kind");
  requireFiniteNonNegative(input.observedAtElapsedDays, "WorldMemory observed time");
  requireFiniteNonNegative(input.knownAtElapsedDays, "WorldMemory known time");
  if (input.knownAtElapsedDays < input.observedAtElapsedDays) {
    throw new WorldMemoryValidationError("WorldMemory known time cannot precede observed time.");
  }
  if (input.staleAfterDays !== null && (!Number.isFinite(input.staleAfterDays) || input.staleAfterDays <= 0)) {
    throw new WorldMemoryValidationError("WorldMemory staleAfterDays must be null or finite and positive.");
  }
  if (!(["direct_observation", "command_result", "report", "rumor"] as const)
    .includes(input.provenance.sourceType)) {
    throw new WorldMemoryValidationError(`Unknown provenance source ${String(input.provenance.sourceType)}.`);
  }
  requireId(input.provenance.sourceId, "WorldMemory provenance source id");
  if (input.provenance.sourceOwnerId !== null) {
    requireId(input.provenance.sourceOwnerId, "WorldMemory provenance source owner id");
  }
  if (input.provenance.nodeId !== null) requireId(input.provenance.nodeId, "WorldMemory provenance node id");
  validateSerializable(input.payload, "WorldMemory payload");
}

function toIngest(entry: WorldMemoryEntry): WorldMemoryIngest {
  const { entryId: _entryId, sequence: _sequence, ...input } = entry;
  return input;
}

function fingerprint(value: WorldMemoryIngest): string {
  return JSON.stringify(canonicalize(value));
}

function canonicalize(value: unknown): SerializableValue {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value !== null && typeof value === "object") {
    const record = value as Record<string, unknown>;
    return Object.fromEntries(Object.keys(record).sort().map((key) => [key, canonicalize(record[key])]));
  }
  return value as string | number | boolean | null;
}

function validateSerializable(value: unknown, label: string): asserts value is SerializableValue {
  if (value === null || typeof value === "string" || typeof value === "boolean") return;
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new WorldMemoryValidationError(`${label} contains a non-finite number.`);
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) validateSerializable(item, label);
    return;
  }
  if (typeof value !== "object") throw new WorldMemoryValidationError(`${label} is not JSON serializable.`);
  const prototype = Object.getPrototypeOf(value);
  if (prototype !== Object.prototype && prototype !== null) {
    throw new WorldMemoryValidationError(`${label} must contain plain JSON objects.`);
  }
  for (const item of Object.values(value as Record<string, unknown>)) validateSerializable(item, label);
}

function requireId(value: string, label: string): void {
  if (typeof value !== "string" || value.length === 0) throw new WorldMemoryValidationError(`${label} must not be empty.`);
}

function requireFiniteNonNegative(value: number, label: string): void {
  if (!Number.isFinite(value) || value < 0) throw new WorldMemoryValidationError(`${label} must be finite and non-negative.`);
}

function requireNonNegativeSafeInteger(value: number, label: string): void {
  if (!Number.isSafeInteger(value) || value < 0) throw new WorldMemoryValidationError(`${label} must be a non-negative safe integer.`);
}
