$ErrorActionPreference = "Stop"
$Install = Join-Path $env:LOCALAPPDATA "CodexVoiceWake"
$Expected = [System.IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA "CodexVoiceWake"))
$Actual = [System.IO.Path]::GetFullPath($Install)
if ($Actual -ne $Expected) { throw "Refusing unexpected uninstall path: $Actual" }

$StopScript = Join-Path $Install "scripts\stop.ps1"
if (Test-Path $StopScript) { & $StopScript }
$StartupCmd = Join-Path ([Environment]::GetFolderPath("Startup")) "CodexVoiceWake.cmd"
Remove-Item -LiteralPath $StartupCmd -Force -ErrorAction SilentlyContinue
if (Test-Path $Install) {
    Remove-Item -LiteralPath $Install -Recurse -Force
}
Write-Host "Removed CodexVoiceWake startup entry and local install."
