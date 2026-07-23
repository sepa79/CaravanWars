# Opportunity Policy v0

## Purpose

Opportunity policies describe optional local actions a party may evaluate while executing a primary order.

They are not second active orders. The primary order remains the only active directive, and any opportunity action must be bounded by explicit constraints.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: future MerchantAI, QuartermasterAI, MayorAI, player party automation, and LLM-assisted intent planners.

## Initial use case

A supply party leaves Wroclaw for Opole to procure food. Before leaving, it may carry surplus goods from Wroclaw to Opole if:

- cargo capacity remains after reserving space for the primary order,
- the party has budget or authority to carry those goods,
- the goods are not reserved for the city,
- the action does not delay the primary order beyond the allowed tolerance,
- the opportunity is known through the party's or manager's WorldMemory, not global simulation truth.

## Evaluation points

V0 opportunity checks should only happen at safe decision points:

- before leaving a location,
- after arriving at a location,
- after completing a local task,
- after receiving a new report or order.

An opportunity policy must not redirect travel by itself. Redirecting, replacing, suspending, or cancelling the primary order requires an explicit lifecycle command.

## Required constraints before implementation

Do not implement opportunistic cargo movement until these constraints exist:

- reserved cargo capacity for primary-order goods,
- reserved budget or authority for primary-order spending,
- ownership/permission checks for city stock,
- explicit max delay or no-delay rule,
- WorldMemory evidence shape for why the opportunity exists.

## Future examples

- Carry surplus goods from Wroclaw to Opole while already traveling there.
- Sell non-reserved cargo at the destination if there is known demand.
- Ask for information while waiting for loading or unloading.
- Carry a report or letter when already going to the recipient's location.

## Non-goals

- No global market scan.
- No hidden route changes.
- No second active order.
- No automatic override of mayor or quartermaster intent.
