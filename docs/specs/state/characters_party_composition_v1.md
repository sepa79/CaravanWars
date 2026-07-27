# Characters & Party Composition v1

Status: active.

`CaravanExpeditions` is the canonical reusable character/expedition component. A character has stable identity, owner and actor, an optional Party assignment, a unique population source and settlement, labour equivalent, explicit roles, narrow skills, physical equipment, health, fatigue, morale and conditions. The same population source cannot be assigned twice to active Party characters. Active Party labour is an external reservation checked by the canonical population allocation command, so it cannot simultaneously be allocated to a Facility sector.

A Party remains the physical aggregate in `WorldSimulation`. Its characters, living animals, non-abandoned vehicles and cargo determine capability, capacity, road/off-road speed, discovery, provisions, retreat and encounter strength. Equipment and transport are records with stable IDs and condition, never implicit bonuses. Travel consumes accumulated food/fodder independent of clock step partitioning and changes fatigue. Death, wounds, rest and abandoned vehicles persist in saves.

Deferred: individual household simulation and full equipment inventory. Those extensions must retain one population truth and the normal command boundary.
