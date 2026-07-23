$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$ServiceDir = Join-Path $Root "services\world_memory"
$Python = Join-Path $ServiceDir ".venv\Scripts\python.exe"
$Godot = $env:GODOT_EXE
if ([string]::IsNullOrWhiteSpace($Godot)) {
    $Godot = Join-Path $env:USERPROFILE "Downloads\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe"
}

if (-not (Test-Path $Python)) {
    throw "WorldMemory venv Python not found: $Python"
}
if (-not (Test-Path $Godot)) {
    throw "Godot binary not found. Set GODOT_EXE or add the expected local binary."
}

$DbPath = Join-Path $env:TEMP ("cw_world_memory_mayor_" + [guid]::NewGuid().ToString() + ".sqlite3")
$OutLog = Join-Path $env:TEMP ("cw_world_memory_mayor_" + [guid]::NewGuid().ToString() + ".out.log")
$ErrLog = Join-Path $env:TEMP ("cw_world_memory_mayor_" + [guid]::NewGuid().ToString() + ".err.log")
$MayorMemoryFile = Join-Path $env:TEMP ("cw_mayor_memory_" + [guid]::NewGuid().ToString() + ".json")
$QuartermasterOutLog = Join-Path $env:TEMP ("cw_mayor_quartermaster_godot_" + [guid]::NewGuid().ToString() + ".out.log")
$QuartermasterErrLog = Join-Path $env:TEMP ("cw_mayor_quartermaster_godot_" + [guid]::NewGuid().ToString() + ".err.log")
$PlannerOutLog = Join-Path $env:TEMP ("cw_mayor_planner_godot_" + [guid]::NewGuid().ToString() + ".out.log")
$PlannerErrLog = Join-Path $env:TEMP ("cw_mayor_planner_godot_" + [guid]::NewGuid().ToString() + ".err.log")

function Get-MemoryEntries {
    param([string]$Uri)

    $Response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
    $Parsed = $Response.Content | ConvertFrom-Json
    $Entries = New-Object System.Collections.ArrayList
    foreach ($Entry in $Parsed) {
        [void]$Entries.Add($Entry)
    }
    return @($Entries)
}

