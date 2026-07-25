export type SerializablePrimitive = string | number | boolean | null;
export type SerializableValue =
  | SerializablePrimitive
  | readonly SerializableValue[]
  | { readonly [key: string]: SerializableValue };

export interface ScheduledEventIntent<Payload extends SerializableValue = SerializableValue> {
  readonly eventId: string;
  readonly kind: string;
  readonly dueElapsedDays: number;
  readonly targetComponent: string;
  readonly targetEntityId: string;
  readonly payload: Payload;
}

export interface ScheduledEventRecord {
  readonly intent: ScheduledEventIntent;
  readonly schedulingSequence: number;
  readonly status: "pending" | "cancelled" | "completed" | "failed";
  readonly failureMessage: string | null;
}

export interface WorldClockSnapshot {
  readonly elapsedDays: number;
  readonly nextSchedulingSequence: number;
  readonly scheduledEvents: readonly ScheduledEventRecord[];
}

export interface WorldClockAdvanceOptions {
  readonly maxEvents: number;
  readonly dispatch: (intent: ScheduledEventIntent) => readonly ScheduledEventIntent[] | void;
  readonly onTimeAdvanced?: (fromElapsedDays: number, toElapsedDays: number) => void;
}

export class WorldClockValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "WorldClockValidationError";
  }
}

export class WorldClockAdvanceError extends WorldClockValidationError {
  constructor(days: number) {
    super(`World clock advance must be a finite positive number of days; received ${String(days)}.`);
    this.name = "WorldClockAdvanceError";
  }
}

export class WorldClockEventBudgetExceededError extends Error {
  constructor(maxEvents: number, elapsedDays: number) {
    super(`World clock event budget of ${maxEvents} was exhausted at day ${elapsedDays}.`);
    this.name = "WorldClockEventBudgetExceededError";
  }
}

export class WorldClock {
  readonly #initialSnapshot: WorldClockSnapshot;
  #elapsedDays: number;
  #nextSchedulingSequence: number;
  #records: Map<string, ScheduledEventRecord>;

  constructor(initial: number | WorldClockSnapshot = 0) {
    const snapshot = typeof initial === "number"
      ? { elapsedDays: initial, nextSchedulingSequence: 0, scheduledEvents: [] }
      : copySnapshot(initial);
    validateSnapshot(snapshot);
    this.#initialSnapshot = copySnapshot(snapshot);
    this.#elapsedDays = snapshot.elapsedDays;
    this.#nextSchedulingSequence = snapshot.nextSchedulingSequence;
    this.#records = recordsFromSnapshot(snapshot);
  }

  static fromSnapshot(snapshot: WorldClockSnapshot): WorldClock {
    return new WorldClock(snapshot);
  }

  restore(snapshot: WorldClockSnapshot): void {
    const copy = copySnapshot(snapshot);
    validateSnapshot(copy);
    this.#elapsedDays = copy.elapsedDays;
    this.#nextSchedulingSequence = copy.nextSchedulingSequence;
    this.#records = recordsFromSnapshot(copy);
  }

  get elapsedDays(): number {
    return this.#elapsedDays;
  }

  schedule(intent: ScheduledEventIntent): void {
    this.scheduleAll([intent]);
  }

