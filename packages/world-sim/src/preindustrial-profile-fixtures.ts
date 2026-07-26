import type { FacilityProfileDefinition, ProfileProcessStage } from "./facility-profiles.js";

const RESEARCH_PROVENANCE = "user-provided non-binding preindustrial research ranges; Facility Profiles v1 goal, 2026-07-26";
const ALL = ["winter", "spring", "summer", "autumn"] as const;

function stage(stageId: string, durationDays: number, allowedSeasons: ProfileProcessStage["allowedSeasons"], inputs: Readonly<Record<string, number>>, outputs: Readonly<Record<string, number>>, nextStageId: string, lossPermille = 0): ProfileProcessStage {
  return { stageId, durationDays, allowedSeasons, inputs, outputs, nextStageId, lossPermille };
}

const sharedLayers = {
  technology: { power: "human_or_animal_traction", storage: "local_physical_store", maintenance: "configured_inputs" },
  managementEnvironment: { workforce: "host_cohorts", timing: "world_clock_due_event", soilWeatherDisease: "explicit_config_modifiers_deferred" },
} as const;

export const PREINDUSTRIAL_FACILITY_PROFILES_V1: readonly FacilityProfileDefinition[] = [
  {
    profileId: "cereal_rye_farm_v1",
    layers: { biology: { crop: "rye", lifecycle: ["sowing", "growth", "harvest", "threshing", "seed_reserve"] }, ...sharedLayers },
    evidence: {
      yieldToSeed: { minimum: 2, maximum: 4, confidence: "medium", provenance: RESEARCH_PROVENANCE },
      laterImprovedYieldToSeed: { minimum: 3, maximum: 6, confidence: "low", provenance: RESEARCH_PROVENANCE },
      harvestProcessingLossPermille: { minimum: 60, maximum: 180, confidence: "medium", provenance: RESEARCH_PROVENANCE },
      storageLossPermille: { minimum: 70, maximum: 150, confidence: "medium", provenance: RESEARCH_PROVENANCE },
      badStorageTailPermille: { minimum: 151, maximum: 350, confidence: "low", provenance: RESEARCH_PROVENANCE },
    },
    processes: [{ processId: "annual_crop", cadence: "multistage", initialStageId: "sowing",
      stages: [
        stage("sowing", 100, ["spring"], { seed_grain: 10 }, {}, "growth"),
        stage("growth", 80, ["spring", "summer"], {}, {}, "harvest"),
        stage("harvest", 60, ["summer", "autumn"], {}, { gross_grain: 40, straw: 16 }, "threshing", 120),
        stage("threshing", 30, ["autumn", "winter"], { gross_grain: 35 }, { seed_grain: 10, edible_grain: 23 }, "seed_reserve", 57),
        stage("seed_reserve", 90, ALL, {}, {}, "sowing"),
      ] }],
  },
  {
    profileId: "hay_meadow_v1", layers: { biology: { crop: "meadow_grass", regrowth: true }, ...sharedLayers }, evidence: {},
    processes: [{ processId: "haymaking", cadence: "seasonal", initialStageId: "cut", stages: [stage("cut", 180, ["summer"], {}, { hay: 30 }, "rest", 100), stage("rest", 180, ALL, {}, {}, "cut")] }],
  },
  {
    profileId: "poultry_yard_v1", layers: { biology: { durableCohorts: true, seasonalLaying: true }, ...sharedLayers },
    evidence: { eggsPerOldHenYear: { minimum: 60, maximum: 130, confidence: "medium", provenance: RESEARCH_PROVENANCE } },
    processes: [{ processId: "laying", cadence: "periodic", initialStageId: "lay", stages: [stage("lay", 30, ["spring", "summer"], { feed: 2 }, { eggs: 8, manure: 1 }, "lay"), stage("winter_pause", 30, ["winter", "autumn"], { feed: 2 }, { manure: 1 }, "winter_pause")] }],
  },
  {
    profileId: "pig_husbandry_v1", layers: { biology: { durableCohorts: true, allocations: ["breeding", "growth", "slaughter", "manure"] }, ...sharedLayers },
    evidence: { littersPerYear: { minimum: 1, maximum: 2, confidence: "low", provenance: RESEARCH_PROVENANCE }, pigletsPerLitter: { minimum: 3, maximum: 8, confidence: "low", provenance: RESEARCH_PROVENANCE } },
    processes: [{ processId: "herd_cycle", cadence: "multistage", initialStageId: "breeding", stages: [stage("breeding", 120, ["winter", "spring"], { feed: 12 }, { manure: 4 }, "birth"), stage("birth", 90, ["spring", "summer"], { feed: 15 }, { manure: 5 }, "growth"), stage("growth", 120, ALL, { feed: 20 }, { manure: 7 }, "slaughter"), stage("slaughter", 30, ["autumn", "winter"], {}, { meat: 18, hides: 3 }, "breeding")] }],
  },
  {
    profileId: "cattle_husbandry_v1", layers: { biology: { durableCohorts: true, classes: ["cow", "calf", "ox"], allocations: ["milk_to_calves", "human_milk", "traction", "breeding", "slaughter", "manure"] }, ...sharedLayers },
    evidence: { milkPerCowSeason: { minimum: 120, maximum: 650, confidence: "low", provenance: RESEARCH_PROVENANCE } },
    processes: [{ processId: "cattle_year", cadence: "multistage", initialStageId: "calving", stages: [stage("calving", 90, ["spring"], { hay: 20 }, { manure: 8 }, "lactation"), stage("lactation", 90, ["spring", "summer"], { hay: 16 }, { milk: 12, manure: 8 }, "traction"), stage("traction", 90, ["summer", "autumn"], { hay: 18 }, { traction: 10, manure: 8 }, "wintering"), stage("wintering", 90, ["winter"], { hay: 30 }, { manure: 8 }, "calving")] }],
  },
  {
    profileId: "tannery_v1", layers: { biology: { seasonalInput: "hides" }, ...sharedLayers }, evidence: {},
    processes: [{ processId: "tanning", cadence: "periodic", initialStageId: "tan", stages: [stage("tan", 30, ALL, { hides: 3 }, { leather: 2 }, "tan", 100)] }],
  },
  {
    profileId: "weaver_v1", layers: { biology: { seasonalInput: "fibre" }, ...sharedLayers }, evidence: {},
    processes: [{ processId: "weaving", cadence: "periodic", initialStageId: "weave", stages: [stage("weave", 20, ALL, { fibre: 4 }, { cloth: 3 }, "weave", 50)] }],
  },
  {
    profileId: "mill_v1", layers: { biology: { seasonalInput: "edible_grain" }, ...sharedLayers }, evidence: {},
    processes: [{ processId: "milling", cadence: "continuous", initialStageId: "mill", stages: [stage("mill", 10, ALL, { edible_grain: 5 }, { flour: 4 }, "mill", 100)] }],
  },
  {
    profileId: "granary_spoilage_v1", layers: { biology: { perishability: "explicit_stock_process" }, ...sharedLayers },
    evidence: { storageLossPermille: { minimum: 70, maximum: 150, confidence: "medium", provenance: RESEARCH_PROVENANCE } },
    processes: [{ processId: "spoilage", cadence: "periodic", initialStageId: "inspect", stages: [stage("inspect", 90, ALL, { edible_grain: 10 }, { edible_grain: 10 }, "inspect", 100)] }],
  },
] as const;
