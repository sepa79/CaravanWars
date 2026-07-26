# Facility Profiles & Seasonal Regional Economy v1

## Contract

`profileId` selects simulation behavior. `visualSkinId` is retained for presentation and is never read by the runtime. Profiles are data interpreted by the one generic Facilities component; setting-specific `PigFarm`, `CattleFarm`, or Mars classes are forbidden.

Every profile separates biology (growth, maturity, breeding, lactation, durable cohorts, seasonality), technology (tools/power, traction, storage, maintenance), and management/environment (workforce, timeliness, soil, weather, disease). Deferred modifiers remain explicit configuration rather than hidden corrections.

The calendar projects canonical `WorldClock.elapsedDays` onto a deterministic 360-day year with four 90-day seasons. It is not a second clock. Continuous, periodic, seasonal and multistage processes schedule serializable `FacilityProfileProcessDue` intents. Ordering is due time then scheduling sequence, with no event-kind priority. A handled intent emits completed/blocked/skipped evidence and exactly one later successor. Missing input never creates stock, advances a stage, or applies a partial mutation.

## Profiles and evidence boundary

The non-binding v1 fixture catalog provides rye/cereal farming, hay meadow, poultry, pig and cattle husbandry, tannery, weaver, mill, and granary spoilage. Animal cohorts are durable state with configured breeding, calf-milk and traction allocations. `winterFeedRequired` is explicit; husbandry physically consumes hay/feed, so winter capacity is feed-limited rather than slot-only.

Rye is a multistage sowing/growth/harvest/threshing/seed-reserve process. Events expose gross output and process loss; inventory separately retains seed grain and edible grain. Missing seed blocks the next sowing. Spoilage is an ordinary configured stock process, not a global `goodsId` property.

Research values are ranges with confidence and provenance, not balance: ordinary grain yield-to-seed 2–4; later/improved 3–6; harvest/processing loss 6–18%; storage loss 7–15% plus an adverse tail; old hens 60–130 eggs/year. Milk, litters and piglets are low-confidence. Oats, final prices, disease/weather/soil curves and breed catalogs are deferred. No tractors, industrial breeds or modern cultivars are implied.

## Regional orchestration

The seasonal Silesia fixture activates ten graph nodes, ten local Facility hosts/TradeHubs, ten varied profiles, ten quartermasters and at least twelve capacity-limited merchants. The existing autonomous loop remains the only orchestration and command path. Observations remain private, local, provenance-bearing and stale; future harvests are never WorldMemory truth. Goods/currency move only through existing TradeHub, cargo and travel commands.

The runner supports 1–10 years, save/resume, unique-seed batches, 12–40 merchants and a deterministic 90-day strategic controller cadence. WorldClock still dispatches every due physical process at its exact time. Reports aggregate population, sowing, gross harvest, seed reserve, edible surplus, feed, herds, production, consumption, spoilage, shortages, trades/value, transport, unrest, tasks, pending queue and retained history.

## Bounds and retention

- one pending successor exists per configured profile process;
- shortage retries retain their existing bounded episode contract;
- all inventory input/capacity validation precedes mutation;
- active logistics needs remain unique through `LogisticsTaskBoard`;
- Party Map contains no Foundation/profile/private-memory truth;
- WorldClock terminal records, Foundation events, WorldMemory and decisions grow linearly in v1. Compaction is deferred and exposed by `retainedHistory`; pending work must remain bounded.

Canonical code is `facility-profiles.ts`, `preindustrial-profile-fixtures.ts`, its composition inside `Facilities`, and `seasonal-regional-economy.ts`.
