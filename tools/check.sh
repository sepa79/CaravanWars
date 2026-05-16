#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT/game"

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
else
  GODOT="$(command -v godot || true)"
fi

if [[ -z "$GODOT" ]]; then
  echo "[check] Error: Godot binary not found. Set GODOT_BIN or add godot to PATH." >&2
  exit 1
fi

echo "[check] Using Godot: $GODOT"
echo "[check] Project: $PROJECT_DIR"

"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/GraphSmokeTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/PartyTravelCommandTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/TravelIntentCommandTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/PartyCargoTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/TransferGoodsCommandTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/ActorTaskStateTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/ReportBackCommandTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/AskLocalInformationCommandTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/SimulationSaveCodecTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/ManagedWorldPartiesTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/PartyOrdersTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/LocationStateTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/GoodsCatalogTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/LocationEconomyTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/MerchantAutoplayScenarioTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/MerchantMemoryAITest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/MayorFoodManagerTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/MayorSupplyPlannerTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/QuartermasterAITest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/WorldMemoryEventExportTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/WorldSimObservationTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/PartyKnowledgeSnapshotTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" --check-only -s tests/DebugTravelPanelTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/GraphSmokeTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/PartyTravelCommandTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/TravelIntentCommandTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/PartyCargoTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/TransferGoodsCommandTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/ActorTaskStateTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/ReportBackCommandTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/AskLocalInformationCommandTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/SimulationSaveCodecTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/ManagedWorldPartiesTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/PartyOrdersTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/LocationStateTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/GoodsCatalogTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/LocationEconomyTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/MerchantAutoplayScenarioTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/MerchantMemoryAITest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/MayorFoodManagerTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/MayorSupplyPlannerTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/QuartermasterAITest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/WorldMemoryEventExportTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/WorldSimObservationTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/PartyKnowledgeSnapshotTest.gd
"$GODOT" --headless --path "$PROJECT_DIR" -s tests/DebugTravelPanelTest.gd

echo "[check] OK"
