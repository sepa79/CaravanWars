# Local LLM Role

## Rule

The LLM is not the simulation and does not own world truth.

The LLM is a language, interpretation, and presentation layer over deterministic simulation state. The game must remain playable without an LLM, with reduced flavor and simpler text.

Runtime LLM calls should go through a separate stateless LLM Service. The simulation prepares context, calls the service, validates the proposal, and writes accepted outcomes. The LLM Service should not directly fetch or mutate WorldMemory during normal gameplay. See `docs/architecture/LLM_SERVICE.md`.

## Player Character Speech

The player is the mind behind the character, not the raw voice of the character.

The player may express intent through:
- microphone input,
- mouse or UI intent choices,
- typed input,
- structured dialogue stance choices such as polite, direct, evasive, threatening, or vulgar.

The LLM turns that intent into an in-world line spoken by the player character.

That rendered line must be shaped by:
- the player's selected intent,
- character statistics such as diplomacy, knowledge, intelligence, intimidation, reputation, and social status,
- current emotional and physical state,
- local language, culture, and context,
- what the character plausibly knows,
- the current conversation partner and relationship.

The player can decide what they mean. The character sheet influences how well, how clearly, and in what style the character says it.

## Intent Adjudication

Raw player input is not the same thing as approved character intent.

The game needs an intent adjudication layer between player input and final LLM rendering. This layer may be implemented with a HiveMind-like multi-check process, but the important requirement is conceptual rather than tied to one implementation.

Reasons:
- players may use archaic, regional, class-based, religious, ethnic, or occupational insults,
- modern LLMs may misunderstand historically loaded terms,
- speech may contain irony, euphemism, threat, command, oath, taboo, or coded social meaning,
- the same words can mean different things depending on speaker status, target identity, region, and year,
- the game must know whether speech is a request, insult, threat, bribe, humiliation, accusation, command, or test of status.

The adjudication layer should convert raw input into structured intent before the dialogue renderer speaks for the character.

Example:

```json
{
  "raw_input": "dawaj parchu zryc, bo ubije",
  "literal_intent": "demand food under threat of violence",
  "social_intent": "humiliate and intimidate a Jewish innkeeper from a superior-status posture",
  "speech_act": "threat",
  "tone": "vulgar",
  "targets_identity": true,
  "identity_axis": "religion_ethnicity",
  "severity": "high",
  "approved_for_character": true,
  "approval_reason": "character/game rules allow vulgar intimidation in this situation",
  "renderer_instruction": "do not soften; preserve the hostile social meaning"
}
```

Only after this step should the LLM render or respond to the line.

If the adjudication layer is uncertain, it should ask for clarification, choose a conservative structured interpretation, or expose multiple candidate intents for selection. It should not silently flatten loaded language into a generic insult.

## Two-Level Control

The LLM must not be the gameplay censor.

There are two separate control layers:

1. LLM interpretation layer.
2. Game rule and publication-safety layer.

The LLM should interpret and render player intent, including rude, aggressive, threatening, deceptive, vulgar, prejudiced, cowardly, cruel, or submissive intent when the game context allows it. It should not refuse just because the speech is unpleasant.

The game decides whether the character can plausibly say or do the requested thing.

Examples:
- A lawful, honorable, or devout character may be unable or unwilling to threaten an innocent innkeeper with hanging.
- A cruel, chaotic, desperate, or powerful character may be able to threaten, extort, assault, burn, steal, or terrorize, subject to world consequences.
- A socially powerful actor with wealth, guards, legal privilege, or patronage may get away with actions that would destroy a poor wanderer.
- A frightened peasant, wary innkeeper, monk, guild master, guard, or noble should react through their own fear, status, loyalties, and memory.

This check belongs to deterministic game rules, not to the LLM.

## Hard Content Boundary

The setting may contain cruelty, class violence, prejudice, exploitation, war crimes, sexual violence, and other historical brutality as world facts, rumors, consequences, and character reputation.

