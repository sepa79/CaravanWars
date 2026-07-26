import { calendarAt, DAYS_PER_YEAR } from "./facility-profiles.js";
import type { FacilityProfileProcessEvent, SeasonId } from "./facility-profiles.js";
import type { PopulationSeasonEvent } from "./population-dynamics.js";
import { AutonomousRegionalEconomyRunner } from "./regional-economy.js";
import type { AutonomousRegionalEconomySnapshot, RegionalEconomyMetrics } from "./regional-economy.js";
import type { RegionGraph } from "./region-graph.js";
import type { PartyTravelConfig, WorldEconomySeed } from "./world-sim.js";

export interface SeasonalEconomyReport {
  readonly fromElapsedDay: number;
  readonly toElapsedDay: number;
  readonly year: number;
  readonly season: SeasonId | "annual";
  readonly population: number;
  readonly births: number;
  readonly deaths: number;
  readonly migrationsInTransit: number;
  readonly averageHealthPermille: number;
  readonly averageNutritionPermille: number;
  readonly labourAvailable: number;
  readonly labourAllocated: number;
  readonly sowing: number;
  readonly grossHarvest: number;
  readonly seedReserve: number;
  readonly edibleSurplus: number;
  readonly feed: number;
  readonly herdCount: number;
  readonly cargoHeld: number;
  readonly spoilage: number;
  readonly profileCompletions: number;
  readonly profileBlocks: number;
  readonly regional: RegionalEconomyMetrics;
  readonly pendingQueue: number;
  readonly retainedHistory: number;
}

export interface SeasonalRegionalEconomySnapshot {
  readonly schemaVersion: 1;
  readonly runner: AutonomousRegionalEconomySnapshot;
  readonly reports: readonly SeasonalEconomyReport[];
  readonly lastReportEventCursor: number;
}

export interface SeasonalEconomyDiagnostics extends ReturnType<AutonomousRegionalEconomyRunner["diagnostics"]> {
  readonly truthView: true;
  readonly calendar: ReturnType<typeof calendarAt>;
  readonly profiles: NonNullable<AutonomousRegionalEconomySnapshot["world"]["simulationFoundation"]>["facilities"]["profileRuntime"];
  readonly populationDynamics: NonNullable<AutonomousRegionalEconomySnapshot["world"]["simulationFoundation"]>["population"];
  readonly routeSecurity: NonNullable<AutonomousRegionalEconomySnapshot["world"]["simulationFoundation"]>["routeSecurity"];
  readonly winterReserves: readonly { readonly hostId: string; readonly hay: number; readonly seedGrain: number; readonly edibleGrain: number }[];
  readonly annualReports: readonly SeasonalEconomyReport[];
}

export class SeasonalRegionalEconomyRunner {
  readonly #runner: AutonomousRegionalEconomyRunner;
  #reports: SeasonalEconomyReport[];
  #lastReportEventCursor: number;

  constructor(runner: AutonomousRegionalEconomyRunner, reports: readonly SeasonalEconomyReport[] = [], lastReportEventCursor = 0) {
    this.#runner = runner;
    this.#reports = Array.from(structuredClone(reports));
    this.#lastReportEventCursor = lastReportEventCursor;
  }

  static resume(graph: RegionGraph, travelConfig: PartyTravelConfig, economySeed: WorldEconomySeed, snapshot: SeasonalRegionalEconomySnapshot): SeasonalRegionalEconomyRunner {
    if (snapshot.schemaVersion !== 1) throw new Error(`Unsupported seasonal economy schema ${snapshot.schemaVersion}.`);
    return new SeasonalRegionalEconomyRunner(AutonomousRegionalEconomyRunner.resume(graph, travelConfig, economySeed, snapshot.runner), snapshot.reports, snapshot.lastReportEventCursor);
  }

