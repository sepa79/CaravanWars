export type LogisticsTaskStatus = "created" | "accepted" | "in_progress" | "completed" | "failed" | "abandoned";

export interface LogisticsTaskIdentity {
  readonly taskId: string;
  readonly ownerActorId: string;
  readonly executorPartyId: string;
  readonly destinationEntityId: string;
  readonly destinationNodeId: string;
  readonly goodsId: string;
  readonly amount: number;
}

export interface LogisticsTaskTransition {
  readonly transitionId: string;
  readonly status: LogisticsTaskStatus;
  readonly elapsedDays: number;
  readonly reason: string;
}

export interface LogisticsTaskSnapshot extends LogisticsTaskIdentity {
  readonly status: LogisticsTaskStatus;
  readonly createdAtElapsedDays: number;
  readonly transitions: readonly LogisticsTaskTransition[];
}

export interface LogisticsTaskBoardSnapshot {
  readonly tasks: readonly LogisticsTaskSnapshot[];
  readonly processedTransitionIds: readonly { readonly transitionId: string; readonly fingerprint: string; readonly result: LogisticsTaskMutationResult }[];
}

export type LogisticsTaskMutationResult =
  | { readonly accepted: true; readonly idempotentReplay: boolean; readonly task: LogisticsTaskSnapshot }
  | { readonly accepted: false; readonly errorCode: "DUPLICATE_ACTIVE_TASK" | "TASK_NOT_FOUND" | "INVALID_TRANSITION" | "TRANSITION_ID_CONFLICT"; readonly message: string };

const TERMINAL = new Set<LogisticsTaskStatus>(["completed", "failed", "abandoned"]);
const ALLOWED: Readonly<Record<LogisticsTaskStatus, readonly LogisticsTaskStatus[]>> = {
  created: ["accepted", "failed", "abandoned"],
  accepted: ["in_progress", "failed", "abandoned"],
  in_progress: ["completed", "failed", "abandoned"],
  completed: [], failed: [], abandoned: [],
};

export class LogisticsTaskBoard {
  readonly #tasks = new Map<string, LogisticsTaskSnapshot>();
  readonly #processed = new Map<string, { readonly fingerprint: string; readonly result: LogisticsTaskMutationResult }>();

