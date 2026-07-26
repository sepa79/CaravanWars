# Seasonal Regional Economy v1 verification

Verified on 2026-07-26 with Node 22.22.3 and the explicit
`seasonal-silesia-v1` fixture.

Commands:

```bash
npm run sim:seasonal -- --years 2 --seeds 3,5,17 --merchants 12
npm run sim:seasonal -- --years 5 --seeds 23 --merchants 12
npm run sim:seasonal -- --years 10 --seeds 31 --merchants 12
```

The three-seed two-year batch completed deterministically. Each run retained
20 pending events (ten profile processes and ten cohort needs); year-one/year-two
history was 1,541/3,083 records after the bounded retry fixture adjustment.
The five-year run completed in about 4 seconds with 20 pending events and 7,709
retained terminal/event records. The ten-year run completed in about 14 seconds
with 20 pending events and 15,275 retained records. This demonstrates bounded
pending work and documented linear history growth. No inventory was negative,
and save-mid-cycle continuation is covered by the automated replay test.

The non-binding fixture is not balance evidence. Aggregate outcomes vary only
where the seed-dependent actor ordering encounters contested affordances; an
equal aggregate is valid and does not imply shared knowledge or deterministic
identity ordering.