  runDays(days: number): SeasonalEconomyReport {
    if (!Number.isSafeInteger(days) || days <= 0 || days > DAYS_PER_YEAR * 10) throw new Error("runDays must be an integer from 1 to 3600.");
    const start = this.#runner.metrics().elapsedDays;
    let remaining = days;
    while (remaining > 0) { const interval = Math.min(remaining, 90); this.#runner.runControlInterval(interval); remaining -= interval; }
    return this.#captureReport(start, this.#runner.metrics().elapsedDays, days >= DAYS_PER_YEAR ? "annual" : calendarAt(this.#runner.metrics().elapsedDays).season);
  }

  runYears(years: number): readonly SeasonalEconomyReport[] {
    if (!Number.isSafeInteger(years) || years < 1 || years > 10) throw new Error("runYears must be an integer from 1 to 10.");
    const reports: SeasonalEconomyReport[] = [];
    for (let year = 0; year < years; year += 1) reports.push(this.runDays(DAYS_PER_YEAR));
    return reports;
  }

  snapshot(): SeasonalRegionalEconomySnapshot {
    return { schemaVersion: 1, runner: this.#runner.snapshot(), reports: structuredClone(this.#reports), lastReportEventCursor: this.#lastReportEventCursor };
  }

  diagnostics(): SeasonalEconomyDiagnostics {
    const snapshot = this.#runner.snapshot();
    const facilities = snapshot.world.simulationFoundation?.facilities;
    return {
      ...this.#runner.diagnostics(),
      calendar: calendarAt(snapshot.world.clock.elapsedDays),
      profiles: facilities?.profileRuntime ?? null,
      populationDynamics: snapshot.world.simulationFoundation?.population ?? null,
      routeSecurity: snapshot.world.simulationFoundation?.routeSecurity ?? null,
      winterReserves: (facilities?.hosts ?? []).map((host) => ({ hostId: host.hostId, hay: host.inventory.hay ?? 0, seedGrain: host.inventory.seed_grain ?? 0, edibleGrain: host.inventory.edible_grain ?? 0 })),
      annualReports: this.#reports.filter((report) => report.season === "annual"),
    };
  }

  partyMapSnapshot(partyId: string) { return this.#runner.partyMapSnapshot(partyId); }

  #captureReport(fromElapsedDay: number, toElapsedDay: number, season: SeasonId | "annual"): SeasonalEconomyReport {
    const snapshot = this.#runner.snapshot();
    const foundation = snapshot.world.simulationFoundation;
    const events = foundation?.events ?? [];
    const relevant = events.slice(this.#lastReportEventCursor).filter((event): event is FacilityProfileProcessEvent => event.eventType.startsWith("FacilityProfileProcess"));
    const populationEvents = events.slice(this.#lastReportEventCursor).filter((event): event is PopulationSeasonEvent => event.eventType === "PopulationSeasonAdvanced");
    this.#lastReportEventCursor = events.length;
    const hosts = foundation?.facilities.hosts ?? [];
    const produced = (goodsId: string) => relevant.reduce((sum, event) => sum + (event.produced[goodsId] ?? 0), 0);
    const consumed = (goodsId: string) => relevant.reduce((sum, event) => sum + (event.consumed[goodsId] ?? 0), 0);
    const report: SeasonalEconomyReport = {
      fromElapsedDay, toElapsedDay, year: season === "annual" ? Math.floor(fromElapsedDay / DAYS_PER_YEAR) + 1 : calendarAt(toElapsedDay).year, season,
      population: foundation?.population?.settlements.reduce((sum, settlement) => sum + settlement.cohorts.children + settlement.cohorts.workingAdults + settlement.cohorts.elders, 0) ?? hosts.flatMap((host) => host.cohorts).reduce((sum, cohort) => sum + cohort.population, 0),
      births: populationEvents.reduce((sum, event) => sum + event.births, 0), deaths: populationEvents.reduce((sum, event) => sum + event.deaths, 0),
      migrationsInTransit: foundation?.population?.migrations.filter((migration) => migration.status === "traveling").reduce((sum, migration) => sum + migration.people, 0) ?? 0,
      averageHealthPermille: average(foundation?.population?.settlements.map((settlement) => settlement.healthPermille) ?? []),
      averageNutritionPermille: average(foundation?.population?.settlements.map((settlement) => settlement.nutritionPermille) ?? []),
      labourAvailable: populationEvents.reduce((sum, event) => sum + event.labourAvailable, 0),
      labourAllocated: foundation?.population?.settlements.flatMap((settlement) => settlement.allocations).reduce((sum, allocation) => sum + allocation.workers, 0) ?? 0,
      sowing: consumed("seed_grain"), grossHarvest: produced("gross_grain"), seedReserve: produced("seed_grain"), edibleSurplus: produced("edible_grain"),
      feed: hosts.reduce((sum, host) => sum + (host.inventory.hay ?? 0) + (host.inventory.feed ?? 0), 0),
      herdCount: foundation?.facilities.profileRuntime?.instances.flatMap((instance) => instance.animalCohorts).reduce((sum, cohort) => sum + cohort.count, 0) ?? 0,
      cargoHeld: snapshot.world.parties.reduce((sum, party) => sum + Object.values(party.cargo).reduce((inner, amount) => inner + amount, 0), 0),
      spoilage: relevant.reduce((sum, event) => sum + Object.values(event.losses).reduce((inner, amount) => inner + amount, 0), 0),
      profileCompletions: relevant.filter((event) => event.eventType === "FacilityProfileProcessCompleted").length,
      profileBlocks: relevant.filter((event) => event.eventType === "FacilityProfileProcessBlocked").length,
      regional: this.#runner.metrics(), pendingQueue: snapshot.world.clock.scheduledEvents.filter((event) => event.status === "pending").length,
      retainedHistory: snapshot.world.clock.scheduledEvents.length + events.length,
    };
    this.#reports.push(report);
    return report;
  }
}

function average(values: readonly number[]): number { return values.length === 0 ? 0 : Math.floor(values.reduce((sum, value) => sum + value, 0) / values.length); }

export interface SeasonalBatchResult { readonly seed: number; readonly reports: readonly SeasonalEconomyReport[]; readonly finalSnapshot: SeasonalRegionalEconomySnapshot }

export function runSeasonalBatch(seeds: readonly number[], years: number, create: (seed: number) => SeasonalRegionalEconomyRunner): readonly SeasonalBatchResult[] {
  if (seeds.length === 0 || new Set(seeds).size !== seeds.length) throw new Error("Batch seeds must be non-empty and unique.");
  return seeds.map((seed) => { if (!Number.isSafeInteger(seed)) throw new Error("Batch seed must be an integer."); const runner = create(seed); const reports = runner.runYears(years); return { seed, reports, finalSnapshot: runner.snapshot() }; });
}
