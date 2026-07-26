import type { PartyComposition } from "./world-sim.js";
import type { ScheduledEventIntent, SerializableValue } from "./world-clock.js";
import type { WorldMemoryOwnerView } from "./world-memory.js";

export const ROUTE_SECURITY_COMPONENT = "route_security";
export const ROUTE_ENCOUNTER_DUE = "RouteEncounterDue";

export type SecurityPartyRole = "bandit" | "patrol" | "escort";
export type SecurityTaskKind = "patrol" | "escort";
export type SecurityTaskStatus = "created" | "accepted" | "in_progress" | "completed" | "failed" | "abandoned";

export interface RouteSecurityState {
  readonly routeId: string;
  readonly riskPermille: number;
  readonly trafficValue: number;
  readonly incidentCount: number;
  readonly successfulAmbushes: number;
  readonly patrolStrength: number;
}

export interface SecurityPartyState {
  readonly partyId: string;
  readonly role: SecurityPartyRole;
  readonly ownerId: string;
  readonly governorActorId: string;
  readonly conditionPermille: number;
  readonly moralePermille: number;
  readonly supplies: number;
  readonly casualties: number;
}

export interface SecurityTaskTransition { readonly transitionId: string; readonly status: SecurityTaskStatus; readonly elapsedDays: number; readonly reason: string }
export interface SecurityTaskSnapshot {
  readonly taskId: string;
  readonly kind: SecurityTaskKind;
  readonly ownerActorId: string;
  readonly executorPartyId: string;
  readonly routeId: string;
  readonly protectedPartyId: string | null;
  readonly labourRequired: number;
  readonly status: SecurityTaskStatus;
  readonly transitions: readonly SecurityTaskTransition[];
}

export interface RouteEncounterSnapshot {
  readonly encounterId: string;
  readonly routeId: string;
  readonly attackerPartyId: string;
  readonly defenderPartyId: string;
  readonly escortPartyIds: readonly string[];
  readonly eventId: string;
  readonly status: "pending" | "resolved" | "invalidated";
}

export interface ProcessedSecurityCommand { readonly commandId: string; readonly fingerprint: string; readonly result: SecurityCommandResult }
export interface RouteSecuritySnapshot {
  readonly seed: number;
  readonly routes: readonly RouteSecurityState[];
  readonly parties: readonly SecurityPartyState[];
  readonly tasks: readonly SecurityTaskSnapshot[];
  readonly encounters: readonly RouteEncounterSnapshot[];
  readonly processedCommandIds: readonly ProcessedSecurityCommand[];
  readonly processedEventIds: readonly string[];
}

export interface CreateSecurityTaskCommand {
  readonly commandId: string;
  readonly issuerActorId: string;
  readonly taskId: string;
  readonly kind: SecurityTaskKind;
  readonly executorPartyId: string;
  readonly routeId: string;
  readonly protectedPartyId: string | null;
  readonly labourRequired: number;
}

export interface TransitionSecurityTaskCommand { readonly commandId: string; readonly issuerActorId: string; readonly taskId: string; readonly status: Exclude<SecurityTaskStatus, "created">; readonly reason: string }
export interface PlanRouteEncounterCommand {
  readonly commandId: string;
  readonly issuerActorId: string;
  readonly encounterId: string;
  readonly routeId: string;
  readonly attackerPartyId: string;
  readonly defenderPartyId: string;
  readonly escortPartyIds: readonly string[];
  readonly delayDays: number;
}
export type SecurityCommand = CreateSecurityTaskCommand | TransitionSecurityTaskCommand | PlanRouteEncounterCommand;
export type SecurityCommandResult =
  | { readonly accepted: true; readonly idempotentReplay: boolean; readonly scheduledEventId: string | null }
  | { readonly accepted: false; readonly idempotentReplay: boolean; readonly errorCode: "NOT_AUTHORIZED" | "INVALID_COMMAND" | "COMMAND_ID_CONFLICT" | "DUPLICATE_ACTIVE_TASK" | "TASK_NOT_FOUND" | "INVALID_TRANSITION" | "PARTY_NOT_PHYSICAL" | "INSUFFICIENT_LABOUR" | "DUPLICATE_ENCOUNTER" | "SCHEDULING_FAILED"; readonly message: string };

