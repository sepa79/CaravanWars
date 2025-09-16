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
set CI_AUTO_QUIT=1
call :run_logged_command "Running --check-only" "%GODOT%" --headless --check-only --path "%PROJECT_DIR%"
if errorlevel 1 exit /b %errorlevel%

if /I "%MODE%"=="check" goto :done
if /I "%MODE%"=="quick" goto :quick
if /I "%MODE%"=="both" goto :quick

echo [check] Unknown mode: %MODE% (use: check^|quick^|both)
exit /b 2

:quick
call :run_logged_command "Running quick boot (1 frame)" "%GODOT%" --headless --quit-after 1 --path "%PROJECT_DIR%"
if errorlevel 1 exit /b %errorlevel%
set "CI_AUTO_QUIT="
set "MAP_SMOKE_TEST=1"
call :run_logged_command "Running map smoke test" "%GODOT%" --headless --path "%PROJECT_DIR%"
if errorlevel 1 (
  set "MAP_SMOKE_TEST="
  exit /b %errorlevel%
)
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

:run_logged_command
setlocal
set "DESC=%~1"
shift
if "%DESC%"=="" (
  endlocal & exit /b 0
)
echo [check] %DESC%
set "LOG_FILE=%TEMP%\godot_check_%RANDOM%%RANDOM%.log"
cmd /c "%* > "%LOG_FILE%" 2>&1"
set "EXIT_CODE=%ERRORLEVEL%"
type "%LOG_FILE%"
if not "%EXIT_CODE%"=="0" (
  echo [check] Error: Command failed during %DESC% (exit %EXIT_CODE%).
  del "%LOG_FILE%" >nul 2>&1
  endlocal & exit /b %EXIT_CODE%
)
findstr /R /C:"^[ ]*WARNING:" /C:"^[ ]*ERROR:" /C:"^[ ]*SCRIPT ERROR:" "%LOG_FILE%" >nul
if not errorlevel 1 (
  echo [check] Error: Godot reported warnings/errors during %DESC%.
  del "%LOG_FILE%" >nul 2>&1
  endlocal & exit /b 1
)
del "%LOG_FILE%" >nul 2>&1
endlocal & exit /b 0

