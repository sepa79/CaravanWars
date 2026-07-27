export {
  RegionGraphValidationError,
  getEdgeBetween,
  getNeighbors,
  loadRegionGraphFile,
  parseRegionGraph,
} from "./region-graph.js";

export type {
  RegionGraph,
  RegionGraphEdge,
  RegionGraphNode,
  RegionLandmark,
  RegionRouteWaypoint,
  RegionTerrainArea,
  Vec2,
} from "./region-graph.js";

export {
  PartyTravelConfigValidationError,
  PARTY_MOVEMENT_COMPONENT,
  PARTY_MOVEMENT_TICK_DUE,
  WorldSimulation,
  WorldSimulationConfigurationError,
  WorldSimulationQueryError,
  calculatePartyTravelSpeed,
  loadPartyTravelConfigFile,
} from "./world-sim.js";

export { CARAVAN_EXPEDITION_COMPONENT, CONTRACT_DEADLINE_DUE, EXPEDITION_ENCOUNTER_DUE, CaravanExpeditions } from "./caravan-expedition.js";
export type { AbandonCaravanContractCommand, AcceptCaravanContractCommand, OfferCaravanContractCommand, CaravanContractState, CaravanContractStatus, CaravanExpeditionSnapshot, CharacterCondition, CharacterRole, CharacterState, DeliverCaravanContractCommand, EncounterDecision, ExpeditionAnimalState, ExpeditionCommandResult, ExpeditionEncounterState, ExpeditionLogEntry, ExpeditionMetrics, ExpeditionVehicleState, PickupCaravanContractCommand, PlanExpeditionEncounterCommand, ResolveExpeditionEncounterCommand, RestExpeditionPartyCommand } from "./caravan-expedition.js";
export { ExpeditionAIController, createPlayableExpeditionFixture } from "./playable-expedition.js";
export type { ExpeditionAIDecision, PlayableExpeditionFixture } from "./playable-expedition.js";

export type {
  CommandResult,
  MovePartyCommand,
  MovePartyErrorCode,
  PartyComposition,
  PartySeed,
  PartySnapshot,
  PartyMapRegionEdge,
  PartyMapRegionNode,
  PartyMapRegionSnapshot,
  PartyMapSnapshot,
  PartyTravelConfig,
  PartyTravelSnapshot,
  PartyMovementOrderSnapshot,
  PartySpatialTravelSnapshot,
  WorldSnapshot,
  WorldSimulationEvent,
  GoodsTransferredEvent,
  LocationEconomyTickedEvent,
  LocationSeed,
  LocationSnapshot,
  LocalTradeHubAffordance,
  MerchantLocalTradeAffordances,
  ObserveLocalTradeContextRequest,
  ObserveLocalTradeContextResult,
  RouteWaypointObservedEvent,
  TransferGoodsCommand,
  TransferGoodsErrorCode,
  TransferGoodsResult,
  TransferPartyGoodsWithTradeHubCommand,
  DeliverSupplyTaskCommand,
  ReportSupplyTaskCommand,
  SupplyCommandResult,
  WorldEconomySeed,
  WorldCommandEnvelope,
  WorldCommandSubmissionResult,
  RelocateSpatialObjectCommand,
} from "./world-sim.js";

export {
  WorldClock,
  WorldClockAdvanceError,
  WorldClockEventBudgetExceededError,
  WorldClockValidationError,
} from "./world-clock.js";
export type {
  ScheduledEventIntent,
  ScheduledEventRecord,
  SerializableValue,
  WorldClockAdvanceOptions,
  WorldClockSnapshot,
} from "./world-clock.js";

export { Governance, GovernanceValidationError } from "./governance.js";
export type {
  AuthorityDecision,
  AuthorityDelegation,
  AuthorityQuery,
  GovernanceSnapshot,
  GovernorController,
  GovernorDefinition,
  ManagedEntityGovernance,
} from "./governance.js";

export {
  FACILITIES_COMPONENT,
  FACILITY_PRODUCTION_TICK_DUE,
  Facilities,
  FacilitiesValidationError,
} from "./facilities.js";
export type {
  CohortShortageEffect,
  FacilitiesSnapshot,
  FacilityBlockedReason,
  FacilityHostSeed,
  FacilityHostSnapshot,
  FacilityProductionEvent,
  FacilityProductionTickPayload,
  FacilityRecipe,
  FacilitySeed,
  FacilitySnapshot,
  FacilityTickResult,
  PopulationCohortSeed,
  ResourceConsumptionResult,
  ResourceQuantities,
  ResourceShortagePolicy,
  ShortageConsequence,
  FacilityProductionDegradedEvent,
  FacilityProductionRecoveredEvent,
} from "./facilities.js";

