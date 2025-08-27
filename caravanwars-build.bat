@echo off
setlocal

:: --- KONFIG ---
set "GODOT_EXE=C:\Users\Sepa\Downloads\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe"
set "DST_DIR=C:\Users\Sepa\Documents\GoDot\CaravanWars"
set "SRC_DIR=%CD%"
:: -------------

echo [CaravanWars] Kill -> Clean -> Copy -> Import (Editor)

:: 0) ubij wszystkie poprzednie sesje Godota (editor / gra)
for %%P in (Godot_v4.4.1-stable_win64.exe godot4.exe Godot.exe) do (
  taskkill /F /IM "%%P" >nul 2>&1
)

:: 1) wyczyść docelowy
if exist "%DST_DIR%" rd /S /Q "%DST_DIR%"
mkdir "%DST_DIR%"

:: 2) skopiuj cały projekt
xcopy "%SRC_DIR%\*" "%DST_DIR%\" /E /I /Y /H >nul

:: 3) odpal edytor (import assetów)
pushd "%DST_DIR%"
start "" "%GODOT_EXE%" -e --path "%DST_DIR%"
popd

:: 4) zakończ sesję debug w VS Code - halucynacje GPT, nie dziala
exit
