$ErrorActionPreference = "Stop"
$PidPath = Join-Path $env:LOCALAPPDATA "CodexVoiceWake\runtime\wake.pid"
if (-not (Test-Path $PidPath)) {
    Write-Host "Not running."
    exit 0
}
$WakePid = [int](Get-Content -LiteralPath $PidPath -Raw)
$Process = Get-Process -Id $WakePid -ErrorAction SilentlyContinue
if ($Process) {
    Stop-Process -Id $WakePid
    Write-Host "Stopped: PID $WakePid"
}
Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue
