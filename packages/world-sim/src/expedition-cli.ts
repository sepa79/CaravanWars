import { resolve } from "node:path";
import { ExpeditionAIController, createPlayableExpeditionFixture } from "./playable-expedition.js";
import { loadRegionGraphFile } from "./region-graph.js";
import { loadPartyTravelConfigFile } from "./world-sim.js";

const years = Number(process.argv[process.argv.indexOf("--years") + 1] ?? 1), seedValues = (process.argv[process.argv.indexOf("--seeds") + 1] ?? "47").split(",").map(Number);
if (!Number.isSafeInteger(years) || years < 1 || years > 10 || seedValues.some((item) => !Number.isSafeInteger(item))) throw new Error("Use --years 1..10 and comma-separated integer --seeds.");
const graph = loadRegionGraphFile(resolve("data/regions/silesia.json")), travel = loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json")), results = seedValues.map((seed) => {
  const fixture = createPlayableExpeditionFixture(graph, travel, seed), world = fixture.world, ai = new ExpeditionAIController();
  for (let step = 0; step < 3; step += 1) { const decision = ai.decide(world, fixture.playerPartyId); if (decision.envelope !== null) world.submitCommand(decision.envelope); }
  world.submitCommand({ commandType: "move_party", command: { party_id: fixture.banditPartyId, from_node_id: "wroclaw", to_node_id: "opole" } });
  world.submitCommand({ commandType: "plan_expedition_encounter", command: { commandId: `cli:${seed}:ambush`, issuerActorId: "bandit_chief", encounterId: `cli_ambush_${seed}`, routeId: "wroclaw_opole", attackerPartyId: fixture.banditPartyId, defenderPartyId: fixture.playerPartyId, delayDays: 0.25 } }); world.advanceDays(0.25);
  const encounterDecision = ai.decide(world, fixture.playerPartyId); if (encounterDecision.envelope !== null) world.submitCommand(encounterDecision.envelope); world.advanceDays(5);
  const delivery = ai.decide(world, fixture.playerPartyId); if (delivery.envelope !== null) world.submitCommand(delivery.envelope); world.advanceDays(years * 360 - world.elapsedDays());
  const snapshot = world.snapshot(), expedition = world.caravanExpeditionSnapshot()!; return { seed, elapsedDays: world.elapsedDays(), metrics: expedition.metrics, contractStatus: expedition.contracts[0]!.status, pendingQueue: snapshot.clock.scheduledEvents.filter((item) => item.status === "pending").length, retainedEvents: snapshot.clock.scheduledEvents.length, visibleLogSize: world.privateExpeditionLog(fixture.playerPartyId).length };
});
process.stdout.write(`${JSON.stringify({ configId: "playable-expedition-v1", years, results }, null, 2)}\n`);