  constructor(snapshot: LogisticsTaskBoardSnapshot = { tasks: [], processedTransitionIds: [] }) {
    for (const task of snapshot.tasks) {
      validateIdentity(task);
      requireTime(task.createdAtElapsedDays, "Task creation time");
      if (task.transitions.length === 0 || task.transitions.at(-1)?.status !== task.status) throw new Error(`Task ${task.taskId} lifecycle does not end at its status.`);
      for (const transition of task.transitions) validateTransition(transition);
      if (this.#tasks.has(task.taskId)) throw new Error(`Duplicate logistics task ${task.taskId}.`);
      this.#tasks.set(task.taskId, structuredClone(task));
    }
    for (const item of snapshot.processedTransitionIds) {
      requireId(item.transitionId, "Processed transition id");
      requireId(item.fingerprint, "Processed transition fingerprint");
      if (this.#processed.has(item.transitionId)) throw new Error(`Duplicate transition ${item.transitionId}.`);
      this.#processed.set(item.transitionId, { fingerprint: item.fingerprint, result: structuredClone(item.result) });
    }
    const activeKeys = new Set<string>();
    for (const task of this.#tasks.values()) if (!TERMINAL.has(task.status)) {
      const key = `${task.destinationEntityId}\u0000${task.goodsId}`;
      if (activeKeys.has(key)) throw new Error(`Duplicate active logistics need ${task.destinationEntityId}/${task.goodsId}.`);
      activeKeys.add(key);
    }
  }

  create(identity: LogisticsTaskIdentity, transitionId: string, elapsedDays: number, reason: string): LogisticsTaskMutationResult {
    validateIdentity(identity);
    requireId(transitionId, "Transition id");
    requireTime(elapsedDays, "Transition time");
    requireId(reason, "Transition reason");
    const fingerprint = stableFingerprint({ action: "create", identity, elapsedDays, reason });
    const replay = this.#replay(transitionId, fingerprint, identity.taskId);
    if (replay !== null) return replay;
    const duplicate = [...this.#tasks.values()].find((task) => !TERMINAL.has(task.status)
      && task.destinationEntityId === identity.destinationEntityId && task.goodsId === identity.goodsId);
    if (duplicate !== undefined) return this.#recordResult(transitionId, fingerprint, rejected("DUPLICATE_ACTIVE_TASK", `Active task ${duplicate.taskId} already covers ${identity.destinationEntityId}/${identity.goodsId}.`));
    if (this.#tasks.has(identity.taskId)) return this.#recordResult(transitionId, fingerprint, rejected("INVALID_TRANSITION", `Task ${identity.taskId} already exists.`));
    const transition = { transitionId, status: "created" as const, elapsedDays, reason };
    const task = { ...identity, status: "created" as const, createdAtElapsedDays: elapsedDays, transitions: [transition] };
    this.#tasks.set(task.taskId, task);
    return this.#recordResult(transitionId, fingerprint, { accepted: true, idempotentReplay: false, task: structuredClone(task) });
  }

  transition(taskId: string, status: LogisticsTaskStatus, transitionId: string, elapsedDays: number, reason: string): LogisticsTaskMutationResult {
    requireId(taskId, "Task id");
    requireId(transitionId, "Transition id");
    requireTime(elapsedDays, "Transition time");
    requireId(reason, "Transition reason");
    const fingerprint = stableFingerprint({ action: "transition", taskId, status, elapsedDays, reason });
    const replay = this.#replay(transitionId, fingerprint, taskId);
    if (replay !== null) return replay;
    const task = this.#tasks.get(taskId);
    if (task === undefined) return this.#recordResult(transitionId, fingerprint, rejected("TASK_NOT_FOUND", `Task ${taskId} does not exist.`));
    if (!ALLOWED[task.status].includes(status)) return this.#recordResult(transitionId, fingerprint, rejected("INVALID_TRANSITION", `${task.status} cannot transition to ${status}.`));
    if (elapsedDays < (task.transitions.at(-1)?.elapsedDays ?? task.createdAtElapsedDays)) return this.#recordResult(transitionId, fingerprint, rejected("INVALID_TRANSITION", "Task transition time cannot move backwards."));
    const updated = { ...task, status, transitions: [...task.transitions, { transitionId, status, elapsedDays, reason }] };
    this.#tasks.set(taskId, updated);
    return this.#recordResult(transitionId, fingerprint, { accepted: true, idempotentReplay: false, task: structuredClone(updated) });
  }

  active(): readonly LogisticsTaskSnapshot[] {
    return this.snapshot().tasks.filter((task) => !TERMINAL.has(task.status));
  }

  snapshot(): LogisticsTaskBoardSnapshot {
    return {
      tasks: [...this.#tasks.values()].map((task) => structuredClone(task)),
      processedTransitionIds: [...this.#processed].map(([transitionId, item]) => ({ transitionId, fingerprint: item.fingerprint, result: structuredClone(item.result) })),
    };
  }

  #replay(transitionId: string, fingerprint: string, taskId: string): LogisticsTaskMutationResult | null {
    const prior = this.#processed.get(transitionId);
    if (prior === undefined) return null;
    if (prior.fingerprint !== fingerprint) return rejected("TRANSITION_ID_CONFLICT", `Transition id ${transitionId} was reused.`);
    if (!prior.result.accepted) return structuredClone(prior.result);
    const task = this.#tasks.get(taskId);
    if (task === undefined) throw new Error(`Processed transition ${transitionId} has no task.`);
    return { accepted: true, idempotentReplay: true, task: structuredClone(task) };
  }

  #recordResult(transitionId: string, fingerprint: string, result: LogisticsTaskMutationResult): LogisticsTaskMutationResult {
    this.#processed.set(transitionId, { fingerprint, result: structuredClone(result) });
    return result;
  }
}

function validateIdentity(identity: LogisticsTaskIdentity): void {
  for (const [label, value] of [["Task id", identity.taskId], ["Owner actor", identity.ownerActorId], ["Executor party", identity.executorPartyId], ["Destination entity", identity.destinationEntityId], ["Destination node", identity.destinationNodeId], ["Goods id", identity.goodsId]] as const) requireId(value, label);
  if (!Number.isSafeInteger(identity.amount) || identity.amount <= 0) throw new Error("Task amount must be a positive safe integer.");
}

function validateTransition(transition: LogisticsTaskTransition): void {
  requireId(transition.transitionId, "Transition id");
  requireId(transition.reason, "Transition reason");
  requireTime(transition.elapsedDays, "Transition time");
}

function requireId(value: string, label: string): void {
  if (value.length === 0) throw new Error(`${label} must not be empty.`);
}

function requireTime(value: number, label: string): void {
  if (!Number.isFinite(value) || value < 0) throw new Error(`${label} must be finite and non-negative.`);
}

function stableFingerprint(value: unknown): string {
  return JSON.stringify(sortValue(value));
}

function sortValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortValue);
  if (value !== null && typeof value === "object") return Object.fromEntries(Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).map(([key, item]) => [key, sortValue(item)]));
  return value;
}

function rejected(errorCode: Extract<LogisticsTaskMutationResult, { readonly accepted: false }>["errorCode"], message: string): LogisticsTaskMutationResult {
  return { accepted: false, errorCode, message };
}
