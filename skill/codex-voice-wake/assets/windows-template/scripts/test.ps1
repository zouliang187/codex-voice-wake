$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Python = Join-Path $Project "runtime\venv\Scripts\python.exe"
if (-not (Test-Path $Python)) {
    $Python = "python"
}
& $Python -m py_compile (Join-Path $Project "wake_service.py") (Join-Path $Project "state_machine.py")
& $Python -m unittest discover -s (Join-Path $Project "tests") -v