export { GovernorAIController } from "./governor-controller.js";
export type {
  AssignSupplyTaskCommand,
  GovernorDecision,
  GovernorShortagePolicy,
  GovernorSupplyAffordance,
} from "./governor-controller.js";

export {
  RESOURCE_CONSUMPTION_DUE,
  RESOURCE_DELIVERY_DUE,
  SETTLEMENT_RESOURCES_COMPONENT,
  SimulationFoundationValidationError,
  WorldSimulationFoundation,
  resourceConsumptionIntent,
  resourceDeliveryIntent,
} from "./simulation-foundation.js";
export type {
  ResourceConsumptionAttemptedEvent,
  ResourceConsumptionPayload,
  ResourceDeliveryAttemptedEvent,
  ResourceDeliveryPayload,
  FacilityOperationCommand,
  FacilityOperationResult,
  TransferFacilityGoodsToTradeHubCommand,
  SimulationFoundationEvent,
  SimulationFoundationDomainSnapshot,
  SimulationFoundationOptions,
  SimulationFoundationSnapshot,
} from "./simulation-foundation.js";

export {
  TRADE_HUBS_COMPONENT,
  TRADE_HUB_MATCH_DUE,
  TRADE_HUB_ORDER_EXPIRY_DUE,
  TradeHubs,
  TradeHubValidationError,
} from "./trade-hubs.js";
export type {
  CancelTradeHubOrderCommand,
  PlaceTradeHubOrderCommand,
  ProcessedTradeHubCommandSnapshot,
  TradeHubAccountSnapshot,
  TradeHubCommand,
  TradeHubCommandErrorCode,
  TradeHubCommandFailure,
  TradeHubCommandIdentity,
  TradeHubCommandMutation,
  TradeHubCommandResult,
  TradeHubCommandSuccess,
  TradeHubEvent,
  TradeHubGoodsTransferredEvent,
  TradeHubOrderClosedEvent,
  TradeHubOrderPlacedEvent,
  TradeHubOrderSnapshot,
  TradeHubScheduledIntentIgnoredEvent,
  TradeHubsSnapshot,
  TradeHubSnapshot,
  TradeHubTradeExecutedEvent,
  TradeOrderSide,
  TradeOrderStatus,
  TransferTradeHubGoodsCommand,
} from "./trade-hubs.js";

export {
  EconomyConfigValidationError,
  loadGoodsCatalogFile,
  loadLocationEconomyConfigFile,
  loadPartyCargoConfigFile,
} from "./economy-config.js";

export { WorldMemory, WorldMemoryValidationError } from "./world-memory.js";
export type {
  ProcessedWorldMemoryIngest,
  WorldMemoryBatchIngestResult,
  WorldMemoryEntry,
  WorldMemoryEntryView,
  WorldMemoryFreshness,
  WorldMemoryIngest,
  WorldMemoryIngestResult,
  WorldMemoryOwnerKind,
  WorldMemoryOwnerView,
  WorldMemoryProvenance,
  WorldMemorySnapshot,
  WorldMemorySourceType,
} from "./world-memory.js";

export { MerchantMemoryAI } from "./merchant-memory-ai.js";
export type {
  LocationObservationMemory,
  MerchantMemoryAction,
  MerchantMemoryDecision,
  MerchantMemoryEntry,
  NeedLedgerMemory,
  MerchantTradeAction,
  MerchantTradeDecision,
  MerchantTradePolicy,
} from "./merchant-memory-ai.js";

export { LogisticsTaskBoard } from "./logistics-tasks.js";
export type {
  LogisticsTaskBoardSnapshot,
  LogisticsTaskIdentity,
  LogisticsTaskMutationResult,
  LogisticsTaskSnapshot,
  LogisticsTaskStatus,
  LogisticsTaskTransition,
} from "./logistics-tasks.js";

export { AutonomousRegionalEconomyRunner, routeKey } from "./regional-economy.js";
export type {
  AutonomousRegionalEconomyConfig,
  AutonomousRegionalEconomySnapshot,
  RegionalDecisionRecord,
  RegionalEconomyDiagnosticSnapshot,
  RegionalEconomyMetrics,
  RegionalFacilityMarketPolicy,
  RegionalGovernorPolicy,
  RegionalMerchantPolicy,
} from "./regional-economy.js";