export interface RouteEncounterPayload extends Record<string, SerializableValue> { readonly encounterId: string }
export interface EncounterPartyView { readonly partyId: string; readonly travelingRouteId: string | null; readonly composition: PartyComposition; readonly cargo: Readonly<Record<string, number>>; readonly cargoFreeBulk: number; readonly conditionPermille: number; readonly moralePermille: number }
export interface EncounterPhysicalMutation { readonly attackerPartyId: string; readonly defenderPartyId: string; readonly stolenCargo: Readonly<Record<string, number>>; readonly attackerCasualties: number; readonly defenderCasualties: number; readonly escortCasualties: Readonly<Record<string, number>>; readonly defenderDelayDays: number }
export interface EncounterPhysicalPort { readonly party: (partyId: string) => EncounterPartyView | null; readonly apply: (mutation: EncounterPhysicalMutation) => boolean }

export interface RouteEncounterEvent {
  readonly eventType: "RouteEncounterResolved" | "RouteEncounterInvalidated" | "RouteEncounterIgnored";
  readonly scheduledEventId: string;
  readonly elapsedDays: number;
  readonly encounterId: string;
  readonly routeId: string;
  readonly attackerPartyId: string;
  readonly defenderPartyId: string;
  readonly outcome: "ambush_success" | "defender_held" | "attacker_retreat" | "invalidated" | "duplicate";
  readonly attackerStrength: number;
  readonly defenderStrength: number;
  readonly rollPermille: number;
  readonly stolenCargo: Readonly<Record<string, number>>;
  readonly attackerCasualties: number;
  readonly defenderCasualties: number;
  readonly riskDeltaPermille: number;
}

type RuntimeParty = Omit<SecurityPartyState, "conditionPermille" | "moralePermille" | "supplies" | "casualties"> & {
  conditionPermille: number;
  moralePermille: number;
  supplies: number;
  casualties: number;
};

export class RouteSecurity {
  readonly #seed: number;
  readonly #routes = new Map<string, RouteSecurityState>();
  readonly #parties = new Map<string, RuntimeParty>();
  readonly #tasks = new Map<string, SecurityTaskSnapshot>();
  readonly #encounters = new Map<string, RouteEncounterSnapshot>();
  readonly #processedCommands = new Map<string, ProcessedSecurityCommand>();
  readonly #processedEvents = new Set<string>();

