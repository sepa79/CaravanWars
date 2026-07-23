# Merchant autoplay scenario v0

## Purpose

`Merchant Autoplay Scenario v0` is the first automated integration scenario for travel, cargo, location resources, transfer commands, and deterministic manager behavior.

It is not full trade AI, pricing, bargaining, or economic planning. It is a technical harness proving that a manager can use existing authoritative commands to move a physical good between locations without direct state mutation. Production-direction merchant decisions should use `Merchant memory AI v0`.

## Owner / consumers

- Manager: `game/simulation/managers/MerchantFoodManager.gd`
- Scenario test: `game/tests/MerchantAutoplayScenarioTest.gd`

## Manager rule

The v0 manager only handles `food`.

On each processing step:

- if the party is missing or busy, do nothing;
- if the party carries food, travel to the known location with the lowest food;
- if the party carries food and is already at that location, deposit the food;
- if the party carries no food, compare the current location with known reachable locations;
- if another known location has lower food, withdraw a bounded amount from the current location and submit travel intent to that lower-food location.

The manager submits:

- `TransferGoodsCommand`
- `TravelIntentCommand`

It must not mutate party cargo, location resources, or party travel state directly.

## Scenario invariants

The test sets Opole as a food source and Wroclaw as a food shortage, then runs manager processing and simulation ticks for several days.

It verifies:

- location resources never become negative;
- party cargo stays valid and within capacity;
- `goods_transferred` is emitted;
- `party_travel_started` is emitted;
- `party_arrived` is emitted;
- food is deposited in Wroclaw;
- the merchant does not end in an invalid travel state.

## Compatibility notes

No compatibility is required during the reboot. This is a deterministic harness for catching integration regressions before richer manager logic exists.