  scheduleAll(intents: readonly ScheduledEventIntent[]): void {
    const batchIds = new Set<string>();
    for (const intent of intents) {
      validateIntent(intent, this.#elapsedDays);
      if (this.#records.has(intent.eventId) || batchIds.has(intent.eventId)) {
        throw new WorldClockValidationError(`Scheduled event id is already known: ${intent.eventId}.`);
      }
      batchIds.add(intent.eventId);
    }
    if (this.#nextSchedulingSequence + intents.length > Number.MAX_SAFE_INTEGER) {
      throw new WorldClockValidationError("World clock scheduling sequence is exhausted.");
    }
    for (const intent of intents) {
      const record: ScheduledEventRecord = {
        intent: copyIntent(intent),
        schedulingSequence: this.#nextSchedulingSequence,
        status: "pending",
        failureMessage: null,
      };
      this.#nextSchedulingSequence += 1;
      this.#records.set(intent.eventId, record);
    }
  }

  cancel(eventId: string): boolean {
    const record = this.#records.get(eventId);
    if (record === undefined || record.status !== "pending") return false;
    this.#records.set(eventId, { ...record, status: "cancelled", failureMessage: null });
    return true;
  }

  advanceDays(days: number, options?: WorldClockAdvanceOptions): void {
    if (!Number.isFinite(days) || days <= 0) throw new WorldClockAdvanceError(days);
    const targetElapsedDays = this.#elapsedDays + days;
    if (!Number.isFinite(targetElapsedDays)) throw new WorldClockAdvanceError(days);
    if (options === undefined) {
      this.#advanceTimeTo(targetElapsedDays, undefined);
      return;
    }
    if (!Number.isSafeInteger(options.maxEvents) || options.maxEvents <= 0) {
      throw new WorldClockValidationError("World clock maxEvents must be a positive safe integer.");
    }

    let dispatched = 0;
    while (true) {
      const record = this.#nextPendingDueAtOrBefore(targetElapsedDays);
      if (record === undefined) break;
      this.#advanceTimeTo(record.intent.dueElapsedDays, options.onTimeAdvanced);
      if (dispatched >= options.maxEvents) {
        throw new WorldClockEventBudgetExceededError(options.maxEvents, this.#elapsedDays);
      }
      dispatched += 1;
      let followUps: readonly ScheduledEventIntent[];
      try {
        followUps = options.dispatch(copyIntent(record.intent)) ?? [];
      } catch (error: unknown) {
        const failureMessage = error instanceof Error ? error.message : String(error);
        this.#records.set(record.intent.eventId, { ...record, status: "failed", failureMessage });
        throw error;
      }
      this.#records.set(record.intent.eventId, {
        ...record,
        status: "completed",
        failureMessage: null,
      });
      this.scheduleAll(followUps);
    }
    this.#advanceTimeTo(targetElapsedDays, options.onTimeAdvanced);
  }

  reset(): void {
    this.#elapsedDays = this.#initialSnapshot.elapsedDays;
    this.#nextSchedulingSequence = this.#initialSnapshot.nextSchedulingSequence;
    this.#records = recordsFromSnapshot(this.#initialSnapshot);
  }

  snapshot(): WorldClockSnapshot {
    return {
      elapsedDays: this.#elapsedDays,
      nextSchedulingSequence: this.#nextSchedulingSequence,
      scheduledEvents: [...this.#records.values()]
        .sort((left, right) => left.schedulingSequence - right.schedulingSequence)
        .map(copyRecord),
    };
  }

  #advanceTimeTo(
    targetElapsedDays: number,
    onTimeAdvanced: WorldClockAdvanceOptions["onTimeAdvanced"],
  ): void {
    if (targetElapsedDays === this.#elapsedDays) return;
    const previous = this.#elapsedDays;
    this.#elapsedDays = targetElapsedDays;
    onTimeAdvanced?.(previous, targetElapsedDays);
  }

  #nextPendingDueAtOrBefore(targetElapsedDays: number): ScheduledEventRecord | undefined {
    let next: ScheduledEventRecord | undefined;
    for (const record of this.#records.values()) {
      if (record.status !== "pending" || record.intent.dueElapsedDays > targetElapsedDays) continue;
      if (next === undefined
        || record.intent.dueElapsedDays < next.intent.dueElapsedDays
        || (record.intent.dueElapsedDays === next.intent.dueElapsedDays
          && record.schedulingSequence < next.schedulingSequence)) {
        next = record;
      }
    }
    return next;
  }
}