export { createAutonomousRegionalEconomyFixture } from "./regional-economy-fixture.js";
export type { AutonomousRegionalEconomyFixture } from "./regional-economy-fixture.js";
export {
  calendarAt,
  DAYS_PER_YEAR,
  FACILITY_PROFILE_PROCESS_DUE,
  FacilityProfileRuntime,
} from "./facility-profiles.js";
export type {
  AnimalCohort,
  EvidenceConfidence,
  EvidenceRange,
  FacilityProfileDefinition,
  FacilityProfileInstanceSeed,
  FacilityProfileInstanceSnapshot,
  FacilityProfileLayers,
  FacilityProfileProcess,
  FacilityProfileProcessEvent,
  FacilityProfileRuntimeSnapshot,
  ProcessCadence,
  ProfileCalendarDate,
  ProfileProcessStage,
  SeasonId,
} from "./facility-profiles.js";
export { PREINDUSTRIAL_FACILITY_PROFILES_V1 } from "./preindustrial-profile-fixtures.js";
export { SeasonalRegionalEconomyRunner, runSeasonalBatch } from "./seasonal-regional-economy.js";
export type {
  SeasonalBatchResult,
  SeasonalEconomyDiagnostics,
  SeasonalEconomyReport,
  SeasonalRegionalEconomySnapshot,
} from "./seasonal-regional-economy.js";
export { createSeasonalRegionalEconomyFixture, SEASONAL_ACTIVE_NODES } from "./seasonal-regional-fixture.js";
export type { SeasonalRegionalFixture } from "./seasonal-regional-fixture.js";
export {
  GovernorPopulationController,
  PopulationMigrationController,
  POPULATION_COMPONENT,
  POPULATION_MIGRATION_ARRIVAL_DUE,
  POPULATION_SEASON_DUE,
  PopulationDynamics,
} from "./population-dynamics.js";
export { ContinuousSpace, SPATIAL_SEARCH_DUE, SPATIAL_TRAVEL_DUE, buildNavigationKnowledgeGraph, detectionSucceeds, deterministicSearchPath, distance, distanceToPolyline, edgePolyline, navigationItem, pointAlongPolyline, pointInUncertainty, polylineDistance, spatialSpeedKmPerDay, terrainAt } from "./continuous-space.js";
export type { NavigationKnowledgeGraph, NavigationKnowledgeItem, NavigationKnowledgeKind, ObserveSurroundingsCommand, ReportNavigationKnowledgeCommand, SearchAreaCommand, SpatialCommandResult, SpatialMetrics, SpatialMovementConfig, SpatialRuntimeSnapshot, SpatialSearchPlan, SpatialTravelCommand, SpatialTravelKind, SpatialTravelPlan, UncertaintyCircle } from "./continuous-space.js";
export { BanditRouteController, ROUTE_ENCOUNTER_DUE, ROUTE_SECURITY_COMPONENT, RouteSecurity, SecurityAwareRouteController } from "./route-security.js";
export type { CreateSecurityTaskCommand, EncounterPartyView, EncounterPhysicalMutation, EncounterPhysicalPort, PlanRouteEncounterCommand, RouteChoicePolicy, RouteEncounterEvent, RouteEncounterSnapshot, RouteSecuritySnapshot, RouteSecurityState, SecurityCommandResult, SecurityPartyRole, SecurityPartyState, SecurityTaskKind, SecurityTaskSnapshot, SecurityTaskStatus, TransitionSecurityTaskCommand } from "./route-security.js";
export type {
  AllocateLabourCommand,
  GovernorPopulationPolicy,
  LabourAllocation,
  LabourSector,
  PopulationAgeCohorts,
  PopulationCommand,
  PopulationCommandResult,
  PopulationEvent,
  PopulationMigrationEvent,
  PopulationMigrationPolicy,
  PopulationMigrationSnapshot,
  PopulationPolicy,
  PopulationSeasonEvent,
  PopulationSettlementSeed,
  PopulationSnapshot,
  StartMigrationCommand,
} from "./population-dynamics.js";
export type {
  GoodsCatalog,
  GoodsDefinition,
  LocationEconomyConfig,
  LocationEconomyProfile,
  PartyCargoConfig,
} from "./economy-config.js";
