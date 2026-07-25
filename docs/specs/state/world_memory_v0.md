# WorldMemory v0

## Purpose

WorldMemory v0 is the reusable durable knowledge component for CaravanWars and
future simulations such as MarsKolony. It stores what a particular actor,
party, or location knows; it never owns physical truth, authorizes commands, or
provides a global rumor board.

## Ownership and entry shape

An owner is the explicit pair `ownerKind` (`actor`, `party`, or `location`) and
`ownerId`. Equal textual ids in different owner kinds do not share knowledge.
Each entry contains:

- deterministic `entryId` and append `sequence`;
- stable boundary `ingestId`;
- owner kind and id;
- setting-independent `kind` and JSON payload;
- `observedAtElapsedDays` and `knownAtElapsedDays`;
- explicit positive `staleAfterDays`, or null when aging is not applicable;
- provenance source type, stable source id, optional source owner, and optional
  physical node.

`observedAtElapsedDays` records when the underlying observation occurred.
`knownAtElapsedDays` records when this owner learned it and cannot be earlier.
Reports and rumors may therefore arrive later without rewriting their origin.

## Observation boundary

WorldSimulation adjudicates direct observations from physical state. The v0
local TradeHub observation requires an idle observer party at the hub node and
permits writes only to that party or its manager actor. It exposes a bounded
local market summary, the observer's own cargo, and its own local account; it
does not expose remote hubs or other participants' balances.

Observation is written to WorldMemory before it becomes an AI input:

```text
local physical truth
  -> WorldSimulation observation rules
  -> owner-scoped WorldMemory ingest
  -> owner view with explicit freshness
  -> MerchantAI proposal
  -> WorldCommandEnvelope and Governance
```

TradeHub command outcomes are ingested as owner-scoped `trade_command_result`
entries. This is observation of a submitted result, not a second mutation path.

## Aging and querying

Owner views require both owner kind and id plus authoritative elapsed time.
They include only entries already known at that time, preserve append sequence,
and derive `ageDays` and `freshness` (`fresh` or `stale`). Aging never silently
deletes or rewrites an entry. V0 has no automatic forgetting, confidence decay,
rumor distortion, indexing, or compaction policy.

V0 retains entries and processed-ingest records indefinitely. Hosts must treat
snapshot growth and eventual sequence exhaustion as observable capacity
concerns; retention/checkpoint policy is deferred until workload evidence
exists and must never silently discard private knowledge.

## Idempotency and atomicity

The canonical fingerprint of an ingest is key-order independent. Repeating the
same `ingestId` and payload returns the existing entry. Reusing it with another
payload returns `INGEST_ID_CONFLICT` without mutation. Batch ingest validates
all ids, payloads, and sequence capacity before appending any entry.

Entry ids are `memory:<sequence>` and order is the monotonic append sequence.
There is no wall clock, randomness, locale comparison, or implicit retry.

## Save/load and replay

The JSON snapshot stores the next sequence, entries, and processed-ingest
fingerprints. Loading validates owner scope, timestamps, deterministic ids,
ordering, fingerprints, and serializable payloads. JSON round-trip followed by
the same ingests or AI input must produce identical continuation.

## AI boundary

The TradeHub MerchantAI accepts only its party's `WorldMemoryOwnerView`, its
direct party state, and locally adjudicated TradeHub affordances. It does not
receive a WorldSimulation reference. Its output is a normal command proposal;
WorldSimulation and Governance remain authoritative.

## Canonical implementation

`packages/world-sim/src/world-memory.ts` owns the component contract.
`WorldSimulation.observeLocalTradeContext` owns direct observation adjudication.
`MerchantMemoryAI.decideTrade` owns the deterministic v0 policy over bounded
inputs.
