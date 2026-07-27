import assert from "node:assert/strict";
import test from "node:test";
import { createDemoBattle } from "../src/battle-sim.js";

test("the player directly controls only their own character", () => {
  const battle = createDemoBattle();
  assert.equal(battle.commandPlayerMove("ally_spear", { q: -1, r: 0 }).accepted, false);
  assert.equal(battle.commandPlayerMove("player", { q: -1, r: 1 }).accepted, true);
  battle.advanceTick();
  assert.deepEqual(battle.truthSnapshot().actors.find((actor) => actor.id === "player")?.position, { q: -1, r: 1 });
});

test("orders are grouped, authority checked and interpreted by autonomous allies", () => {
  const battle = createDemoBattle();
  const view = battle.playerView();
  assert.deepEqual(view.availableOrders.map((group) => group.category), ["movement", "position", "formation", "combat", "retreat", "command"]);
  assert.equal(battle.issueOrder({ issuerId: "player", recipientId: "ally_spear", category: "movement", type: "advance", targetHex: { q: 0, r: 0 }, targetActorId: null }).accepted, true);
  assert.equal(battle.issueOrder({ issuerId: "player", recipientId: "enemy_1", category: "combat", type: "attack", targetHex: null, targetActorId: "enemy_leader" }).accepted, false);
  battle.advanceTick();
  const ally = battle.truthSnapshot().actors.find((actor) => actor.id === "ally_spear")!;
  assert.notDeepEqual(ally.position, { q: -2, r: 0 });
  assert.equal(ally.activeOrder?.type, "advance");
});

test("player view exposes perceptions rather than enemy truth", () => {
  const battle = createDemoBattle();
  const view = battle.playerView(), enemy = view.visible.find((actor) => actor.actorId === "enemy_1")!;
  assert.equal(enemy.condition, "unhurt");
  assert.equal(enemy.orderStatus, "unknown");
  assert.equal(enemy.activeOrder, null);
  assert.equal("health" in enemy, false);
  assert.equal("morale" in enemy, false);
});

test("the same seed and commands replay deterministically", () => {
  const left = createDemoBattle(), right = createDemoBattle();
  for (const battle of [left, right]) {
    battle.issueOrder({ issuerId: "player", recipientId: "ally_spear", category: "position", type: "hold", targetHex: null, targetActorId: null });
    battle.commandPlayerMove("player", { q: -1, r: 1 });
    for (let tick = 0; tick < 6; tick += 1) battle.advanceTick();
  }
  assert.deepEqual(left.truthSnapshot(), right.truthSnapshot());
});
