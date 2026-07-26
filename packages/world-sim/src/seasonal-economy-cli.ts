import { resolve } from "node:path";
import { createSeasonalRegionalEconomyFixture } from "./seasonal-regional-fixture.js";
import { loadPartyTravelConfigFile } from "./world-sim.js";
import { loadRegionGraphFile } from "./region-graph.js";

const options = parseOptions(process.argv.slice(2));
const graph = loadRegionGraphFile(resolve("data/regions/silesia.json"));
const travel = loadPartyTravelConfigFile(resolve("data/simulation/party_travel.json"));
const results = options.seeds.map((seed) => {
  const fixture = createSeasonalRegionalEconomyFixture(graph, travel, seed, options.merchants);
  const reports = fixture.runner.runYears(options.years);
  const diagnostics = fixture.runner.diagnostics();
  return { seed, years: options.years, reports, final: { calendar: diagnostics.calendar, profileCount: diagnostics.profiles?.instances.length ?? 0, activeTasks: diagnostics.metrics.activeTasks, pendingQueue: diagnostics.metrics.pendingClockEvents } };
});
process.stdout.write(`${JSON.stringify({ configId: "seasonal-silesia-v1", results }, null, 2)}\n`);

function parseOptions(args: readonly string[]): { readonly years: number; readonly seeds: readonly number[]; readonly merchants: number } {
  let years = 1, seeds: number[] = [17], merchants = 12;
  for (let index = 0; index < args.length; index += 1) {
    const key = args[index], value = args[index + 1];
    if (value === undefined) throw new Error(`Missing value after ${key}.`);
    if (key === "--years") years = Number(value);
    else if (key === "--seeds") seeds = value.split(",").map(Number);
    else if (key === "--merchants") merchants = Number(value);
    else throw new Error(`Unknown option ${key}.`);
    index += 1;
  }
  if (!Number.isSafeInteger(years) || years < 1 || years > 10) throw new Error("--years must be from 1 to 10.");
  if (seeds.length === 0 || seeds.some((seed) => !Number.isSafeInteger(seed)) || new Set(seeds).size !== seeds.length) throw new Error("--seeds must contain unique comma-separated integers.");
  if (!Number.isSafeInteger(merchants) || merchants < 12 || merchants > 40) throw new Error("--merchants must be from 12 to 40.");
  return { years, seeds, merchants };
}
