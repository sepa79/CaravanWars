export interface Hex { readonly q: number; readonly r: number }
export type BattleFaction = "player" | "enemy";
export type OrderCategory = "movement" | "position" | "formation" | "combat" | "retreat" | "command";
export type BattleOrderType = "follow" | "rally" | "advance" | "hold" | "guard" | "close_formation" | "loose_formation" | "attack" | "withdraw" | "pursue" | "discretion";
export interface BattleOrder { readonly orderId: string; readonly issuerId: string; readonly recipientId: string; readonly category: OrderCategory; readonly type: BattleOrderType; readonly targetHex: Hex | null; readonly targetActorId: string | null; readonly issuedTick: number }
export interface BattleActorSeed { readonly id: string; readonly name: string; readonly faction: BattleFaction; readonly position: Hex; readonly commanderId: string | null; readonly playerControlled: boolean; readonly maxHealth: number; readonly sightRange: number; readonly voiceRange: number }
export interface BattleMapSeed { readonly radius: number; readonly blocked: readonly Hex[]; readonly difficult: readonly Hex[] }
export interface BattleSeed { readonly map: BattleMapSeed; readonly actors: readonly BattleActorSeed[]; readonly playerActorId: string }

interface ActorState extends BattleActorSeed { health: number; morale: number; position: Hex; intent: ActorIntent | null; activeOrder: BattleOrder | null; orderStatus: "none" | "received" | "executing" | "refused" }
type ActorIntent = { readonly type: "move"; readonly target: Hex } | { readonly type: "attack"; readonly targetActorId: string };
export interface BattleEvent { readonly tick: number; readonly type: "moved" | "attacked" | "order_issued" | "order_received" | "order_unheard" | "order_refused"; readonly actorId: string; readonly detail: string }
export interface PlayerObservation { readonly actorId: string; readonly name: string; readonly faction: BattleFaction; readonly position: Hex; readonly relation: "self" | "ally" | "enemy"; readonly condition: "unhurt" | "hurt" | "badly_hurt" | "down"; readonly bearing: string; readonly lastObservedTick: number; readonly activeOrder: BattleOrderType | null; readonly orderStatus: ActorState["orderStatus"] | "unknown" }
export interface PlayerBattleView { readonly tick: number; readonly playerActorId: string; readonly map: BattleMapSeed; readonly self: PlayerObservation; readonly visible: readonly PlayerObservation[]; readonly selectedActorId: string | null; readonly availableOrders: readonly { readonly category: OrderCategory; readonly orders: readonly BattleOrderType[] }[]; readonly recentEvents: readonly BattleEvent[] }
export type CommandResult = { readonly accepted: true } | { readonly accepted: false; readonly errorCode: "ACTOR_NOT_FOUND" | "NOT_PLAYER_ACTOR" | "NOT_ADJACENT" | "HEX_BLOCKED" | "TARGET_NOT_VISIBLE" | "NOT_AUTHORIZED" | "INVALID_ORDER"; readonly message: string };

const DIRECTIONS: readonly Hex[] = [{ q: 1, r: 0 }, { q: 1, r: -1 }, { q: 0, r: -1 }, { q: -1, r: 0 }, { q: -1, r: 1 }, { q: 0, r: 1 }];
const ORDER_GROUPS: Readonly<Record<OrderCategory, readonly BattleOrderType[]>> = {
  movement: ["follow", "rally", "advance"], position: ["hold", "guard"], formation: ["close_formation", "loose_formation"], combat: ["attack"], retreat: ["withdraw", "pursue"], command: ["discretion"],
};

export class BattleSimulation {
  readonly #map: BattleMapSeed;
  readonly #actors = new Map<string, ActorState>();
  readonly #playerActorId: string;
  readonly #events: BattleEvent[] = [];
  #tick = 0;
  #orderSequence = 0;
  #selectedActorId: string | null = null;

