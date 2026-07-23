# CaravanWars World Memory

Small local prototype for CaravanWars world, NPC, and conversation memory.

This service is separate from Godot. Godot or a dialogue test client can call it over HTTP, then pass the returned context to Ollama.

## Role

SQLite is the source of truth for:
- actors and their stats/persona,
- world facts and rumors,
- what each actor believes or knows,
- relationships between actors,
- conversation turns,
- searchable memory events.

The LLM does not write directly to truth. It may propose dialogue lines, summaries, or memory updates. The service records only accepted state.

## NPC And Party Memory

Rumors are stored as private memory entries owned by important NPCs or parties. There is no central rumor registry that every actor reads from.

Examples of memory owners:
- innkeeper,
- escort captain,
- merchant party,
- bandit party,
- caravan leader,
- local authority or retinue.

A tavern spreads information because its innkeeper and guests exchange memories. A bandit party acts on what its own memory says, even when that memory is wrong.

## Rumor Transfer

Most rumor spread should be cheap and not call an LLM:

1. Select shareable memory entries for a meeting tick.
2. Copy the entry into the listener's memory.
3. Update metadata such as credibility, salience, freshness, repeat chance, distortion, and hop count.
4. Preserve source chain, heard location, and heard time.

The text can remain unchanged for many hops. Re-render only when:
- the player will see or hear the rumor,
- an important NPC or party will make a decision from it,
- distortion crosses a threshold,
- the memory needs compression or cleanup.

Distortion should usually mean "how many allowed mutations may be used," not free invention. Useful mutation families include:
- uncertain time,
- more or fewer wagons,
- hurry,
- trade or valuable goods,
- higher price,
- delay,
- weak animal,
- missing goods,
- suspicion,
- patrol or toll collectors,
- uncertain threat.

Decision models should receive the deciding actor's own memory, not objective world truth.

## Local Model Learnings

Current local tests favor English internal memory text.

Observed roles:
- `mistral`: fastest useful background rumor mutation.
- `qwen3:8b`: controlled JSON and conservative mutation.
- `phi4`: best English player-facing rumor renderer, slower but stronger text.
- `llama3.1:8b`: valid but usually too bland or occasionally changes meaning.

Warm local calls were commonly sub-second. Switching models cost roughly 1-4 seconds depending on model. Use batched queues instead of alternating models per request:

```text
mistral queue: many cheap background memory mutations
qwen3:8b queue: controlled JSON or conservative decision jobs
phi4 queue: important/player-facing render jobs
```

## Control Layers

The LLM is not the gameplay censor. It should render player intent, including rude, aggressive, threatening, deceptive, vulgar, or cruel intent.

The game rule layer decides whether that intent fits the character and situation:
- character morality/personality/alignment,
- social status and legal protection,
- wealth, armed followers, and local power,
- fear, trust, respect, and reputation,
- witnesses and retaliation risk.

Extreme material can exist as high-level world facts, rumors, aftermath, reputation, or consequence. The memory service should store those facts without requiring the LLM to generate explicit exploitative scenes.

## Intent Adjudication

Do not pass raw player speech directly to the dialogue renderer as the only source of truth.

CaravanWars needs a HiveMind-like intent adjudication step. This can be one model, several models, rules plus model checks, or a later dedicated service. The requirement is that raw input is converted into structured intent before final dialogue rendering.

This matters because player language may include archaic insults, coded social meanings, class contempt, religious or ethnic hostility, threats, irony, euphemism, and local references that a general LLM may misunderstand.

The adjudicated payload should preserve meaning:

```json
{
  "raw_input": "dawaj parchu zryc, bo ubije",
  "literal_intent": "demand food under threat of violence",
  "social_intent": "humiliate and intimidate a Jewish innkeeper",
  "speech_act": "threat",
  "tone": "vulgar",
  "targets_identity": true,
  "identity_axis": "religion_ethnicity",
  "approved_for_character": true,
  "renderer_instruction": "do not soften"
}
```

The renderer should use this structure rather than guessing from raw text alone.

## Run

```powershell
cd C:\Users\Sepa\Downloads\CaravanWarsReboot\services\world_memory
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
.\.venv\Scripts\python seed_demo.py
.\.venv\Scripts\uvicorn app:app --reload --host 127.0.0.1 --port 8011
```

Useful endpoints:
- `GET /health`
- `GET /actors`
- `POST /actors`
- `POST /facts`
- `POST /known-facts`
- `POST /relationships`
- `POST /world-events`
- `GET /world-events`
- `POST /domain-events/ingest`
- `POST /world-events/{event_id}/remember`
- `POST /memory-entries`
- `GET /memory-entries`
- `GET /owners/{owner_id}/memory`
- `POST /memory-transfer`
- `POST /decision-context`
- `POST /conversations`
- `POST /conversations/{conversation_id}/turns`
- `POST /dialogue-context`
- `GET /memory-search?query=...`

## Domain Event Ingest

Use `POST /domain-events/ingest` for simulation events that should become WorldMemory state.

