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

$DbPath = Join-Path $env:TEMP ("cw_world_memory_supply_loop_" + [guid]::NewGuid().ToString() + ".sqlite3")
$OutLog = Join-Path $env:TEMP ("cw_world_memory_supply_loop_" + [guid]::NewGuid().ToString() + ".out.log")
$ErrLog = Join-Path $env:TEMP ("cw_world_memory_supply_loop_" + [guid]::NewGuid().ToString() + ".err.log")
$GodotOutLog = Join-Path $env:TEMP ("cw_supply_loop_godot_" + [guid]::NewGuid().ToString() + ".out.log")
$GodotErrLog = Join-Path $env:TEMP ("cw_supply_loop_godot_" + [guid]::NewGuid().ToString() + ".err.log")

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

    $GodotProcess = Start-Process `
        -FilePath $Godot `
        -ArgumentList @("--headless", "--path", "game", "-s", "tests/SupplyLoopWorldMemoryIntegrationTest.gd") `
        -WorkingDirectory $Root `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput $GodotOutLog `
        -RedirectStandardError $GodotErrLog
    if (-not $GodotProcess.WaitForExit(90000)) {
        Stop-Process -Id $GodotProcess.Id -Force
        if (Test-Path $GodotOutLog) { Get-Content $GodotOutLog }
        if (Test-Path $GodotErrLog) { Get-Content $GodotErrLog }
        throw "Supply loop WorldMemory integration timed out."
    }
    $GodotProcess.Refresh()
    if ($null -ne $GodotProcess.ExitCode -and $GodotProcess.ExitCode -ne 0) {
        if (Test-Path $GodotOutLog) { Get-Content $GodotOutLog }
        if (Test-Path $GodotErrLog) { Get-Content $GodotErrLog }
        throw "Supply loop WorldMemory integration failed with exit code $($GodotProcess.ExitCode)."
    }

    $WorldEvents = Get-MemoryEntries "http://127.0.0.1:8011/world-events?limit=200"
    $MayorMemory = Get-MemoryEntries "http://127.0.0.1:8011/owners/mayor_wroclaw/memory?limit=100"
    $CityMemory = Get-MemoryEntries "http://127.0.0.1:8011/owners/wroclaw_city/memory?limit=100"
    $SupplyMemory = Get-MemoryEntries "http://127.0.0.1:8011/owners/wroclaw_supply_party_01/memory?limit=100"

    $NeedLedgers = @($CityMemory | Where-Object { $_.kind -eq "need_ledger" })
    $MayorIntents = @($MayorMemory | Where-Object { $_.kind -eq "mayor_supply_intent" })
    $ActiveOrders = @($MayorMemory | Where-Object { $_.kind -eq "order_ledger" -and $_.metadata.status -eq "active" })
    $CompletedOrders = @($MayorMemory | Where-Object { $_.kind -eq "order_ledger" -and $_.metadata.status -eq "completed" })
    $CityDeposits = @($CityMemory | Where-Object { $_.kind -eq "direct_observation" -and $_.metadata.direction -eq "deposit_to_location" -and $_.metadata.goods_id -eq "food" })
    $SupplyCompletedOrders = @($SupplyMemory | Where-Object { $_.kind -eq "order_ledger" -and $_.metadata.status -eq "completed" })

    if ($NeedLedgers.Count -le 0) {
        throw "Expected city need_ledger from supply loop."
    }
    if ($MayorIntents.Count -le 0) {
        throw "Expected mayor_supply_intent from supply loop."
    }
    if ($ActiveOrders.Count -le 0) {
        throw "Expected active mayor order_ledger from supply loop."
    }
    if ($CompletedOrders.Count -le 0) {
        throw "Expected completed mayor order_ledger from supply loop."
    }
    if ($CityDeposits.Count -le 0) {
        throw "Expected city deposit observation from supply loop."
    }
    if ($SupplyCompletedOrders.Count -le 0) {
        throw "Expected supply party completed order ledger from supply loop."
    }

    [pscustomobject]@{
        world_events = $WorldEvents.Count
        mayor_memory = $MayorMemory.Count
        city_memory = $CityMemory.Count
        supply_memory = $SupplyMemory.Count
        need_ledger_entries = $NeedLedgers.Count
        mayor_supply_intents = $MayorIntents.Count
        active_order_ledgers = $ActiveOrders.Count
        completed_order_ledgers = $CompletedOrders.Count
        city_deposit_entries = $CityDeposits.Count
        supply_completed_orders = $SupplyCompletedOrders.Count
        db_path = $DbPath
    }
} finally {
    Remove-Item Env:\WORLD_MEMORY_DB_PATH -ErrorAction SilentlyContinue
    if ($Process -and -not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force
    }
}
