# Commands - CaravanWars Reboot

This file contains canonical commands for humans and AI agents.

Agents must prefer these commands over ad-hoc guesses.

## Requirements

- Godot 4.x.
- PowerShell on Windows for `tools/check.bat`.
- Bash on Unix-like shells for `tools/check.sh`.

## Install / bootstrap

```bash
git status --short
```

No package install step is currently defined.

## Build

```bash
godot --headless --path game --quit
```

No export preset is currently defined.

## Test

Windows:

```powershell
tools\check.bat
```

Unix-like shells:

```bash
tools/check.sh
```

## Focused test

For each modified GDScript file when Godot is available:

```bash
godot --headless --path game --check game/world/RegionGraph.gd
```

Replace the path with the modified `.gd` file.

Current focused test scripts:

```bash
godot --headless --path game --check-only -s tests/GraphSmokeTest.gd
godot --headless --path game --check-only -s tests/PartyTravelCommandTest.gd
godot --headless --path game --check-only -s tests/TravelIntentCommandTest.gd
godot --headless --path game --check-only -s tests/PartyCargoTest.gd
godot --headless --path game --check-only -s tests/TransferGoodsCommandTest.gd
godot --headless --path game --check-only -s tests/MemoryFreshnessPolicyTest.gd
godot --headless --path game --check-only -s tests/ActorTaskStateTest.gd
godot --headless --path game --check-only -s tests/ReportBackCommandTest.gd
godot --headless --path game --check-only -s tests/AskLocalInformationCommandTest.gd
godot --headless --path game --check-only -s tests/SimulationSaveCodecTest.gd
godot --headless --path game --check-only -s tests/ManagedWorldPartiesTest.gd
godot --headless --path game --check-only -s tests/PartyOrdersTest.gd
godot --headless --path game --check-only -s tests/LocationStateTest.gd
godot --headless --path game --check-only -s tests/GoodsCatalogTest.gd
godot --headless --path game --check-only -s tests/LocationEconomyTest.gd
godot --headless --path game --check-only -s tests/MerchantAutoplayScenarioTest.gd
godot --headless --path game --check-only -s tests/MerchantMemoryAITest.gd
godot --headless --path game --check-only -s tests/MayorFoodManagerTest.gd
godot --headless --path game --check-only -s tests/MayorSupplyPlannerTest.gd
godot --headless --path game --check-only -s tests/QuartermasterAITest.gd
godot --headless --path game --check-only -s tests/WorldMemoryEventExportTest.gd
godot --headless --path game --check-only -s tests/WorldSimObservationTest.gd
godot --headless --path game --check-only -s tests/PartyKnowledgeSnapshotTest.gd
godot --headless --path game --check-only -s tests/DebugTravelPanelTest.gd
godot --headless --path game -s tests/PartyTravelCommandTest.gd
godot --headless --path game -s tests/TravelIntentCommandTest.gd
godot --headless --path game -s tests/PartyCargoTest.gd
godot --headless --path game -s tests/TransferGoodsCommandTest.gd
godot --headless --path game -s tests/MemoryFreshnessPolicyTest.gd
godot --headless --path game -s tests/ActorTaskStateTest.gd
godot --headless --path game -s tests/ReportBackCommandTest.gd
godot --headless --path game -s tests/AskLocalInformationCommandTest.gd
godot --headless --path game -s tests/SimulationSaveCodecTest.gd
godot --headless --path game -s tests/ManagedWorldPartiesTest.gd
godot --headless --path game -s tests/PartyOrdersTest.gd
godot --headless --path game -s tests/LocationStateTest.gd
godot --headless --path game -s tests/GoodsCatalogTest.gd
godot --headless --path game -s tests/LocationEconomyTest.gd
godot --headless --path game -s tests/MerchantAutoplayScenarioTest.gd
godot --headless --path game -s tests/MerchantMemoryAITest.gd
godot --headless --path game -s tests/MayorFoodManagerTest.gd
godot --headless --path game -s tests/MayorSupplyPlannerTest.gd
godot --headless --path game -s tests/QuartermasterAITest.gd
godot --headless --path game -s tests/WorldMemoryEventExportTest.gd
godot --headless --path game -s tests/WorldSimObservationTest.gd
godot --headless --path game -s tests/PartyKnowledgeSnapshotTest.gd
godot --headless --path game -s tests/DebugTravelPanelTest.gd
```

WorldMemory service focused test:

```powershell
services\world_memory\.venv\Scripts\python.exe -m unittest services.world_memory.test_domain_ingest
```

Optional merchant-to-WorldMemory integration test. This starts `services/world_memory` on a temporary SQLite database, exports merchant simulation payloads from Godot, ingests them through HTTP, and verifies memory entries:

```powershell
tools\run_merchant_world_memory_integration.ps1
```

Optional quartermaster-to-WorldMemory integration test. This starts `services/world_memory` on a temporary SQLite database, exports a local information query from Godot, ingests it through HTTP, and verifies the supply party can receive `local_information` memory:

```powershell
tools\run_quartermaster_world_memory_integration.ps1
```

Optional mayor supply planner-to-WorldMemory integration test. This starts `services/world_memory`, ingests a mayor need, runs the quartermaster report-back flow, writes mayor memory to a temporary JSON file, and verifies `MayorSupplyPlanner` uses that memory without duplicating fresh active orders:

```powershell
tools\run_mayor_supply_planner_world_memory_integration.ps1
```

Optional full supply-loop WorldMemory integration test. This starts `services/world_memory`, runs mayor need declaration, mayor supply planning, quartermaster procurement travel, withdraw, return, deposit, and verifies WorldMemory contains need, intent, active order, completed order, and deposit memory:

```powershell
tools\run_supply_loop_world_memory_integration.ps1
```

## Lint / format / static checks

Windows:

```powershell
tools\check.bat
```

Unix-like shells:

```bash
tools/check.sh
```

## Run locally

```bash
godot --path game
```

## Debug / inspect

```bash
godot --headless --path game --check game/tests/GraphSmokeTest.gd
```

## Package / release

```bash
# No package/release command is defined yet.
```

## Deployment

```bash
# No deployment command is defined yet.
```

## Known command caveats

- `godot` must be on `PATH` for headless checks.
- `tools/check.bat` and `tools/check.sh` are the repo-level check entry points.
- Do not invent export or deployment commands until export presets are added.

## Agent command rules

- Do not invent commands when this file is incomplete.
- If a command is missing, inspect the repo and add a `TODO:` with likely location.
- Capture command output in evidence when preparing PRs or reviews.
