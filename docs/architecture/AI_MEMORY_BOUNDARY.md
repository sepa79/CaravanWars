# AI Memory Boundary

## Rule

AI agents do not have private memory in Godot.

Merchant AI, mayor AI, bandit AI, patrol AI, NPC decision LLMs, and future human-assist agents may base decisions only on:

- their own WorldMemory entries,
- their current directly managed physical state,
- legal commands available to them,
- immediate local affordances supplied by WorldSim.

They must not scan objective `server.state` to learn remote location resources, remote parties, global danger, prices, or events.

## Observation Flow

Observation is not free.

```text
Physical WorldSim state
-> observation rules using actor/party/location stats and context
-> WorldSim observation event
-> WorldMemory owner entry
-> AI decision context
-> command proposal
-> authoritative command validation
```

This keeps "what exists" separate from "what an actor knows".

## Godot Runtime Knowledge

Runtime party knowledge in Godot is only a local visibility and command-boundary helper. It is not durable memory and should not become AI belief state.

Examples:

- A party may know a route enough to submit a travel command.
- The same party's durable remembered sightings, shortages, rumors, and trade opportunities belong in WorldMemory.

## Deterministic AI

Deterministic manager code may inspect the entity it directly manages so it can submit legal commands. For example:

- a location manager can read its own location resources to declare a shortage;
- a party manager can read its own party cargo and current node;
- a test harness can set up state for scenario coverage.

Strategic choice must come from WorldMemory, not a global scan.

Current `MerchantFoodManager` is a technical scenario harness proving cargo/travel commands. `MerchantMemoryAI` is the first production-direction slice: it chooses food delivery actions from the merchant party's memory entries such as `need_ledger` and `location_observation`.

## LLM Planning

LLM decisions receive memory owned by the deciding actor or party, plus a bounded list of legal actions. LLM output is a proposal. It may not mutate resources, movement, cargo, party knowledge, or memory directly.

Accepted proposals must become normal commands or explicit WorldMemory writes owned by the orchestrating simulation layer.
