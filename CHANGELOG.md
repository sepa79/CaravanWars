# Changelog

## Unreleased

### Added

- Continuous Space, Exploration & Private Navigation Graph v1 with one
  authoritative 2D truth, hidden/off-road locations, deterministic movement
  and search, private uncertain navigation knowledge, save/replay, and
  explicitly filtered Party Map versus labelled truth diagnostics.

- Route Security, Bandits & Escorts v1 with local route risk, physical
  security Parties, Governance/labour-checked task lifecycle, deterministic
  delayed encounters, atomic physical effects, private aging observations,
  replay-safe saves, regional metrics and labelled truth diagnostics.

- Population, Health & Labour Dynamics v1 with deterministic age cohorts,
  births/aging/deaths, nutrition, disease/recovery, seasonal scarce labour,
  memory-bound Governor allocation, ration reserves and delayed migration.

- Generic layered Facility Profiles with deterministic seasonal/multistage
  processes, durable livestock cohorts, explicit spoilage and historical
  evidence ranges; a ten-node seasonal Silesia economy with a 1–10 year
  multi-seed runner, save/replay, bounds metrics and truth-only diagnostics.

- Autonomous Regional Economy v1 with three local settlement economies,
  competing memory-bound merchants, Governor supply response, physical
  logistics, a deterministic 1–180 day CLI runner, save/resume, and metrics.
- Idempotent LogisticsTaskBoard lifecycle and explicitly truth-scoped browser
  economy diagnostics.

- Configured Shortage Consequences v0 with deterministic block, degradation,
  retry, cohort episode effects, recovery, save/load, and replay behavior.
- Memory-bound GovernorAI v0 with Governance-scoped delegation, physical
  Facility delivery, and explicit provenance-bearing reports.

- TypeScript WorldMemory v0 with deterministic owner-scoped entries,
  provenance, observed/known simulation times, explicit freshness, atomic
  idempotent ingest, and validated JSON save/load.
- WorldSimulation-adjudicated local TradeHub observation and owner-scoped
  command-result memory without remote truth exposure.
- A pure memory-driven MerchantAI TradeHub policy and full Facility-to-market
  vertical scenario covering local purchase, physical inter-hub transport,
  local resale, replay, stale knowledge, and actor isolation.

- Location-bound Trade Hub instances with physical Facility and party
  deposits/withdrawals, local accounts, goods and currency escrow, stable
  price-time matching, partial fills, cancellation, and scheduled expiry.
- Canonical Trade Hub commands authorized by Governance and deduplicated by
  command id, plus save/load continuation and a two-location physical transport
  integration scenario.
- Atomic World Clock batch scheduling for domain commands that enqueue more
  than one intent.

- Architecture contracts for generic owner/governor authority chains and
  reusable, event-scheduled Facility production cycles.
- Serializable World Clock scheduling ordered by due time and stable scheduling
  sequence, including cancellation, persisted lifecycle/idempotency state,
  explicit dispatch failures, positive-delay retries, and a bounded same-time
  event budget.
- Generic Governance runtime with separate owners and governors, controller
  kinds, role configuration, scoped superior chains, time-bounded delegations,
  cycle rejection, and an authority-checked Facility operation command.
- Deterministic atomic Facilities with generation invalidation, duplicate-event
  protection, explicit blocked outcomes for resources, storage, power,
  maintenance, and workforce, plus configurable retry cadence.
- A save/load integration fixture covering cohort-level production, warehouse
  stock, same-time consumption-before-delivery causality, shortage unrest and
  workforce loss, blocked follow-up production, and a successful later retry.

- Deterministic TypeScript World Clock with explicit positive time advances.
- Server-authoritative `MovePartyCommand` handling, party travel state,
  route-waypoint interpolation, snapshots, and rejection tests.
- Development-only Node/Vite browser Truth Map with Canvas rendering, explicit
  time controls, and movement through the normal command boundary.
- Playwright browser coverage for Truth Map rendering, command-driven travel,
  deterministic arrival, and explicit invalid host-control failures.
- Actor-filtered Party Map snapshots that serialize only party-known nodes and
  routes and never fall back to authoritative truth for an unknown observer.
- Owner-specific route observation events at travel start, with Party Map
  discovery of authored waypoints and referenced landmarks without exposing
  full terrain geometry.
- Canonical goods, party-cargo, and location-economy config loaders for the
  active TypeScript runtime.
- Physical party cargo and managed-location resources inside the same
  authoritative `WorldSimulation`, including full-day metabolism and atomic
  `TransferGoodsCommand` validation/events.
- A single typed world-command envelope shared by browser and AI controllers.
- Memory-bounded merchant AI plus a playable browser loop that withdraws,
  transports, and deposits food without reading remote authoritative truth.