  constructor(seed: BattleSeed) {
    this.#map = { radius: seed.map.radius, blocked: seed.map.blocked.map(copyHex), difficult: seed.map.difficult.map(copyHex) };
    this.#playerActorId = seed.playerActorId;
    for (const actor of seed.actors) {
      if (this.#actors.has(actor.id)) throw new Error(`Duplicate battle actor ${actor.id}.`);
      if (!insideMap(actor.position, this.#map.radius) || this.#blocked(actor.position)) throw new Error(`Invalid start hex for ${actor.id}.`);
      this.#actors.set(actor.id, { ...actor, position: copyHex(actor.position), health: actor.maxHealth, morale: 800, intent: null, activeOrder: null, orderStatus: "none" });
    }
    if (this.#actors.get(this.#playerActorId)?.playerControlled !== true) throw new Error("Player actor must exist and be player-controlled.");
  }

  selectActor(actorId: string | null): void { this.#selectedActorId = actorId; }

  commandPlayerMove(actorId: string, target: Hex): CommandResult {
    const actor = this.#actors.get(actorId);
    if (actor === undefined) return rejected("ACTOR_NOT_FOUND", `Actor ${actorId} does not exist.`);
    if (actor.id !== this.#playerActorId || !actor.playerControlled) return rejected("NOT_PLAYER_ACTOR", "The player directly controls only their own character.");
    if (hexDistance(actor.position, target) !== 1) return rejected("NOT_ADJACENT", "Direct movement is limited to an adjacent hex.");
    if (!insideMap(target, this.#map.radius) || this.#blocked(target) || this.#occupied(target)) return rejected("HEX_BLOCKED", "The target hex is unavailable.");
    actor.intent = { type: "move", target: copyHex(target) };
    return { accepted: true };
  }

  commandPlayerAttack(actorId: string, targetActorId: string): CommandResult {
    const actor = this.#actors.get(actorId), target = this.#actors.get(targetActorId);
    if (actor === undefined || target === undefined) return rejected("ACTOR_NOT_FOUND", "Attacker or target does not exist.");
    if (actor.id !== this.#playerActorId || !actor.playerControlled) return rejected("NOT_PLAYER_ACTOR", "The player directly controls only their own character.");
    if (!this.#visibleToPlayer(target)) return rejected("TARGET_NOT_VISIBLE", "The player character cannot currently perceive that target.");
    actor.intent = { type: "attack", targetActorId };
    return { accepted: true };
  }

  issueOrder(input: Omit<BattleOrder, "orderId" | "issuedTick">): CommandResult {
    const issuer = this.#actors.get(input.issuerId), recipient = this.#actors.get(input.recipientId);
    if (issuer === undefined || recipient === undefined) return rejected("ACTOR_NOT_FOUND", "Order issuer or recipient does not exist.");
    if (issuer.id !== this.#playerActorId) return rejected("NOT_AUTHORIZED", "Only the player character may issue player orders.");
    if (recipient.faction !== issuer.faction || !isInCommandChain(this.#actors, issuer.id, recipient.id)) return rejected("NOT_AUTHORIZED", `${issuer.name} has no authority over ${recipient.name}.`);
    if (!ORDER_GROUPS[input.category].includes(input.type)) return rejected("INVALID_ORDER", `${input.type} is not in ${input.category}.`);
    const order: BattleOrder = { ...input, orderId: `order:${this.#orderSequence++}`, issuedTick: this.#tick, targetHex: input.targetHex === null ? null : copyHex(input.targetHex) };
    this.#events.push({ tick: this.#tick, type: "order_issued", actorId: issuer.id, detail: `${order.type}:${recipient.id}` });
    if (hexDistance(issuer.position, recipient.position) > issuer.voiceRange) {
      this.#events.push({ tick: this.#tick, type: "order_unheard", actorId: recipient.id, detail: order.orderId });
      return { accepted: true };
    }
    recipient.activeOrder = order;
    recipient.orderStatus = recipient.morale < 200 ? "refused" : "received";
    this.#events.push({ tick: this.#tick, type: recipient.orderStatus === "refused" ? "order_refused" : "order_received", actorId: recipient.id, detail: order.orderId });
    return { accepted: true };
  }

  advanceTick(): void {
    this.#tick += 1;
    const actors = [...this.#actors.values()].filter((actor) => actor.health > 0).sort((a, b) => a.id.localeCompare(b.id));
    for (const actor of actors) {
      const intent = actor.playerControlled ? actor.intent : this.#chooseAiIntent(actor);
      actor.intent = null;
      if (intent?.type === "move") this.#move(actor, intent.target);
      else if (intent?.type === "attack") this.#attack(actor, intent.targetActorId);
    }
  }

  playerView(): PlayerBattleView {
    const player = this.#actors.get(this.#playerActorId)!;
    const visible = [...this.#actors.values()].filter((actor) => this.#visibleToPlayer(actor)).sort((a, b) => hexDistance(player.position, a.position) - hexDistance(player.position, b.position) || a.id.localeCompare(b.id)).map((actor) => observation(player, actor, this.#tick));
    return { tick: this.#tick, playerActorId: player.id, map: this.#map, self: observation(player, player, this.#tick), visible, selectedActorId: this.#selectedActorId, availableOrders: (Object.keys(ORDER_GROUPS) as OrderCategory[]).map((category) => ({ category, orders: ORDER_GROUPS[category] })), recentEvents: this.#events.slice(-12) };
  }

  truthSnapshot(): { readonly tick: number; readonly actors: readonly { readonly id: string; readonly position: Hex; readonly health: number; readonly morale: number; readonly activeOrder: BattleOrder | null }[] } {
    return { tick: this.#tick, actors: [...this.#actors.values()].sort((a, b) => a.id.localeCompare(b.id)).map((actor) => ({ id: actor.id, position: copyHex(actor.position), health: actor.health, morale: actor.morale, activeOrder: actor.activeOrder })) };
  }

  #chooseAiIntent(actor: ActorState): ActorIntent | null {
    const order = actor.activeOrder;
    if (order !== null && actor.orderStatus !== "refused") {
      actor.orderStatus = "executing";
      if (order.type === "hold" || order.type === "close_formation" || order.type === "loose_formation") return this.#adjacentEnemy(actor)?.id === undefined ? null : { type: "attack", targetActorId: this.#adjacentEnemy(actor)!.id };
      if (order.type === "attack" && order.targetActorId !== null) return this.#intentTowardActor(actor, order.targetActorId);
      if (order.type === "withdraw") return this.#stepAwayFromNearestEnemy(actor);
      const target = order.type === "follow" || order.type === "rally" ? this.#actors.get(order.issuerId)?.position ?? null : order.targetHex;
      if (target !== null) return this.#stepToward(actor, target);
    }
    const enemy = this.#nearestVisibleEnemy(actor);
    return enemy === null ? null : this.#intentTowardActor(actor, enemy.id);
  }

  #intentTowardActor(actor: ActorState, targetId: string): ActorIntent | null { const target = this.#actors.get(targetId); if (target === undefined || target.health <= 0) return null; return hexDistance(actor.position, target.position) === 1 ? { type: "attack", targetActorId: target.id } : this.#stepToward(actor, target.position); }
  #stepToward(actor: ActorState, target: Hex): ActorIntent | null { const candidates = hexNeighbors(actor.position).filter((hex) => insideMap(hex, this.#map.radius) && !this.#blocked(hex) && !this.#occupied(hex)).sort((a, b) => hexDistance(a, target) - hexDistance(b, target) || hexKey(a).localeCompare(hexKey(b))); return candidates[0] === undefined ? null : { type: "move", target: candidates[0] }; }
  #stepAwayFromNearestEnemy(actor: ActorState): ActorIntent | null { const enemy = this.#nearestVisibleEnemy(actor); if (enemy === null) return null; const candidates = hexNeighbors(actor.position).filter((hex) => insideMap(hex, this.#map.radius) && !this.#blocked(hex) && !this.#occupied(hex)).sort((a, b) => hexDistance(b, enemy.position) - hexDistance(a, enemy.position) || hexKey(a).localeCompare(hexKey(b))); return candidates[0] === undefined ? null : { type: "move", target: candidates[0] }; }
  #nearestVisibleEnemy(actor: ActorState): ActorState | null { return [...this.#actors.values()].filter((candidate) => candidate.faction !== actor.faction && candidate.health > 0 && hexDistance(actor.position, candidate.position) <= actor.sightRange).sort((a, b) => hexDistance(actor.position, a.position) - hexDistance(actor.position, b.position) || a.id.localeCompare(b.id))[0] ?? null; }
  #adjacentEnemy(actor: ActorState): ActorState | null { return [...this.#actors.values()].find((candidate) => candidate.faction !== actor.faction && candidate.health > 0 && hexDistance(actor.position, candidate.position) === 1) ?? null; }
  #move(actor: ActorState, target: Hex): void { if (hexDistance(actor.position, target) !== 1 || this.#blocked(target) || this.#occupied(target)) return; actor.position = copyHex(target); this.#events.push({ tick: this.#tick, type: "moved", actorId: actor.id, detail: hexKey(target) }); }
  #attack(actor: ActorState, targetId: string): void { const target = this.#actors.get(targetId); if (target === undefined || target.health <= 0 || target.faction === actor.faction || hexDistance(actor.position, target.position) !== 1) return; const damage = 2 + deterministicValue(`${this.#tick}:${actor.id}:${target.id}`, 3); target.health = Math.max(0, target.health - damage); target.morale = Math.max(0, target.morale - damage * 35); this.#events.push({ tick: this.#tick, type: "attacked", actorId: actor.id, detail: target.id }); }
  #visibleToPlayer(actor: ActorState): boolean { const player = this.#actors.get(this.#playerActorId)!; return actor.id === player.id || hexDistance(player.position, actor.position) <= player.sightRange; }
  #blocked(hex: Hex): boolean { return this.#map.blocked.some((item) => sameHex(item, hex)); }
  #occupied(hex: Hex): boolean { return [...this.#actors.values()].some((actor) => actor.health > 0 && sameHex(actor.position, hex)); }
}

export function createDemoBattle(): BattleSimulation { return new BattleSimulation({ playerActorId: "player", map: { radius: 5, blocked: [{ q: 0, r: -2 }, { q: 1, r: -2 }], difficult: [{ q: -1, r: 0 }, { q: 0, r: 1 }] }, actors: [
  { id: "player", name: "Aulus", faction: "player", position: { q: -2, r: 1 }, commanderId: null, playerControlled: true, maxHealth: 12, sightRange: 5, voiceRange: 4 },
  { id: "ally_spear", name: "Wulf", faction: "player", position: { q: -2, r: 0 }, commanderId: "player", playerControlled: false, maxHealth: 11, sightRange: 4, voiceRange: 3 },
  { id: "ally_bow", name: "Runa", faction: "player", position: { q: -3, r: 1 }, commanderId: "player", playerControlled: false, maxHealth: 9, sightRange: 6, voiceRange: 3 },
  { id: "enemy_1", name: "Obcy wojownik", faction: "enemy", position: { q: 2, r: -1 }, commanderId: "enemy_leader", playerControlled: false, maxHealth: 10, sightRange: 4, voiceRange: 3 },
  { id: "enemy_leader", name: "Obcy dowódca", faction: "enemy", position: { q: 3, r: -1 }, commanderId: null, playerControlled: false, maxHealth: 12, sightRange: 5, voiceRange: 4 },
] }); }

export function hexDistance(a: Hex, b: Hex): number { return (Math.abs(a.q - b.q) + Math.abs(a.q + a.r - b.q - b.r) + Math.abs(a.r - b.r)) / 2; }
export function hexNeighbors(hex: Hex): Hex[] { return DIRECTIONS.map((direction) => ({ q: hex.q + direction.q, r: hex.r + direction.r })); }
function observation(player: ActorState, actor: ActorState, tick: number): PlayerObservation { const ratio = actor.health / actor.maxHealth; return { actorId: actor.id, name: actor.name, faction: actor.faction, position: copyHex(actor.position), relation: actor.id === player.id ? "self" : actor.faction === player.faction ? "ally" : "enemy", condition: actor.health <= 0 ? "down" : ratio > .75 ? "unhurt" : ratio > .4 ? "hurt" : "badly_hurt", bearing: bearing(player.position, actor.position), lastObservedTick: tick, activeOrder: actor.faction === player.faction ? actor.activeOrder?.type ?? null : null, orderStatus: actor.faction === player.faction ? actor.orderStatus : "unknown" }; }
function bearing(from: Hex, to: Hex): string { if (sameHex(from, to)) return "tutaj"; const dq = to.q - from.q, dr = to.r - from.r; if (Math.abs(dq) > Math.abs(dr)) return dq > 0 ? "wschód" : "zachód"; return dr > 0 ? "południowy zachód" : "północny wschód"; }
function isInCommandChain(actors: ReadonlyMap<string, ActorState>, commanderId: string, actorId: string): boolean { let current = actors.get(actorId); while (current?.commanderId !== null && current?.commanderId !== undefined) { if (current.commanderId === commanderId) return true; current = actors.get(current.commanderId); } return false; }
function deterministicValue(key: string, range: number): number { let hash = 2166136261; for (const char of key) { hash ^= char.charCodeAt(0); hash = Math.imul(hash, 16777619); } return Math.abs(hash) % range; }
function insideMap(hex: Hex, radius: number): boolean { return hexDistance({ q: 0, r: 0 }, hex) <= radius; }
function sameHex(a: Hex, b: Hex): boolean { return a.q === b.q && a.r === b.r; }
function hexKey(hex: Hex): string { return `${hex.q},${hex.r}`; }
function copyHex(hex: Hex): Hex { return { q: hex.q, r: hex.r }; }
function rejected(errorCode: Exclude<CommandResult, { accepted: true }>["errorCode"], message: string): CommandResult { return { accepted: false, errorCode, message }; }
