# CaravanWars LLM Service

Stateless local LLM worker for CaravanWars prototypes.

The service does not read or write WorldMemory during normal gameplay. The simulation/scheduler owns orchestration:

```text
Simulation
-> pulls context from WorldMemory
-> calls this LLM Service
-> validates proposal
-> applies or rejects in simulation
-> writes accepted results back to WorldMemory
```

## Role

Endpoints:

- `POST /render-rumor`
- `POST /npc-decision`
- `POST /render-report`
- `POST /parse-player-intent`
- `POST /raw`

Default local model roles:

```text
mistral   -> fast rumor rendering
qwen3:8b  -> decisions and intent parsing
phi4      -> player-facing reports/text
```

## Run

```powershell
cd C:\Users\Sepa\Downloads\CaravanWarsReboot\services\llm_service
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
.\.venv\Scripts\uvicorn app:app --host 127.0.0.1 --port 8013
```

API docs:

```text
http://127.0.0.1:8013/docs
```

## Example: Rumor Render

```powershell
$body = @{
  entry = @{
    text = "Miroslaw's caravan leaves for Opole tomorrow morning."
    tags = @("caravan", "miroslaw", "opole", "departure")
    distortion = 0.65
    hop_count = 3
  }
  speaker = @{ name = "Izaak"; role = "innkeeper" }
  listener = @{ name = "Boruta"; role = "bandit leader" }
  allowed_mutations = @("time_uncertain", "more_wagons", "hurry", "trade_goods", "valuable_goods")
  llm = @{ model = "mistral" }
} | ConvertTo-Json -Depth 8

Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8013/render-rumor" -ContentType "application/json" -Body $body
```

## Example: NPC Decision

```powershell
$body = @{
  actor = @{ id = "party_boruta"; persona = "cautious road predators, hungry for profit" }
  memory = @(
    @{ text = "Miroslaw's caravan leaves for Opole tomorrow morning."; credibility = 0.7; salience = 0.8; tags = @("caravan", "opole") },
    @{ text = "Two wagons are said to have vanished on the road to Opole."; credibility = 0.45; salience = 0.7; tags = @("opole_road", "danger") }
  )
  local_state = @{ men = 6; food = "low"; location = "near_opole_road" }
  available_actions = @("ignore", "sell_information", "scout_road", "shadow_caravan", "ambush_now", "set_ambush_after_scouting")
  llm = @{ model = "qwen3:8b" }
} | ConvertTo-Json -Depth 8

Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8013/npc-decision" -ContentType "application/json" -Body $body
```
