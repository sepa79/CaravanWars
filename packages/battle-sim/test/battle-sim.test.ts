import assert from "node:assert/strict";
import test from "node:test";
import { BattleSimulation, createFordDefenseBattle, formationSlots, type BattleSeed, type Hex } from "../src/battle-sim.js";

const order = (battle: BattleSimulation, type: "rally" | "advance" | "hold" | "change_facing" | "close_formation" | "loose_formation" | "withdraw", targetHex: Hex | null = null, targetFacing: number | null = null) =>
  battle.issueOrder({ issuerId: "player", targetGroupId: "retainers", category: type === "hold" || type === "change_facing" ? "position" : type === "close_formation" || type === "loose_formation" ? "formation" : type === "withdraw" ? "retreat" : "movement", type, targetHex, targetGroupIdToAttack: null, targetFacing });

test("direct control remains exclusive to the player character", () => {
  const battle = createFordDefenseBattle();
  assert.deepEqual(battle.commandPlayerMove("retainer_1", { q: -1, r: -1 }), { accepted: false, errorCode: "NOT_PLAYER_ACTOR", message: "The player directly controls only their own character." });
  assert.equal(battle.commandPlayerMove("player", { q: -2, r: 1 }).accepted, true);
});

test("orders target an authorized group and use physical voice delivery", () => {
  const battle = createFordDefenseBattle();
  assert.equal(order(battle, "hold").accepted, true);
  assert.equal(battle.issueOrder({ issuerId: "player", targetGroupId: "raiders", category: "position", type: "hold", targetHex: null, targetGroupIdToAttack: null, targetFacing: null }).accepted, false);
  const status = (): string | undefined => battle.truthSnapshot().groups.find((group) => group.id === "retainers")!.currentOrder?.status;
  battle.advanceTick(); assert.equal(status(), "propagating");
  battle.advanceTick(); assert.equal(status(), "received");
  battle.advanceTick(); assert.equal(status(), "interpreted");
  battle.advanceTick(); assert.equal(status(), "executing");
});

test("an order outside voice range becomes unheard, never magically received", () => {
  const battle = new BattleSimulation(seed({ player: { q: -4, r: 0 }, allies: [{ q: 3, r: 0 }] }));
  assert.equal(order(battle, "hold").accepted, true);
  battle.advanceTick(); battle.advanceTick();
  assert.equal(battle.truthSnapshot().groups.find((group) => group.id === "retainers")!.currentOrder?.status, "unheard");
});

test("an unreachable physical target reaches the explicit impossible terminal state", () => {
  const battle = createFordDefenseBattle();
  assert.equal(order(battle, "advance", { q: 9, r: 9 }).accepted, true);
  for (let tick = 0; tick < 4; tick += 1) battle.advanceTick();
  assert.equal(battle.truthSnapshot().groups.find((group) => group.id === "retainers")!.currentOrder?.status, "impossible");
});

test("all formations and facing rotations produce stable deterministic slots", () => {
  for (const formation of ["loose", "line", "close_shield_line"] as const) {
    const first = formationSlots({ q: 0, r: 0 }, 0, formation, 5);
    assert.deepEqual(first, formationSlots({ q: 0, r: 0 }, 0, formation, 5));
    assert.equal(new Set(first.map(key)).size, 5);
    assert.notDeepEqual(first, formationSlots({ q: 0, r: 0 }, 2, formation, 5));
  }
  const battle = createFordDefenseBattle();
  assert.equal(order(battle, "change_facing", { q: -2, r: 0 }, 2).accepted, true);
  for (let tick = 0; tick < 5; tick += 1) battle.advanceTick();
  assert.equal(battle.truthSnapshot().groups.find((group) => group.id === "retainers")!.facing, 2);
});

test("blocked ideal slots receive explicit stable fallbacks", () => {
  const battle = createFordDefenseBattle();
  const preview = battle.previewOrder("retainers", "rally", { q: 0, r: 0 }, 0)!;
  assert.ok(preview.slots.some((slot) => slot.status === "fallback" || slot.status === "blocked"));
  assert.deepEqual(preview, battle.previewOrder("retainers", "rally", { q: 0, r: 0 }, 0));
});

test("unordered allies cohere instead of independently charging", () => {
  const battle = createFordDefenseBattle(), before = battle.truthSnapshot();
  battle.advanceTick();
  const after = battle.truthSnapshot();
  for (const id of ["retainer_1", "retainer_2", "retainer_3", "retainer_4"]) {
    const start = before.actors.find((actor) => actor.id === id)!.position, end = after.actors.find((actor) => actor.id === id)!.position;
    assert.ok(Math.abs(end.q - start.q) <= 1);
    assert.ok(end.q < 1, "an unordered retainer must not home toward raiders");
  }
});

test("rally, advance and withdrawal move a coherent group through its anchor", () => {
  for (const [type, target] of [["rally", { q: -1, r: 0 }], ["advance", { q: 1, r: 0 }], ["withdraw", { q: -4, r: 0 }]] as const) {
    const battle = createFordDefenseBattle(), start = battle.truthSnapshot().groups.find((group) => group.id === "retainers")!.banner;
    assert.equal(order(battle, type, target).accepted, true);
    for (let tick = 0; tick < 9; tick += 1) battle.advanceTick();
    const group = battle.truthSnapshot().groups.find((item) => item.id === "retainers")!;
    assert.notDeepEqual(group.banner, start);
    assert.equal(new Set(battle.truthSnapshot().actors.map((actor) => key(actor.position))).size, battle.truthSnapshot().actors.length);
  }
});

