# Caravan Contracts v1

Status: active.

A contract names its issuer, contractor Party, physical pickup and delivery locations, goods, quantity, deadline, payment, collateral and required roles. Lifecycle is `offered -> accepted -> picked_up -> delivered -> completed`, or terminal `failed`/`abandoned`. Every transition has a stable transition/command ID.

Offer, acceptance, pickup, delivery and abandonment use `WorldCommandEnvelope` and Governance. Acceptance atomically places issuer payment and contractor collateral in escrow and schedules an ordinary deadline event. Pickup and delivery require the contractor Party at the named location, real local inventory, real Party cargo and sufficient capacity. Settlement releases escrow only with the physical delivery mutation. Failure returns unused payment and forfeits collateral to the issuer; terminal escrow is zero. Replayed command/event IDs do not apply effects twice.

No contract teleports goods, people, vehicles, currency or knowledge. Fixture prices and deadlines are configuration, not balance.
