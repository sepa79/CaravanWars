# Trade Hub v0

## Purpose

Trade Hub v0 is a reusable deterministic local exchange for CaravanWars and
future simulations such as MarsKolony. Every hub is a concrete instance at one
physical node with its own warehouse, accounts, order book, and Governance
record. Goods deposited at one hub never become available at another hub.

## State

A hub stores a stable id, physical node id, owner, optional governor, explicit
connected Facility host ids, per-good warehouse capacities and inventory,
local participant accounts, ordered offers, monotonic ordinals, processed
command results, and processed scheduled-event ids.

Accounts separate available and escrowed goods and currency. Currency is an
abstract local integer balance in v0. It is not a goods-catalog item and never
moves implicitly between hubs. Initial balances are fixture/save data; banking,
credit, and cross-hub clearing are out of scope.

## Physical transfers

`trade_hub_transfer_party_goods` deposits from or withdraws to an idle party at
the hub node. WorldSimulation validates party position, cargo, carrying
capacity, catalog membership, Governance scope, hub capacity, and account stock
before applying both physical stores atomically.

`trade_hub_transfer_facility_goods` moves goods from a specifically connected
Facility host into a local hub account. WorldSimulation validates Governance,
the explicit connection, local Facility stock, and hub capacity before commit.

## Offers, escrow, and matching

`place_trade_hub_order` contains stable command/order ids, issuer, governed
account entity id, hub, side, goods, positive integer quantity, positive safe
integer limit price, and optional future expiry time.

- Sell placement moves the full quantity from available goods to goods escrow.
- Buy placement moves `quantity * limitPrice` from available currency to
  currency escrow.
- Accepted placement schedules serializable `TradeHubMatchDue` data. Optional
  expiry schedules `TradeHubOrderExpiryDue`; WorldClock stores no callbacks.

Matching selects the highest buy and lowest sell. Equal prices use stable offer
placement order. A crossing executes at the older resting offer's explicit
limit price. Full and partial fills update both escrows and accounts atomically;
buy-side price improvement is returned immediately.

## Cancellation, expiry, and ordering

`cancel_trade_hub_order` releases only remaining escrow. An open/partial offer
can become cancelled or expired exactly once; later cancellation cannot refund
again.

Expiry and matching are ordinary WorldClock intents ordered only by due time
and scheduling sequence. There are no kind priorities or phases. If expiry was
scheduled first at a timestamp, matching sees an expired offer. If matching was
scheduled first, it may fill before expiry.

## Authorization and idempotency

Every command identifies an issuer and governed account/facility entity.
WorldSimulation checks the applicable `trade:transfer`, `trade:order`, or
`trade:cancel` scope through Governance. Authority grants neither remote
communication nor market knowledge.

Every TradeHub command has a non-empty command id. The hub persists its
canonical payload fingerprint and result. Repeating the same id/payload returns
that result without mutation; reusing an id with another payload fails.
Scheduled-event ids are also retained and applied at most once.

All validation precedes mutation. Rejections, capacity failures, missing stock,
authorization failures, and malformed scheduled data are explicit. There are
no partial settlements, implicit retries, fallback hubs, or compatibility
lookups.

## Save/load

Snapshots contain every hub, account balance, escrow, offer, ordinal, processed
command result, and processed scheduled-event id. Combined with canonical
WorldClock and WorldSimulation physical state, JSON round-trip must give an
identical deterministic continuation.

## Out of scope

- strategic merchant AI and WorldMemory market knowledge;
- fees, taxes, debt, banking, exchange rates, or price balancing;
- cross-hub clearing, remote pickup, hidden prices, and order amendments.

## Canonical implementation

`packages/world-sim/src/trade-hubs.ts` owns the runtime contract.
`simulation-foundation.ts` supplies WorldClock dispatch and Governance;
`WorldSimulation` remains the single physical command/state boundary.
