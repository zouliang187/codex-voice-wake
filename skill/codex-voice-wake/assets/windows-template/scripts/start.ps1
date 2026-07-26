$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Pythonw = Join-Path $Project "runtime\venv\Scripts\pythonw.exe"
$Service = Join-Path $Project "wake_service.py"
$Config = Join-Path $Project "config.json"
$PidPath = Join-Path $env:LOCALAPPDATA "CodexVoiceWake\runtime\wake.pid"

if (Test-Path $PidPath) {
    $ExistingPid = [int](Get-Content -LiteralPath $PidPath -Raw)
    if (Get-Process -Id $ExistingPid -ErrorAction SilentlyContinue) {
        Write-Host "Already running: PID $ExistingPid"
        exit 0
    }
}
if (-not (Test-Path $Pythonw)) { throw "Run scripts\install.ps1 first." }
if (-not (Test-Path $Config)) { throw "Missing config.json." }

$Arguments = @("`"$Service`"", "--config", "`"$Config`"")
Start-Process -FilePath $Pythonw -ArgumentList $Arguments -WindowStyle Hidden
Start-Sleep -Milliseconds 800
if (Test-Path $PidPath) {
    Write-Host "Started: PID $(Get-Content -LiteralPath $PidPath -Raw)"
} else {
    throw "Listener did not create its PID file. Check logs\wake.log."
}
