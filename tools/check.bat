@echo off
setlocal

set "ROOT=%~dp0.."
set "PROJECT_DIR=%ROOT%\game"

if not "%GODOT_EXE%"=="" (
  set "GODOT=%GODOT_EXE%"
) else (
  for %%P in (godot4.exe godot.exe Godot.exe Godot_v4.4.1-stable_win64.exe) do (
    where %%P >nul 2>&1 && (
      set "GODOT=%%P"
      goto :found
    )
  )
)

:found
if "%GODOT%"=="" (
  if exist "%USERPROFILE%\Downloads\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" (
    set "GODOT=%USERPROFILE%\Downloads\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe"
  )
)

if "%GODOT%"=="" (
  echo [check] Error: Godot binary not found. Set GODOT_EXE or add Godot to PATH.
  exit /b 1
)

echo [check] Using Godot: %GODOT%
echo [check] Project: %PROJECT_DIR%

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/GraphSmokeTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/PartyTravelCommandTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/TravelIntentCommandTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/PartyCargoTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/TransferGoodsCommandTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/ActorTaskStateTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/ReportBackCommandTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/AskLocalInformationCommandTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/SimulationSaveCodecTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/ManagedWorldPartiesTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/PartyOrdersTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/LocationStateTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/GoodsCatalogTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/LocationEconomyTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/MerchantAutoplayScenarioTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/MerchantMemoryAITest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/MayorFoodManagerTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/MayorSupplyPlannerTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/QuartermasterAITest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/WorldMemoryEventExportTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/WorldSimObservationTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/PartyKnowledgeSnapshotTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" --check-only -s tests/DebugTravelPanelTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/GraphSmokeTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/PartyTravelCommandTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/TravelIntentCommandTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/PartyCargoTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/TransferGoodsCommandTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/ActorTaskStateTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/ReportBackCommandTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/AskLocalInformationCommandTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/SimulationSaveCodecTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/ManagedWorldPartiesTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/PartyOrdersTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/LocationStateTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/GoodsCatalogTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/LocationEconomyTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/MerchantAutoplayScenarioTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/MerchantMemoryAITest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/MayorFoodManagerTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/MayorSupplyPlannerTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/QuartermasterAITest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/WorldMemoryEventExportTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/WorldSimObservationTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/PartyKnowledgeSnapshotTest.gd
if errorlevel 1 exit /b 1

"%GODOT%" --headless --path "%PROJECT_DIR%" -s tests/DebugTravelPanelTest.gd
if errorlevel 1 exit /b 1

echo [check] OK
exit /b 0
