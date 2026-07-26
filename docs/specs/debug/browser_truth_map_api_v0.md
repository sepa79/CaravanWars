# Browser Truth Map API v0

## Purpose

This development-only HTTP boundary connects the browser Canvas Truth Map to
the authoritative TypeScript simulation. It proves that normal travel uses the
same command/state boundary intended for local singleplayer and multiplayer.

It is not a production network protocol and not the actor-facing parchment map.

## Owner / consumers

- Owner: `apps/truth-map`.
- Consumer: browser Truth Map client.
- Authority: `packages/world-sim` remains the only gameplay state owner.

## Endpoints

### `GET /api/state?view_mode={party|truth}&party_id={id}`

`view_mode` is required. `truth` returns the full authored region graph and
authoritative world snapshot. `party` requires `party_id` and returns the
filtered `Party Map Snapshot v0`. An invalid mode or missing observer fails
explicitly; there is no default-to-truth behavior.

### `POST /api/commands/move-party`

Accepts the canonical `MovePartyCommand` shape from
`docs/specs/commands/move_party.md`. The server returns the explicit
`CommandResult` and the resulting state. Rejected commands do not mutate state.
The same required view query selects the returned state without changing the
canonical command body.

### `POST /api/time/advance`

Development-only host control:

```json
{
  "days": 0.25
}
```

`days` must be finite and positive. The browser auto-advance toggle submits
explicit one-hour increments; the core simulation has no hidden wall-clock
mapping.

### `POST /api/reset`

Resets the development scenario to its explicit seed state. It is not a
gameplay command and must not be exposed by a production server.

### Regional economy diagnostics

`GET /api/economy?view_mode=truth` returns the explicitly marked regional
economy truth/debug report. `POST /api/economy/advance?view_mode=truth` accepts
an integer `days` from 1 to 30. Both reject party mode. Party Map never embeds
regional metrics, task lists, decision reasons, or another owner's memory.

### `POST /api/ai/merchant-step`

Runs one deterministic Merchant Memory AI decision for the development
scenario. The host supplies explicit owner memory, the AI submits at most one
normal world command, and the response contains the decision and selected
actor-filtered or truth state. This is a development orchestration endpoint,
not a privileged gameplay mutation path.

## Validation and failure behavior

- JSON bodies are bounded to 64 KiB.
- Invalid bodies return an explicit request validation error.
- Unknown API routes return an explicit 404 response.
- There are no fallback routes, implicit command conversions, or direct client
  state mutations.

## Exposure

The truth-only regional diagnostic may include the seasonal calendar, profile
ids and process stages, winter reserves and annual reports. These fields are
debug truth and remain absent from Party Map snapshots.

Population totals, health/nutrition and labour allocations are also truth-only
diagnostics and remain absent from Party Map snapshots.

The v0 development host listens on port `4173` so it can be viewed over the
home LAN or configured WireGuard route. It exposes full world truth and has no
authentication. It must not be internet-published or reused as a production
transport.
