@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "REPO_ROOT=%%~fI"

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
call :run_changed_checks
if errorlevel 1 exit /b %errorlevel%
echo [check] Running --check-only
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
echo [check] Running map smoke test
set "CI_AUTO_QUIT="
set "MAP_SMOKE_TEST=1"
"%GODOT%" --headless --path "%PROJECT_DIR%"
set "MAP_SMOKE_TEST="

:done
echo [check] OK
exit /b 0

:run_changed_checks
set "PYTHON_BIN=%PYTHON_BIN%"
if not "%PYTHON_BIN%"=="" goto :have_python
for %%P in (python3.exe python.exe py.exe) do (
  where %%P >nul 2>&1 && (
    set "PYTHON_BIN=%%P"
    goto :have_python
  )
)
:have_python
if "%PYTHON_BIN%"=="" (
  echo [check] Warning: Python interpreter not found. Skipping per-script Godot checks.
  exit /b 0
)
if not exist "%SCRIPT_DIR%check_changed_gd.py" (
  echo [check] Warning: Missing helper script check_changed_gd.py; skipping per-script checks.
  exit /b 0
)
"%PYTHON_BIN%" "%SCRIPT_DIR%check_changed_gd.py" --project-dir "%PROJECT_DIR%" --repo-root "%REPO_ROOT%" --godot "%GODOT%"
exit /b %errorlevel%