The endpoint stores one canonical `world_event`, then creates per-entity `memory_entries` for event types it understands. The `text` field is only a technical fallback. Gameplay, debug UI, and later LLM rumor rendering should primarily use structured `metadata`.

Current v0 mappings:

- `goods_transferred`: creates one party memory entry and one location memory entry.
- `location_economy_ticked`: creates one location memory entry.
- `location_need_declared`: creates one location memory entry.
- `mayor_supply_intent_declared`: creates one mayor actor memory entry and one location memory entry.
- `worldsim_location_observed`: creates one observer owner memory entry.
- `worldsim_party_observed`: creates one observer owner memory entry.
- `worldsim_route_waypoint_observed`: creates one observer owner route memory entry.
- `worldsim_local_information_received`: creates one asking party memory entry.
- `worldsim_memory_reported`: transfers entries from the reporting party owner to the recipient owner as `heard_report`.
- `party_travel_started`: creates one party memory entry.
- `party_arrived`: creates one party memory entry.
- `party_order_assigned`: creates order ledger entries for the recipient party, issuer actor, direct manager actor, and target location when present.
- `party_order_completed`: creates terminal order ledger entries for the recipient party, issuer actor, direct manager actor, and target location when present.

Example:

```json
{
  "world_event": {
    "id": "goods_transferred:merchant_party_01:day:1.000",
    "event_type": "goods_transferred",
    "text": "goods_transferred",
    "location_id": "opole_stronghold",
    "occurred_at": "day:1.000",
    "importance": 0.7,
    "reliability": 1.0,
    "tags": ["simulation", "goods_transferred", "food", "opole_stronghold", "merchant_party_01"],
    "metadata": {
      "party_id": "merchant_party_01",
      "location_id": "opole_stronghold",
      "goods_id": "food",
      "amount": 10,
      "direction": "withdraw_from_location"
    }
  }
}
```

For this event, `merchant_party_01` gets `owner_goods_delta = 10`, while `opole_stronghold` gets `owner_goods_delta = -10`, both linked to the same `source_event_id`.

`GET /memory-search` now searches `memory_entries`, not the older `memory_events` table. The older table remains for prototype conversation memory and compatibility with early demo helpers.

## Memory Transfer Example

Seed data includes Zenek, Izaak, and Boruta's party.

```powershell
$body = @{
  from_owner_id = "zenek_escort_captain"
  to_owner_id = "innkeeper_wroclaw_gate"
  location_id = "wroclaw_gate_inn"
  trust = 0.45
  listener_interest_tags = @("caravan", "opole", "money")
  max_entries = 2
  notes = "Evening tavern talk"
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8011/memory-transfer" -ContentType "application/json" -Body $body
```

Then inspect private memory:

```powershell
Invoke-RestMethod "http://127.0.0.1:8011/owners/innkeeper_wroclaw_gate/memory?limit=10"
```

The transfer does not call an LLM. It copies memory text and updates metadata such as credibility, salience, distortion, hop count, and source chain. LLM re-render can be added later for entries where `metadata.needs_rerender` is true.

## Report Back Example

Supply parties report back through the Godot `ReportBackCommand`, which emits `worldsim_memory_reported`. WorldMemory ingests that event and uses the same memory transfer path internally.

The direct HTTP transfer endpoint is still useful for service tests and debugging:

```powershell
$body = @{
  from_owner_id = "wroclaw_supply_party_01"
  to_owner_id = "mayor_wroclaw"
  to_owner_kind = "actor"
  location_id = "wroclaw_city"
  trust = 0.9
  listener_interest_tags = @("food", "wroclaw_city")
  max_entries = 3
  notes = "Supply party report back"
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8011/memory-transfer" -ContentType "application/json" -Body $body
```

`worldsim_memory_reported` creates `heard_report` entries and preserves structured metadata from the source memory. Messenger delivery, loyalty filters, and written report rules are later layers.

## Dialogue Test Flow

1. UI or speech-to-text captures the player's raw intent.
2. The client calls `POST /dialogue-context`.
3. The client sends context + intent to Ollama.
4. Ollama returns structured JSON:

```json
{
  "player_line": "Good host, what is said of the road to Opole?",
  "tone": "polite",
  "memory_updates": []
}
```

5. The client records accepted dialogue with `POST /conversations/{id}/turns`.
6. Accepted facts, rumors, or relationship changes are written through explicit endpoints.

## Ollama CLI Demo

After seeding the database and installing dependencies:

```powershell
.\.venv\Scripts\python dialogue_demo.py "zapytaj karczmarza grzecznie o plotki z drogi do Opola" --stance polite
```

The script:
- builds dialogue context from SQLite,
- calls local Ollama with `dolphin-mistral` by default,
- expects JSON,
- records the accepted player line as a conversation turn.

## Demo Context Request

```powershell
$body = @{
  player_actor_id = "player_caravan_leader"
  npc_actor_id = "innkeeper_wroclaw_gate"
  conversation_id = "demo_inn_opole_road"
  query = "Opole road rumors"
  limit = 8
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8011/dialogue-context" -ContentType "application/json" -Body $body
```
