# Route Security, Bandits & Escorts v1 verification

Date: 2026-07-26

## Automated evidence

- `npm run check`: PASS — strict TypeScript and 97/97 Node tests.
- `npm run test:browser`: PASS — 6/6 Playwright tests. The reused dev
  WebSocket port emitted a non-fatal `24678 already in use` warning.
- `npm run sim:seasonal -- --years 3 --seeds 3,5,17 --merchants 12`: PASS.
  Every 1080-day run retained a stable 30 pending intents, linearly growing
  history (5059 records at year three), one conserved-cargo ambush, completed
  patrol/escort response tasks, and no runaway encounter/task queues.
- `git diff --check`: PASS before checkpoint.

## Reviewer hat

- Confirmed one canonical WorldCommandEnvelope and WorldSimulation physical
  state; RouteSecurity owns no duplicate cargo or travel state.
- Confirmed graph/Party references are validated when the composition boundary
  is created and pending encounters survive JSON save/load.
- Confirmed Party Map remains actor-filtered and route-security truth is added
  only to explicitly labelled TRUTH diagnostics.
- Confirmed archive code is not imported.

## Jester hat

- Exercised unauthorized commands, insufficient labour, duplicate active
  tasks, invalid lifecycle, duplicate command/event replay, stale/foreign
  memory, non-physical participants, cargo conservation and save mid-encounter.
- Hardened distinct participants, positive bandit supplies, missing escorts,
  atomic physical-port rejection, route/Party graph validation and endpoint
  report handoff.
- Confirmed WorldClock ordering has no event-kind priority and security work is
  bounded by stable identifiers plus duplicate-active guards.

## Explicit v1 limits

Encounter resolution is deliberately coarse and fixture values are not game
balance. The local authority office at a route endpoint is the v1 report
handoff boundary; courier travel beyond that endpoint and tactical combat are
deferred. Retained event history grows linearly by contract.
