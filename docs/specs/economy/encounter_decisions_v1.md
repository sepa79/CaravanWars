# Encounter Decisions v1

Status: active.

An expedition encounter is a scheduled WorldClock event which becomes an `awaiting_decision` pause for the defender Party. The authorized human or AI controller sees the same affordances and submits the same command: `evade`, `retreat`, `negotiate`, `pay_ransom`, `surrender_cargo`, `fight`, or `continue` when safe.

Resolution is deterministic from the simulation seed and encounter ID plus physical Party composition, active characters, health, fatigue, morale, roles, equipment, animals, vehicles and cargo. A decision creates one atomic mutation of cargo/currency, casualties, wounds, fatigue, morale, retreat delay and possible vehicle abandonment. It writes a private result observation and a route-risk incident. Duplicate commands/events are inert.

V1 deliberately uses an aggregate resolver rather than a tactical battle map. It does not grant clients or AI truth-state access.
