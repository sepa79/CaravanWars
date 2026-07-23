@echo off
setlocal enabledelayedexpansion

REM Godot headless check for Windows.
REM Usage: tools\check.bat [project_dir=. ] [mode]
REM mode: check (default) | quick | both

set "PROJECT_DIR=%~1"
if "%PROJECT_DIR%"=="" set "PROJECT_DIR=."
set "MODE=%~2"
if "%MODE%"=="" set "MODE=check"

REM Resolve Godot binary: prefer GODOT_EXE, else PATH entries
if not "%GODOT_EXE%"=="" (
  set "GODOT=%GODOT_EXE%"
) else (
  for %%P in (godot4.exe godot.exe) do (
    where %%P >nul 2>&1 && (
      set "GODOT=%%P"
      goto :found
    )
  )
)

:found
if "%GODOT%"=="" (
  echo [check] Error: Godot binary not found. Set GODOT_EXE or add godot4.exe/godot.exe to PATH.
  exit /b 1
)

echo [check] Using Godot: %GODOT%
echo [check] Project: %PROJECT_DIR%
echo [check] Running --check-only
set CI_AUTO_SINGLEPLAYER=1
set CI_AUTO_QUIT=1
"%GODOT%" --headless --check-only --path "%PROJECT_DIR%"

if /I "%MODE%"=="check" goto :done
if /I "%MODE%"=="quick" goto :quick
if /I "%MODE%"=="both" goto :quick

echo [check] Unknown mode: %MODE% (use: check^|quick^|both)
exit /b 2

:quick
echo [check] Running quick boot (1 frame)
"%GODOT%" --headless --quit-after 1 --path "%PROJECT_DIR%"

:done
echo [check] OK
exit /b 0