  constructor(snapshot: RouteSecuritySnapshot) {
    if (!Number.isSafeInteger(snapshot.seed)) throw new Error("Route security seed must be an integer.");
    this.#seed = snapshot.seed;
    for (const route of snapshot.routes) { validateRoute(route); if (this.#routes.has(route.routeId)) throw new Error(`Duplicate security route ${route.routeId}.`); this.#routes.set(route.routeId, structuredClone(route)); }
    for (const party of snapshot.parties) { validateParty(party); if (this.#parties.has(party.partyId)) throw new Error(`Duplicate security party ${party.partyId}.`); this.#parties.set(party.partyId, structuredClone(party)); }
    for (const task of snapshot.tasks) { if (this.#tasks.has(task.taskId)) throw new Error(`Duplicate security task ${task.taskId}.`); this.#tasks.set(task.taskId, structuredClone(task)); }
    for (const encounter of snapshot.encounters) { if (this.#encounters.has(encounter.encounterId)) throw new Error(`Duplicate encounter ${encounter.encounterId}.`); this.#encounters.set(encounter.encounterId, structuredClone(encounter)); }
    for (const item of snapshot.processedCommandIds) this.#processedCommands.set(item.commandId, structuredClone(item));
    for (const id of snapshot.processedEventIds) this.#processedEvents.add(id);
  }

  createTask(command: CreateSecurityTaskCommand, elapsedDays: number, authorized: boolean, availableMilitaryLabour: number): SecurityCommandResult {
    const replay = this.#replay(command); if (replay !== null) return replay;
    if (!authorized) return this.#record(command, fail("NOT_AUTHORIZED", "Actor is not authorized to create a security task."));
    if (!Number.isSafeInteger(command.labourRequired) || command.labourRequired <= 0 || command.taskId.length === 0 || command.executorPartyId.length === 0 || !this.#routes.has(command.routeId) || (command.kind === "escort" && command.protectedPartyId === null)) return this.#record(command, fail("INVALID_COMMAND", "Security task payload is invalid."));
    if (availableMilitaryLabour < command.labourRequired) return this.#record(command, fail("INSUFFICIENT_LABOUR", "Security task lacks allocated military labour."));
    if (this.#parties.get(command.executorPartyId)?.role !== command.kind) return this.#record(command, fail("INVALID_COMMAND", "Executor role does not match task kind."));
    const duplicate = [...this.#tasks.values()].find((task) => !terminal(task.status) && task.executorPartyId === command.executorPartyId && task.routeId === command.routeId);
    if (duplicate !== undefined) return this.#record(command, fail("DUPLICATE_ACTIVE_TASK", `Active task ${duplicate.taskId} already covers the executor/route.`));
    this.#tasks.set(command.taskId, { taskId: command.taskId, kind: command.kind, ownerActorId: command.issuerActorId, executorPartyId: command.executorPartyId, routeId: command.routeId, protectedPartyId: command.protectedPartyId, labourRequired: command.labourRequired, status: "created", transitions: [{ transitionId: `${command.commandId}:created`, status: "created", elapsedDays, reason: "created" }] });
    return this.#record(command, { accepted: true, idempotentReplay: false, scheduledEventId: null });
  }

  transitionTask(command: TransitionSecurityTaskCommand, elapsedDays: number, authorized: boolean): SecurityCommandResult {
    const replay = this.#replay(command); if (replay !== null) return replay;
    if (!authorized) return this.#record(command, fail("NOT_AUTHORIZED", "Actor is not authorized to transition security task."));
    const task = this.#tasks.get(command.taskId); if (task === undefined) return this.#record(command, fail("TASK_NOT_FOUND", `Security task ${command.taskId} does not exist.`));
    if (!allowedTransition(task.status, command.status)) return this.#record(command, fail("INVALID_TRANSITION", `${task.status} cannot transition to ${command.status}.`));
    this.#tasks.set(task.taskId, { ...task, status: command.status, transitions: [...task.transitions, { transitionId: command.commandId, status: command.status, elapsedDays, reason: command.reason }] });
    if (task.kind === "patrol" && command.status === "completed") this.#adjustRoute(task.routeId, -120, task.labourRequired, false, false);
    return this.#record(command, { accepted: true, idempotentReplay: false, scheduledEventId: null });
  }

  planEncounter(command: PlanRouteEncounterCommand, elapsedDays: number, authorized: boolean, physical: (partyId: string) => EncounterPartyView | null): { readonly result: SecurityCommandResult; readonly intent: ScheduledEventIntent | null } {
    const replay = this.#replay(command); if (replay !== null) return { result: replay, intent: null };
    if (!authorized) return { result: this.#record(command, fail("NOT_AUTHORIZED", "Actor is not authorized to plan an encounter.")), intent: null };
    if (this.#encounters.has(command.encounterId)) return { result: this.#record(command, fail("DUPLICATE_ENCOUNTER", `Encounter ${command.encounterId} exists.`)), intent: null };
    const attackerState = this.#parties.get(command.attackerPartyId);
    const participantIds = [command.attackerPartyId, command.defenderPartyId, ...command.escortPartyIds];
    if (!Number.isFinite(command.delayDays) || command.delayDays <= 0 || attackerState?.role !== "bandit" || attackerState.supplies <= 0 || !this.#routes.has(command.routeId) || new Set(participantIds).size !== participantIds.length) return { result: this.#record(command, fail("INVALID_COMMAND", "Encounter payload, supplies, or distinct participants are invalid.")), intent: null };
    const participants = [command.attackerPartyId, command.defenderPartyId, ...command.escortPartyIds].map(physical);
    if (participants.some((party) => party === null || party.travelingRouteId !== command.routeId)) return { result: this.#record(command, fail("PARTY_NOT_PHYSICAL", "Every encounter party must be traveling on the declared route.")), intent: null };
    const eventId = `encounter:${command.encounterId}:due`;
    this.#encounters.set(command.encounterId, { encounterId: command.encounterId, routeId: command.routeId, attackerPartyId: command.attackerPartyId, defenderPartyId: command.defenderPartyId, escortPartyIds: [...command.escortPartyIds], eventId, status: "pending" });
    const result = this.#record(command, { accepted: true, idempotentReplay: false, scheduledEventId: eventId });
    return { result, intent: { eventId, kind: ROUTE_ENCOUNTER_DUE, dueElapsedDays: elapsedDays + command.delayDays, targetComponent: ROUTE_SECURITY_COMPONENT, targetEntityId: command.routeId, payload: { encounterId: command.encounterId } } };
  }

  recordSchedulingFailure(command: PlanRouteEncounterCommand, before: RouteSecuritySnapshot, error: unknown): SecurityCommandResult { this.restore(before); return this.#record(command, fail("SCHEDULING_FAILED", error instanceof Error ? error.message : String(error))); }

  handleEncounter(intent: ScheduledEventIntent, elapsedDays: number, port: EncounterPhysicalPort): RouteEncounterEvent {
    const encounterId = readEncounterPayload(intent.payload), encounter = this.#encounters.get(encounterId);
    if (this.#processedEvents.has(intent.eventId) || encounter?.status === "resolved") return ignoredEncounter(intent, elapsedDays, encounter, "duplicate");
    this.#processedEvents.add(intent.eventId);
    if (encounter === undefined || encounter.status !== "pending") return ignoredEncounter(intent, elapsedDays, encounter, "invalidated");
    const attacker = port.party(encounter.attackerPartyId), defender = port.party(encounter.defenderPartyId), escortViews = encounter.escortPartyIds.map(port.party), escorts = escortViews.filter((item): item is EncounterPartyView => item !== null);
    if (attacker === null || defender === null || escorts.length !== encounter.escortPartyIds.length || attacker.travelingRouteId !== encounter.routeId || defender.travelingRouteId !== encounter.routeId || escorts.some((party) => party.travelingRouteId !== encounter.routeId)) { this.#encounters.set(encounterId, { ...encounter, status: "invalidated" }); return ignoredEncounter(intent, elapsedDays, encounter, "invalidated"); }
    const attackerState = this.#parties.get(attacker.partyId)!;
    const attackerStrength = strength(attacker), defenderStrength = strength(defender) + escorts.reduce((sum, party) => sum + strength(party), 0) + this.#route(encounter.routeId).patrolStrength;
    const rollPermille = roll(`${this.#seed}:${encounter.encounterId}`), attackerScore = attackerStrength * (750 + rollPermille) / 1000;
    const outcome = attackerState.moralePermille < 300 || attackerScore < defenderStrength * 0.7 ? "attacker_retreat" : attackerScore > defenderStrength ? "ambush_success" : "defender_held";
    const stolenCargo = outcome === "ambush_success" ? stealableCargo(defender.cargo, attacker.cargoFreeBulk) : {};
    const defenderCasualties = outcome === "ambush_success" ? Math.min(2, headcount(defender.composition)) : 0;
    const attackerCasualties = outcome === "ambush_success" ? 0 : Math.min(outcome === "attacker_retreat" ? 1 : 2, headcount(attacker.composition));
    const escortCasualties = Object.fromEntries(escorts.map((escort) => [escort.partyId, outcome === "ambush_success" ? Math.min(1, headcount(escort.composition)) : 0]));
    const mutation = { attackerPartyId: attacker.partyId, defenderPartyId: defender.partyId, stolenCargo, attackerCasualties, defenderCasualties, escortCasualties, defenderDelayDays: outcome === "ambush_success" ? 1 : 0 };
    if (!port.apply(mutation)) { this.#encounters.set(encounterId, { ...encounter, status: "invalidated" }); return ignoredEncounter(intent, elapsedDays, encounter, "invalidated"); }
    attackerState.supplies = Math.max(0, attackerState.supplies - 1); attackerState.casualties += attackerCasualties; attackerState.moralePermille = clamp(attackerState.moralePermille + (outcome === "ambush_success" ? 80 : -100));
    const riskDeltaPermille = outcome === "ambush_success" ? 80 : -60; this.#adjustRoute(encounter.routeId, riskDeltaPermille, 0, outcome === "ambush_success", true); this.#encounters.set(encounterId, { ...encounter, status: "resolved" });
    return { eventType: "RouteEncounterResolved", scheduledEventId: intent.eventId, elapsedDays, encounterId, routeId: encounter.routeId, attackerPartyId: attacker.partyId, defenderPartyId: defender.partyId, outcome, attackerStrength, defenderStrength, rollPermille, stolenCargo, attackerCasualties, defenderCasualties, riskDeltaPermille };
  }

  route(routeId: string): RouteSecurityState | null { return this.#routes.has(routeId) ? structuredClone(this.#route(routeId)) : null; }
  party(partyId: string): SecurityPartyState | null { const party = this.#parties.get(partyId); return party === undefined ? null : structuredClone(party); }
  tasks(): readonly SecurityTaskSnapshot[] { return [...this.#tasks.values()].map((item) => structuredClone(item)); }
  snapshot(): RouteSecuritySnapshot { return { seed: this.#seed, routes: [...this.#routes.values()].map((item) => structuredClone(item)), parties: [...this.#parties.values()].map((item) => structuredClone(item)), tasks: this.tasks(), encounters: [...this.#encounters.values()].map((item) => structuredClone(item)), processedCommandIds: [...this.#processedCommands.values()].map((item) => structuredClone(item)), processedEventIds: [...this.#processedEvents] }; }
  restore(snapshot: RouteSecuritySnapshot): void { const restored = new RouteSecurity(snapshot); this.#routes.clear(); this.#parties.clear(); this.#tasks.clear(); this.#encounters.clear(); this.#processedCommands.clear(); this.#processedEvents.clear(); for (const [id, item] of restored.#routes) this.#routes.set(id, item); for (const [id, item] of restored.#parties) this.#parties.set(id, item); for (const [id, item] of restored.#tasks) this.#tasks.set(id, item); for (const [id, item] of restored.#encounters) this.#encounters.set(id, item); for (const [id, item] of restored.#processedCommands) this.#processedCommands.set(id, item); for (const id of restored.#processedEvents) this.#processedEvents.add(id); }
  #route(id: string): RouteSecurityState { const route = this.#routes.get(id); if (route === undefined) throw new Error(`Unknown route security state ${id}.`); return route; }
  #adjustRoute(id: string, riskDelta: number, patrolDelta: number, success = false, incident = false): void { const route = this.#route(id); this.#routes.set(id, { ...route, riskPermille: clamp(route.riskPermille + riskDelta), patrolStrength: Math.max(0, route.patrolStrength + patrolDelta), incidentCount: route.incidentCount + (incident ? 1 : 0), successfulAmbushes: route.successfulAmbushes + (success ? 1 : 0) }); }
  #replay(command: SecurityCommand): SecurityCommandResult | null { const known = this.#processedCommands.get(command.commandId); if (known === undefined) return null; return known.fingerprint === fingerprint(command) ? { ...known.result, idempotentReplay: true } : fail("COMMAND_ID_CONFLICT", `Security command id ${command.commandId} has another payload.`); }
  #record(command: SecurityCommand, result: SecurityCommandResult): SecurityCommandResult { this.#processedCommands.set(command.commandId, { commandId: command.commandId, fingerprint: fingerprint(command), result: structuredClone(result) }); return result; }
}

export interface RouteChoicePolicy { readonly valueOfDayDelay: number; readonly riskCostPerPermille: number; readonly maximumRiskPermille: number }
export class SecurityAwareRouteController {
  choose(memory: WorldMemoryOwnerView, candidates: readonly { readonly routeId: string; readonly distanceKm: number; readonly escorted: boolean }[], cargoValue: number, policy: RouteChoicePolicy): { readonly routeId: string | null; readonly reason: string } {
    const scored = candidates.flatMap((candidate) => { const observation = [...memory.entries].reverse().find((entry) => entry.kind === "route_security_observation" && entry.payload.routeId === candidate.routeId && entry.freshness === "fresh"); if (observation === undefined || typeof observation.payload.riskPermille !== "number") return []; const risk = Math.max(0, observation.payload.riskPermille - (candidate.escorted ? 200 : 0)); if (risk > policy.maximumRiskPermille) return []; return [{ routeId: candidate.routeId, score: candidate.distanceKm * policy.valueOfDayDelay + risk * policy.riskCostPerPermille * Math.max(1, cargoValue) }]; }).sort((a, b) => a.score - b.score || (a.routeId < b.routeId ? -1 : 1));
    return scored[0] === undefined ? { routeId: null, reason: "NO_KNOWN_ACCEPTABLE_ROUTE" } : { routeId: scored[0].routeId, reason: "LOWEST_REMEMBERED_COST" };
  }
}

export class BanditRouteController {
  choose(memory: WorldMemoryOwnerView, partyId: string): { readonly routeId: string | null; readonly reason: string } { const opportunities = memory.entries.filter((entry) => entry.kind === "route_traffic_observation" && entry.freshness === "fresh" && typeof entry.payload.routeId === "string" && typeof entry.payload.trafficValue === "number").sort((a, b) => (b.payload.trafficValue as number) - (a.payload.trafficValue as number) || a.sequence - b.sequence); return opportunities[0] === undefined ? { routeId: null, reason: `NO_KNOWN_TRAFFIC:${partyId}` } : { routeId: opportunities[0].payload.routeId as string, reason: "HIGHEST_REMEMBERED_TRAFFIC" }; }
}

function strength(party: EncounterPartyView): number { return Math.floor((party.composition.footCount + party.composition.horseCount * 2 + party.composition.guardCount * 3) * party.conditionPermille * party.moralePermille / 1_000_000); }
function headcount(composition: PartyComposition): number { return composition.footCount + composition.horseCount + composition.guardCount; }
function stealableCargo(cargo: Readonly<Record<string, number>>, freeBulk: number): Readonly<Record<string, number>> { let remaining = Math.max(0, Math.floor(freeBulk)); const result: Record<string, number> = {}; for (const goodsId of Object.keys(cargo).sort()) { const amount = Math.min(cargo[goodsId] ?? 0, remaining); if (amount > 0) result[goodsId] = amount; remaining -= amount; } return result; }
function readEncounterPayload(value: SerializableValue): string { if (value === null || Array.isArray(value) || typeof value !== "object") throw new Error("Invalid encounter payload."); const id = (value as Record<string, SerializableValue>).encounterId; if (typeof id !== "string") throw new Error("Invalid encounter payload."); return id; }
function ignoredEncounter(intent: ScheduledEventIntent, elapsedDays: number, encounter: RouteEncounterSnapshot | undefined, reason: "duplicate" | "invalidated"): RouteEncounterEvent { return { eventType: reason === "duplicate" ? "RouteEncounterIgnored" : "RouteEncounterInvalidated", scheduledEventId: intent.eventId, elapsedDays, encounterId: encounter?.encounterId ?? "unknown", routeId: encounter?.routeId ?? intent.targetEntityId, attackerPartyId: encounter?.attackerPartyId ?? "unknown", defenderPartyId: encounter?.defenderPartyId ?? "unknown", outcome: reason, attackerStrength: 0, defenderStrength: 0, rollPermille: 0, stolenCargo: {}, attackerCasualties: 0, defenderCasualties: 0, riskDeltaPermille: 0 }; }
function validateRoute(route: RouteSecurityState): void { if (route.routeId.length === 0 || !Number.isSafeInteger(route.riskPermille) || route.riskPermille < 0 || route.riskPermille > 1000) throw new Error("Invalid route security state."); }
function validateParty(party: SecurityPartyState): void { if (party.partyId.length === 0 || !["bandit", "patrol", "escort"].includes(party.role) || [party.conditionPermille, party.moralePermille].some((value) => !Number.isSafeInteger(value) || value < 0 || value > 1000)) throw new Error("Invalid security party state."); }
function allowedTransition(from: SecurityTaskStatus, to: SecurityTaskStatus): boolean { const allowed: Readonly<Record<SecurityTaskStatus, readonly SecurityTaskStatus[]>> = { created: ["accepted", "abandoned"], accepted: ["in_progress", "failed", "abandoned"], in_progress: ["completed", "failed", "abandoned"], completed: [], failed: [], abandoned: [] }; return allowed[from].includes(to); }
function terminal(status: SecurityTaskStatus): boolean { return status === "completed" || status === "failed" || status === "abandoned"; }
function roll(value: string): number { let hash = 2166136261; for (let index = 0; index < value.length; index += 1) { hash ^= value.charCodeAt(index); hash = Math.imul(hash, 16777619); } return (hash >>> 0) % 1000; }
function clamp(value: number): number { return Math.max(0, Math.min(1000, Math.round(value))); }
function fail(errorCode: Extract<SecurityCommandResult, { accepted: false }>["errorCode"], message: string): SecurityCommandResult { return { accepted: false, idempotentReplay: false, errorCode, message }; }
function fingerprint(value: unknown): string { return JSON.stringify(sort(value)); }
function sort(value: unknown): unknown { if (Array.isArray(value)) return value.map(sort); if (value !== null && typeof value === "object") return Object.fromEntries(Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).map(([key, item]) => [key, sort(item)])); return value; }