test("player action and group movement share one no-overlap reservation step", () => {
  const battle = createFordDefenseBattle();
  assert.equal(order(battle, "rally", { q: -1, r: 0 }).accepted, true);
  for (let tick = 0; tick < 4; tick += 1) battle.advanceTick();
  battle.commandPlayerMove("player", { q: -2, r: 1 });
  battle.advanceTick();
  const positions = battle.truthSnapshot().actors.map((actor) => key(actor.position));
  assert.equal(new Set(positions).size, positions.length);
});

test("simultaneous duplicate targets and swaps deterministically hold losers", () => {
  const battle = new BattleSimulation(seed({ player: { q: -1, r: 0 }, allies: [{ q: 0, r: 0 }, { q: 1, r: -1 }], banner: { q: 0, r: -1 }, formation: "close_shield_line" }));
  assert.equal(order(battle, "hold").accepted, true);
  for (let tick = 0; tick < 6; tick += 1) battle.advanceTick();
  const snapshot = battle.truthSnapshot(), positions = snapshot.actors.map((actor) => key(actor.position));
  assert.equal(new Set(positions).size, positions.length);
  assert.ok(battle.playerView().recentEvents.some((event) => event.type === "move_blocked"));
});

test("following into vacated cells is allowed without overlap", () => {
  const battle = createFordDefenseBattle();
  assert.equal(order(battle, "advance", { q: 2, r: 0 }).accepted, true);
  for (let tick = 0; tick < 10; tick += 1) battle.advanceTick();
  const moved = battle.playerView().recentEvents.filter((event) => event.type === "moved");
  assert.ok(moved.length >= 2);
  const positions = battle.truthSnapshot().actors.map((actor) => key(actor.position));
  assert.equal(new Set(positions).size, positions.length);
});

test("corpses explicitly remain blocking occupants", () => {
  const battle = new BattleSimulation(seed({ player: { q: -1, r: 0 }, allies: [{ q: 0, r: 0 }] }));
  const saved = battle.saveSnapshot(), corpse = saved.actors.find((actor) => actor.seed.id === "ally_0")!;
  const restored = BattleSimulation.fromSnapshot({ ...saved, actors: saved.actors.map((actor) => actor.seed.id === corpse.seed.id ? { ...actor, health: 0 } : actor) });
  assert.equal(restored.commandPlayerMove("player", { q: 0, r: 0 }).accepted, true);
  restored.advanceTick();
  assert.deepEqual(restored.truthSnapshot().actors.find((actor) => actor.id === "player")!.position, { q: -1, r: 0 });
  assert.ok(restored.playerView().recentEvents.some((event) => event.type === "move_blocked" && event.detail === "corpse"));
});

test("save/load continuation and same command replay are deterministic", () => {
  const left = createFordDefenseBattle(); order(left, "advance", { q: 1, r: 0 });
  for (let tick = 0; tick < 5; tick += 1) left.advanceTick();
  const resumed = BattleSimulation.fromSnapshot(JSON.parse(JSON.stringify(left.saveSnapshot())));
  for (let tick = 0; tick < 8; tick += 1) { left.advanceTick(); resumed.advanceTick(); }
  assert.deepEqual(left.truthSnapshot(), resumed.truthSnapshot());
  const a = createFordDefenseBattle(), b = createFordDefenseBattle(); for (const battle of [a, b]) { order(battle, "rally", { q: -1, r: 0 }); for (let tick = 0; tick < 8; tick += 1) battle.advanceTick(); }
  assert.deepEqual(a.truthSnapshot(), b.truthSnapshot());
});

test("player perception leaks no enemy health, morale, order or hidden group truth", () => {
  const view = createFordDefenseBattle().playerView(), enemy = view.visible.find((actor) => actor.relation === "enemy")!;
  assert.equal("health" in enemy, false); assert.equal("morale" in enemy, false); assert.equal("activeOrder" in enemy, false);
  assert.equal(view.alliedGroups.some((group) => group.groupId === "raiders"), false);
});

function seed(options: { player: Hex; allies: Hex[]; banner?: Hex; formation?: "loose" | "line" | "close_shield_line" }): BattleSeed {
  return { seed: 9, playerActorId: "player", map: { radius: 5, blocked: [], difficult: [] }, actors: [
    { id: "player", name: "Player", faction: "player", position: options.player, playerControlled: true, maxHealth: 10, sightRange: 8, voiceRange: 2 },
    ...options.allies.map((position, index) => ({ id: `ally_${index}`, name: `Ally ${index}`, faction: "player" as const, position, playerControlled: false, maxHealth: 10, sightRange: 6, voiceRange: 2 })),
    { id: "enemy", name: "Enemy", faction: "enemy", position: { q: 4, r: -2 }, playerControlled: false, maxHealth: 10, sightRange: 6, voiceRange: 2 }
  ], groups: [
    { id: "retainers", name: "Retainers", faction: "player", commanderId: "player", memberIds: options.allies.map((_, index) => `ally_${index}`), banner: options.banner ?? options.allies[0]!, formation: options.formation ?? "loose", facing: 0, doctrine: "hold" },
    { id: "enemy_group", name: "Enemy", faction: "enemy", commanderId: "enemy", memberIds: ["enemy"], banner: { q: 4, r: -2 }, formation: "loose", facing: 3, doctrine: "hold" }
  ] };
}
function key(hex: Hex): string { return `${hex.q},${hex.r}`; }
