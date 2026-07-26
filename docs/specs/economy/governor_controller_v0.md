# Governor Controller v0

Status: active contract.

Governor is a normal Governance actor. `GovernorAIController` is pure and deterministic: its only inputs are the actor's `WorldMemoryOwnerView`, WorldSimulation-adjudicated legal supply affordances, and configured consequence weights. It cannot inspect truth state.

WorldSimulation converts only authorized Facility shortage events into private `shortage_observation` entries. The controller ignores stale memory, uses stable memory sequence as its tie-break, and may propose the normal `assign_supply_task` command. Execution checks Governance again.

Delegation v0 requires executor and managed Facility node to be co-located. The task enters private party memory with command provenance. Procurement uses existing TradeHub order, pickup, cargo, and travel commands. `deliver_supply_task` atomically moves actual party cargo into a connected Facility host. `report_supply_task` transfers only a completed result into the authorized Governor's memory with `report` provenance; the party must be idle at the physical handoff node.

Strategic planning, final severity balance, remote communications, and general organization messaging are deferred. V0 provides no telepathy or global inbox.

Autonomous Regional Economy v1 layers the canonical `LogisticsTaskBoard` over
accepted assignments. It supplies explicit created, accepted, in-progress,
completed, failed, and abandoned lifecycle without changing GovernorAI's
private-memory input boundary.
