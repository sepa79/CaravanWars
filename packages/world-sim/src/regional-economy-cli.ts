import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

import { createAutonomousRegionalEconomyFixture } from "./regional-economy-fixture.js";
import { AutonomousRegionalEconomyRunner } from "./regional-economy.js";
import type { AutonomousRegionalEconomySnapshot } from "./regional-economy.js";
import { loadPartyTravelConfigFile } from "./world-sim.js";
import { loadRegionGraphFile } from "./region-graph.js";

const options = parseArguments(process.argv.slice(2));
const graph = loadRegionGraphFile(resolve("data/regions/silesia.json"));
const travel = loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json"));
const fixture = createAutonomousRegionalEconomyFixture(graph, travel, options.seed);
const runner = options.resumePath === null
  ? fixture.runner
  : AutonomousRegionalEconomyRunner.resume(
      graph, travel, fixture.economySeed,
      JSON.parse(readFileSync(options.resumePath, "utf8")) as AutonomousRegionalEconomySnapshot,
    );
const metrics = runner.runDays(options.days);
if (options.savePath !== null) writeFileSync(options.savePath, `${JSON.stringify(runner.snapshot(), null, 2)}\n`, "utf8");
process.stdout.write(`${JSON.stringify(metrics)}\n`);

function parseArguments(args: readonly string[]): { days: number; seed: number; savePath: string | null; resumePath: string | null } {
  let days = 30, seed = 17, savePath: string | null = null, resumePath: string | null = null;
  for (let index = 0; index < args.length; index += 2) {
    const name = args[index], value = args[index + 1];
    if (value === undefined) throw new Error(`Missing value for ${name}.`);
    if (name === "--days") days = Number(value);
    else if (name === "--seed") seed = Number(value);
    else if (name === "--save") savePath = resolve(value);
    else if (name === "--resume") resumePath = resolve(value);
    else throw new Error(`Unknown argument ${name}.`);
  }
  if (!Number.isSafeInteger(days) || days < 1 || days > 180) throw new Error("--days must be an integer from 1 to 180.");
  if (!Number.isSafeInteger(seed)) throw new Error("--seed must be a safe integer.");
  return { days, seed, savePath, resumePath };
}
