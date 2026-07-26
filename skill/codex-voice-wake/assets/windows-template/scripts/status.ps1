$Install = Join-Path $env:LOCALAPPDATA "CodexVoiceWake"
$PidPath = Join-Path $Install "runtime\wake.pid"
$Log = Join-Path $Install "logs\wake.log"
if (Test-Path $PidPath) {
    $WakePid = [int](Get-Content -LiteralPath $PidPath -Raw)
    if (Get-Process -Id $WakePid -ErrorAction SilentlyContinue) {
        Write-Host "RUNNING pid=$WakePid"
    } else {
        Write-Host "STALE pid_file=$WakePid"
    }
} else {
    Write-Host "STOPPED"
}
if (Test-Path $Log) {
    Get-Content -LiteralPath $Log -Tail 20
}