$env:WORLD_MEMORY_DB_PATH = $DbPath
$Process = Start-Process `
    -FilePath $Python `
    -ArgumentList @("-m", "uvicorn", "app:app", "--host", "127.0.0.1", "--port", "8011") `
    -WorkingDirectory $ServiceDir `
    -WindowStyle Hidden `
    -PassThru `
    -RedirectStandardOutput $OutLog `
    -RedirectStandardError $ErrLog

try {
    $Ready = $false
    for ($Index = 0; $Index -lt 50; $Index++) {
        if ($Process.HasExited) {
            break
        }
        try {
            $Health = Invoke-RestMethod -Uri "http://127.0.0.1:8011/health" -TimeoutSec 1
            if ($Health.ok -eq "true") {
                $Ready = $true
                break
            }
        } catch {
            Start-Sleep -Milliseconds 200
        }
    }
    if (-not $Ready) {
        if (Test-Path $ErrLog) {
            Get-Content $ErrLog
        }
        throw "WorldMemory service did not become ready."
    }

    $NeedEvent = @{
        world_event = @{
            id = "evt_mayor_need_integration_001"
            event_type = "location_need_declared"
            text = "Wroclaw needs food."
            location_id = "wroclaw_city"
            occurred_at = "day:0.000"
            importance = 0.7
            reliability = 1.0
            tags = @("simulation", "location_need_declared", "wroclaw_city", "food")
            metadata = @{
                location_id = "wroclaw_city"
                manager_actor_id = "mayor_wroclaw"
                node_id = "wroclaw"
                goods_id = "food"
                current_amount = 20
                desired_amount = 60
                needed_amount = 40
                reason = "food_below_floor"
                occurred_day = 0.0
            }
        }
    } | ConvertTo-Json -Depth 8
    Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8011/domain-events/ingest" -ContentType "application/json" -Body $NeedEvent | Out-Null

    $GodotProcess = Start-Process `
        -FilePath $Godot `
        -ArgumentList @("--headless", "--path", "game", "-s", "tests/QuartermasterWorldMemoryIntegrationTest.gd") `
        -WorkingDirectory $Root `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput $QuartermasterOutLog `
        -RedirectStandardError $QuartermasterErrLog
    if (-not $GodotProcess.WaitForExit(60000)) {
        Stop-Process -Id $GodotProcess.Id -Force
        if (Test-Path $QuartermasterOutLog) { Get-Content $QuartermasterOutLog }
        if (Test-Path $QuartermasterErrLog) { Get-Content $QuartermasterErrLog }
        throw "Quartermaster WorldMemory HTTP integration timed out."
    }
    $GodotProcess.Refresh()
    if ($null -ne $GodotProcess.ExitCode -and $GodotProcess.ExitCode -ne 0) {
        if (Test-Path $QuartermasterOutLog) { Get-Content $QuartermasterOutLog }
        if (Test-Path $QuartermasterErrLog) { Get-Content $QuartermasterErrLog }
        throw "Quartermaster WorldMemory HTTP integration failed with exit code $($GodotProcess.ExitCode)."
    }

    $MayorMemory = Get-MemoryEntries "http://127.0.0.1:8011/owners/mayor_wroclaw/memory?limit=50"
    $CityMemory = Get-MemoryEntries "http://127.0.0.1:8011/owners/wroclaw_city/memory?limit=50"
    $PlannerMemory = @($MayorMemory) + @($CityMemory)
    $NeedLedgers = @($PlannerMemory | Where-Object { $_.kind -eq "need_ledger" })
    $OrderLedgers = @($PlannerMemory | Where-Object { $_.kind -eq "order_ledger" })
    $Reports = @($MayorMemory | Where-Object { $_.kind -eq "heard_report" })
    if ($NeedLedgers.Count -le 0) {
        throw "Expected mayor need_ledger memory entry."
    }
    if ($OrderLedgers.Count -le 0) {
        throw "Expected mayor/city order_ledger memory entry."
    }
    if ($Reports.Count -le 0) {
        throw "Expected mayor heard_report memory entry."
    }

    $PlannerMemory | ConvertTo-Json -Depth 20 | Set-Content -Path $MayorMemoryFile -Encoding UTF8
    $env:CW_MAYOR_MEMORY_FILE = $MayorMemoryFile
    $PlannerProcess = Start-Process `
        -FilePath $Godot `
        -ArgumentList @("--headless", "--path", "game", "-s", "tests/MayorSupplyPlannerWorldMemoryIntegrationTest.gd") `
        -WorkingDirectory $Root `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput $PlannerOutLog `
        -RedirectStandardError $PlannerErrLog
    if (-not $PlannerProcess.WaitForExit(60000)) {
        Stop-Process -Id $PlannerProcess.Id -Force
        if (Test-Path $PlannerOutLog) { Get-Content $PlannerOutLog }
        if (Test-Path $PlannerErrLog) { Get-Content $PlannerErrLog }
        throw "Mayor supply planner WorldMemory integration timed out."
    }
    $PlannerProcess.Refresh()
    if ($null -ne $PlannerProcess.ExitCode -and $PlannerProcess.ExitCode -ne 0) {
        if (Test-Path $PlannerOutLog) { Get-Content $PlannerOutLog }
        if (Test-Path $PlannerErrLog) { Get-Content $PlannerErrLog }
        throw "Mayor supply planner WorldMemory integration failed with exit code $($PlannerProcess.ExitCode)."
    }

    [pscustomobject]@{
        mayor_memory = $MayorMemory.Count
        city_memory = $CityMemory.Count
        planner_memory = $PlannerMemory.Count
        need_ledger_entries = $NeedLedgers.Count
        order_ledger_entries = $OrderLedgers.Count
        heard_report_entries = $Reports.Count
        mayor_memory_file = $MayorMemoryFile
        db_path = $DbPath
    }
} finally {
    Remove-Item Env:\WORLD_MEMORY_DB_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:\CW_MAYOR_MEMORY_FILE -ErrorAction SilentlyContinue
    if ($Process -and -not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force
    }
}