function validateSnapshot(snapshot: WorldClockSnapshot): void {
  if (!Number.isFinite(snapshot.elapsedDays) || snapshot.elapsedDays < 0) {
    throw new WorldClockValidationError("World clock elapsedDays must be finite and non-negative.");
  }
  if (!Number.isSafeInteger(snapshot.nextSchedulingSequence)
    || snapshot.nextSchedulingSequence < 0) {
    throw new WorldClockValidationError(
      "World clock nextSchedulingSequence must be a non-negative safe integer.",
    );
  }
  const eventIds = new Set<string>();
  const sequences = new Set<number>();
  for (const record of snapshot.scheduledEvents) {
    validateIntent(record.intent, 0);
    if (!["pending", "cancelled", "completed", "failed"].includes(record.status)) {
      throw new WorldClockValidationError(`Unknown scheduled event status: ${String(record.status)}.`);
    }
    if (record.failureMessage !== null && typeof record.failureMessage !== "string") {
      throw new WorldClockValidationError("Scheduled event failure message must be a string or null.");
    }
    if (record.status === "pending" && record.intent.dueElapsedDays < snapshot.elapsedDays) {
      throw new WorldClockValidationError("Pending scheduled event cannot be overdue in a snapshot.");
    }
    if ((record.status === "failed") !== (record.failureMessage !== null)) {
      throw new WorldClockValidationError("Only failed scheduled events have a failure message.");
    }
    if (!Number.isSafeInteger(record.schedulingSequence) || record.schedulingSequence < 0) {
      throw new WorldClockValidationError("Scheduling sequence must be non-negative and safe.");
    }
    if (record.schedulingSequence >= snapshot.nextSchedulingSequence) {
      throw new WorldClockValidationError("Scheduling sequence must be below nextSchedulingSequence.");
    }
    if (eventIds.has(record.intent.eventId)) {
      throw new WorldClockValidationError(`Duplicate scheduled event id: ${record.intent.eventId}.`);
    }
    if (sequences.has(record.schedulingSequence)) {
      throw new WorldClockValidationError(
        `Duplicate scheduling sequence: ${record.schedulingSequence}.`,
      );
    }
    eventIds.add(record.intent.eventId);
    sequences.add(record.schedulingSequence);
  }
}

function validateIntent(intent: ScheduledEventIntent, elapsedDays: number): void {
  for (const [label, value] of [
    ["eventId", intent.eventId],
    ["kind", intent.kind],
    ["targetComponent", intent.targetComponent],
    ["targetEntityId", intent.targetEntityId],
  ] as const) {
    if (value.length === 0) throw new WorldClockValidationError(`${label} must not be empty.`);
  }
  if (!Number.isFinite(intent.dueElapsedDays) || intent.dueElapsedDays < elapsedDays) {
    throw new WorldClockValidationError(
      `Scheduled event ${intent.eventId} due time must be finite and not earlier than the clock.`,
    );
  }
  assertSerializable(intent.payload, `Scheduled event ${intent.eventId} payload`, new WeakSet());
}

function assertSerializable(
  value: SerializableValue,
  path: string,
  ancestors: WeakSet<object>,
): void {
  if (value === null || typeof value === "string" || typeof value === "boolean") return;
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new WorldClockValidationError(`${path} must be finite.`);
    return;
  }
  if (Array.isArray(value)) {
    if (ancestors.has(value)) throw new WorldClockValidationError(`${path} must not be cyclic.`);
    ancestors.add(value);
    for (let index = 0; index < value.length; index += 1) {
      assertSerializable(value[index] as SerializableValue, `${path}[${index}]`, ancestors);
    }
    ancestors.delete(value);
    return;
  }
  if (typeof value !== "object") throw new WorldClockValidationError(`${path} is not serializable.`);
  const prototype: object | null = Object.getPrototypeOf(value);
  if (prototype !== Object.prototype && prototype !== null) {
    throw new WorldClockValidationError(`${path} must be a plain serializable object.`);
  }
  if (ancestors.has(value)) throw new WorldClockValidationError(`${path} must not be cyclic.`);
  ancestors.add(value);
  if (Reflect.ownKeys(value).some((key) => typeof key !== "string")) {
    throw new WorldClockValidationError(`${path} must not contain symbol keys.`);
  }
  for (const [key, item] of Object.entries(value)) {
    if (item === undefined) throw new WorldClockValidationError(`${path}.${key} is undefined.`);
    assertSerializable(item, `${path}.${key}`, ancestors);
  }
  ancestors.delete(value);
}

function recordsFromSnapshot(snapshot: WorldClockSnapshot): Map<string, ScheduledEventRecord> {
  return new Map(snapshot.scheduledEvents.map((record) => [record.intent.eventId, copyRecord(record)]));
}

function copySnapshot(snapshot: WorldClockSnapshot): WorldClockSnapshot {
  return {
    elapsedDays: snapshot.elapsedDays,
    nextSchedulingSequence: snapshot.nextSchedulingSequence,
    scheduledEvents: snapshot.scheduledEvents.map(copyRecord),
  };
}

function copyRecord(record: ScheduledEventRecord): ScheduledEventRecord {
  return { ...record, intent: copyIntent(record.intent) };
}

function copyIntent(intent: ScheduledEventIntent): ScheduledEventIntent {
  return structuredClone(intent);
}