The dialogue layer must not turn such material into explicit eroticized or exploitative scenes. When severe sexual violence or similar extreme material is relevant, represent it through high-level facts, aftermath, witness reports, fear, reputation, legal/social consequences, and memory.

The game should support dark historical simulation without depending on the LLM to produce shock content for its own sake.

## NPC Speech

NPCs use the LLM for:
- dialogue rendering,
- rumor wording,
- local descriptions,
- imperfect human communication,
- personality and tone.

NPCs are not fully simulated minds by default. Most NPCs are lightweight roles such as merchants, ferrymen, innkeepers, guards, monks, caravan leaders, mayors, guild masters, and commanders.

## Simulation-Owned Truth

Deterministic code owns:
- world graph state,
- cities and markets,
- caravans and groups,
- prices and inventories,
- travel times,
- roads, coordinates, and landmarks,
- military strength,
- weather state,
- rumor propagation,
- faction relations,
- actor knowledge and memory.

The LLM may describe, distort, or phrase this information through a human perspective. It must not invent authoritative facts.

## Rumors

Rumors are not a central registry of world claims.

Important NPCs and parties carry their own durable memory. An innkeeper, escort captain, merchant party, bandit group, priest, lord's retinue, or caravan leader can remember things independently. Ordinary guards or soldiers can remain lightweight unless the simulation promotes them to important actors.

Rumor spread is a memory transfer problem:
- an actor or party has memory entries,
- a meeting tick selects entries that may be shared,
- the listener receives copied entries with changed metadata,
- text is re-rendered only occasionally.

The cheap path is code-only:
- copy the memory text,
- increment hop count,
- adjust credibility, salience, freshness, repeat chance, and distortion,
- preserve source chain and meeting location/time.

The expensive LLM path is only used when useful:
- the rumor is about to be shown to the player,
- the rumor reaches an important NPC or party,
- distortion crosses a threshold,
- a decision model needs a readable version of memory.

Distortion should not mean "invent anything." It should usually select from allowed mutation types such as uncertain time, more or fewer wagons, hurry, trade goods, valuable goods, missing goods, toll increase, road watch, or suspicious patrol. This keeps rumors human and useful without forcing every hop through a full dialogue simulation.

Decision NPCs act on their own memory, not on global truth. A bandit leader may choose to shadow or ambush a caravan because his party heard a distorted rumor. The rumor does not make the cargo real; it changes what that party believes and does.

Background rumor work must not block the main game loop. Slow LLM jobs can finish later and apply only if their participants, location, time, and target are still valid.

Local model tests suggest this split:
- `mistral`: fastest useful background mutation model.
- `qwen3:8b`: better controlled JSON and conservative mutation.
- `phi4`: best English player-facing rumor renderer, slower but still usable.
- `llama3.1:8b`: valid but least useful in current tests.

Model switching is acceptable in batches, not per-request thrashing. Warm calls were commonly sub-second; switching to `phi4` or `qwen3:8b` cost roughly 2-4 seconds in local tests. Prefer queues such as many `mistral` background jobs, then a smaller `qwen3:8b` validation/control batch, then occasional `phi4` player-facing renders.

## Navigation Text

Code tracks:
- graph nodes and route edges,
- hidden coordinates,
- route waypoint chains,
- landmark visibility,
- travel state,
- off-road direction and uncertainty.

The LLM may render this as local directions, travel descriptions, and orientation hints. It should present the world as people in the setting understand it: incomplete, local, emotional, and unreliable.

## Command Boundary

LLM output that affects gameplay must be treated as a proposal, not a state mutation.

Examples:
- proposed dialogue line,
- proposed command intent,
- proposed negotiation stance,
- proposed rumor rendering,
- proposed local direction wording.

The authoritative simulation validates commands and owns outcomes. If the LLM proposes an impossible action, false fact, or invalid command, the simulation rejects it or asks for a safer rendering.
