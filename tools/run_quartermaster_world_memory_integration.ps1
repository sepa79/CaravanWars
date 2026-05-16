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

$DbPath = Join-Path $env:TEMP ("cw_world_memory_quartermaster_" + [guid]::NewGuid().ToString() + ".sqlite3")
$OutLog = Join-Path $env:TEMP ("cw_world_memory_quartermaster_" + [guid]::NewGuid().ToString() + ".out.log")
$ErrLog = Join-Path $env:TEMP ("cw_world_memory_quartermaster_" + [guid]::NewGuid().ToString() + ".err.log")

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
        -ArgumentList @("--headless", "--path", "game", "-s", "tests/QuartermasterWorldMemoryIntegrationTest.gd") `
        -WorkingDirectory $Root `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    if ($GodotProcess.ExitCode -ne 0) {
        throw "Quartermaster WorldMemory HTTP integration failed with exit code $($GodotProcess.ExitCode)."
    }

    $SupplyMemory = Invoke-RestMethod -Uri "http://127.0.0.1:8011/owners/wroclaw_supply_party_01/memory?limit=50"
    $MayorMemory = Invoke-RestMethod -Uri "http://127.0.0.1:8011/owners/mayor_wroclaw/memory?limit=50"
    $WorldEvents = Invoke-RestMethod -Uri "http://127.0.0.1:8011/world-events?limit=100"

    $LocalInformation = @($SupplyMemory | Where-Object { $_.kind -eq "local_information" })
    $OrderLedgers = @($SupplyMemory | Where-Object { $_.kind -eq "order_ledger" })

    if ($LocalInformation.Count -le 0) {
        throw "Expected supply party local_information memory entry."
    }
    if ($OrderLedgers.Count -le 0) {
        throw "Expected supply party order_ledger memory entry."
    }
    if ($MayorMemory.Count -le 0) {
        throw "Expected mayor order ledger memory entry."
    }

    $KnownSources = ($LocalInformation[0].metadata.known_source_locations | ForEach-Object { $_.location_id }) -join ","
    [pscustomobject]@{
        world_events = $WorldEvents.Count
        supply_memory = $SupplyMemory.Count
        mayor_memory = $MayorMemory.Count
        local_information_entries = $LocalInformation.Count
        order_ledger_entries = $OrderLedgers.Count
        known_sources = $KnownSources
        db_path = $DbPath
    }
} finally {
    Remove-Item Env:\WORLD_MEMORY_DB_PATH -ErrorAction SilentlyContinue
    if ($Process -and -not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force
    }
}
