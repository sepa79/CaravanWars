# Seasonal Regional Economy v1 verification

Verified on 2026-07-26 with Node 22.22.3 and the explicit
`seasonal-silesia-v1` fixture.

Commands:

```bash
npm run sim:seasonal -- --years 2 --seeds 3,5,17 --merchants 12
npm run sim:seasonal -- --years 5 --seeds 23 --merchants 12
npm run sim:seasonal -- --years 10 --seeds 31 --merchants 12
```

The three-seed runs completed deterministically. Population v1 adds ten
seasonal cohort processes, so each run retains 30 pending events (ten profile
processes, ten cohort needs, ten population ticks). A five-year/three-seed run
completed in about 19 seconds with 8,571 records in the sampled result. A
ten-year run completed with 30 pending events and 17,201 retained records.
This demonstrates bounded
pending work and documented linear history growth. No inventory was negative,
and save-mid-cycle continuation is covered by the automated replay test.

The non-binding fixture is not balance evidence. Aggregate outcomes vary only
where the seed-dependent actor ordering encounters contested affordances; an
equal aggregate is valid and does not imply shared knowledge or deterministic
identity ordering.
