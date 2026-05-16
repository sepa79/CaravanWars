# LLM Service

## Role

The LLM Service is separate from Godot and separate from WorldMemory.

It does not own simulation truth, durable memory, inventory, economy, travel, or actor state. It is a stateless language worker that receives prepared context and returns proposals.

## Orchestration

The runtime flow is:

```text
Simulation/Scheduler
-> pulls relevant context from WorldMemory
-> adds current game state and legal actions
-> calls LLM Service
-> validates the proposal
-> applies or rejects it
-> writes accepted consequences back to WorldMemory
```

The LLM Service should not directly fetch or write WorldMemory during normal gameplay. That keeps authority and debugging in the simulation layer.

Developer/debug tools may offer convenience calls that fetch memory by ID, but those are not the core game architecture.

## Responsibilities

The LLM Service can provide:
- rumor re-rendering,
- player intent parsing,
- player-character speech rendering,
- NPC or party decision proposals,
- delegated task report rendering,
- JSON repair or normalization.

All outputs are proposals. The simulation decides what is legal and persistent.

## Typical Requests

Rumor rendering:

```text
input: memory entry text, tags, distortion, allowed mutations, speaker/listener context
output: rewritten rumor text, used mutations, warnings
```

NPC decision:

```text
input: actor/party memory, current local state, available actions
output: chosen action proposal, reason, risk, confidence
```

Player intent:

```text
input: raw player speech, character sheet, location affordances, stance
output: structured intent
```

Report rendering:

```text
input: deterministic task result
output: short in-character report without changing facts
```

## Backend Strategy

Current local model roles:
- `mistral`: fast background text mutation.
- `qwen3:8b`: conservative JSON/control tasks.
- `phi4`: better English player-facing text.

Use batched queues instead of alternating models per request:

```text
many mistral jobs
then qwen3:8b control jobs
then occasional phi4 player-facing jobs
```

OpenAI or another cloud backend can be added behind the same service contract later.
