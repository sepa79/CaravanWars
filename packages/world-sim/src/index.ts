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
  WorldSimulation,
  WorldSimulationConfigurationError,
  WorldSimulationQueryError,
  calculatePartyTravelSpeed,
  loadPartyTravelConfigFile,
} from "./world-sim.js";

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
  WorldSnapshot,
  WorldSimulationEvent,
  GoodsTransferredEvent,
  LocationEconomyTickedEvent,
  LocationSeed,
  LocationSnapshot,
  RouteWaypointObservedEvent,
  TransferGoodsCommand,
  TransferGoodsErrorCode,
  TransferGoodsResult,
  TransferPartyGoodsWithTradeHubCommand,
  WorldEconomySeed,
  WorldCommandEnvelope,
  WorldCommandSubmissionResult,
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
} from "./facilities.js";

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

export { MerchantMemoryAI } from "./merchant-memory-ai.js";
export type {
  LocationObservationMemory,
  MerchantMemoryAction,
  MerchantMemoryDecision,
  MerchantMemoryEntry,
  NeedLedgerMemory,
} from "./merchant-memory-ai.js";
export type {
  GoodsCatalog,
  GoodsDefinition,
  LocationEconomyConfig,
  LocationEconomyProfile,
  PartyCargoConfig,
} from "./economy-config.js";
