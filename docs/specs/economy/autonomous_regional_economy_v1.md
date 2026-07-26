# Autonomous Regional Economy v1

Status: active contract.

V1 is a deterministic headless orchestration layer over one canonical `WorldSimulation`. It composes WorldClock, Facilities, shortage consequences, Governance, local TradeHubs, private WorldMemory, GovernorAI, MerchantAI, and physical parties. It owns no second inventory, market, clock, or mutation API.

`AutonomousRegionalEconomyConfig` explicitly identifies its config id and integer seed, observation age, local Facility markets, Governor candidates and consequence weights, merchants, and route distances used only for metrics. The synthetic conformance fixture has Wroclaw, Opole, and Raciborz; food, leather, and tools; three Facilities/Hubs/cohorts/Governors/supply parties; and two competing merchants. Values prove mechanics, not balance.

Each day advances WorldClock, lets authorized local operators offer Facility output, adjudicates physically local observations, lets Governors propose non-duplicate tasks, advances each executor and independent merchant by at most one normal command, then dispatches matching. Strategic source choice uses only fresh party-owned market observations. Initial remote leads are delayed rumors with provenance. Later prices are learned locally. Stale leads cause no-action or abandonment, never truth lookup.

`LogisticsTaskBoard` owns `created -> accepted -> in_progress -> completed|failed|abandoned`. Transition ids are idempotent; conflicts fail. Only one non-terminal task may cover a `(destinationEntityId, goodsId)` pair. Terminal history is append-only, and a later observed shortage creates a new task instead of resurrecting one.

Run `npm run sim:regional -- --days 30 --seed 17`. Days are 1–180. Optional `--save path` writes the complete JSON snapshot; `--resume path` continues it. Stable metrics cover production, consumption, shortages/recoveries, trades/value, cargo/distance, unrest, throughput, pending queue, task counts, and failed commands.

Snapshots contain config, WorldSimulation state, task lifecycle, decisions, action ordinals, observation cursors, and route-observation state. Resume must equal uninterrupted continuation. Pending work and active tasks are bounded; terminal replay/idempotency history grows linearly. Compaction, final balance, credit, sophisticated routing, general couriers, perishability, and strategic AI are deferred.
