param(
    [string]$PythonLauncher = "py"
)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Install = Join-Path $env:LOCALAPPDATA "CodexVoiceWake"
$Runtime = Join-Path $Install "runtime"
$ModelName = "vosk-model-small-cn-0.22"
$ModelZip = Join-Path $Runtime "$ModelName.zip"
$ModelDir = Join-Path $Runtime "models\$ModelName"
$ModelUrl = "https://alphacephei.com/vosk/models/$ModelName.zip"
$ModelSha256 = "3af8b0e7e0f835ae9d414ce5df580237a3cfb08d586c9fbbb0f7ff29ad5b14ba"

if (-not (Test-Path (Join-Path $Project "config.json"))) {
    throw "Missing config.json. Create this project with scaffold_project.py and a chosen wake phrase."
}

New-Item -ItemType Directory -Force -Path $Install, $Runtime, (Join-Path $Runtime "models") | Out-Null
Get-ChildItem -LiteralPath $Project -Force |
    Where-Object { $_.Name -notin @("runtime", "logs", "__pycache__") } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Install -Recurse -Force }

$VenvPython = Join-Path $Runtime "venv\Scripts\python.exe"
if (-not (Test-Path $VenvPython)) {
    & $PythonLauncher -3 -m venv (Join-Path $Runtime "venv")
}
& $VenvPython -m pip install --upgrade pip
& $VenvPython -m pip install -r (Join-Path $Install "requirements.txt")

if (-not (Test-Path $ModelDir)) {
    if (-not (Test-Path $ModelZip)) {
        Invoke-WebRequest -Uri $ModelUrl -OutFile $ModelZip
    }
    $ActualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $ModelZip).Hash.ToLowerInvariant()
    if ($ActualSha256 -ne $ModelSha256) {
        throw "Vosk model checksum mismatch: $ActualSha256"
    }
    Expand-Archive -LiteralPath $ModelZip -DestinationPath (Join-Path $Runtime "models") -Force
}

$Startup = [Environment]::GetFolderPath("Startup")
$StartupCmd = Join-Path $Startup "CodexVoiceWake.cmd"
$StartScript = Join-Path $Install "scripts\start.ps1"
$Command = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$StartScript`"`r`n"
Set-Content -LiteralPath $StartupCmd -Value $Command -Encoding ASCII

& $StartScript
Write-Host "Installed: $Install"
Write-Host "Startup:   $StartupCmd"
Write-Host "Log:       $(Join-Path $Install 'logs\wake.log')"
Write-Host "Windows path is experimental until validated on a real Windows device."
