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

$DbPath = Join-Path $env:TEMP ("cw_world_memory_merchant_" + [guid]::NewGuid().ToString() + ".sqlite3")
$OutLog = Join-Path $env:TEMP ("cw_world_memory_merchant_" + [guid]::NewGuid().ToString() + ".out.log")
$ErrLog = Join-Path $env:TEMP ("cw_world_memory_merchant_" + [guid]::NewGuid().ToString() + ".err.log")

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
        -ArgumentList @("--headless", "--path", "game", "-s", "tests/MerchantWorldMemoryIntegrationTest.gd") `
        -WorkingDirectory $Root `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    if ($GodotProcess.ExitCode -ne 0) {
        throw "Merchant WorldMemory HTTP integration failed with exit code $($GodotProcess.ExitCode)."
    }

    $MerchantMemory = Invoke-RestMethod -Uri "http://127.0.0.1:8011/owners/merchant_party_01/memory?limit=50"
    $OpoleMemory = Invoke-RestMethod -Uri "http://127.0.0.1:8011/owners/opole_stronghold/memory?limit=50"
    $WroclawMemory = Invoke-RestMethod -Uri "http://127.0.0.1:8011/owners/wroclaw_city/memory?limit=50"
    $WorldEvents = Invoke-RestMethod -Uri "http://127.0.0.1:8011/world-events?limit=100"

    if ($MerchantMemory.Count -le 0) {
        throw "Expected merchant party memory entries."
    }
    if ($OpoleMemory.Count -le 0) {
        throw "Expected Opole location memory entries."
    }
    if ($WroclawMemory.Count -le 0) {
        throw "Expected Wroclaw location memory entries."
    }

    $MerchantEventTypes = ($MerchantMemory | ForEach-Object { $_.metadata.event_type } | Sort-Object -Unique) -join ","
    $OpoleFoodDeltas = ($OpoleMemory | Where-Object { $_.metadata.goods_id -eq "food" } | ForEach-Object { $_.metadata.owner_goods_delta }) -join ","
    $WroclawFoodDeltas = ($WroclawMemory | Where-Object { $_.metadata.goods_id -eq "food" } | ForEach-Object { $_.metadata.owner_goods_delta }) -join ","

    [pscustomobject]@{
        world_events = $WorldEvents.Count
        merchant_memory = $MerchantMemory.Count
        opole_memory = $OpoleMemory.Count
        wroclaw_memory = $WroclawMemory.Count
        merchant_event_types = $MerchantEventTypes
        opole_food_deltas = $OpoleFoodDeltas
        wroclaw_food_deltas = $WroclawFoodDeltas
        db_path = $DbPath
    }
} finally {
    Remove-Item Env:\WORLD_MEMORY_DB_PATH -ErrorAction SilentlyContinue
    if ($Process -and -not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force
    }
}
