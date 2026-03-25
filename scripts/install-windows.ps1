#Requires -Version 5.1
<#
.SYNOPSIS
    Creates a venv, installs PyTorch (CUDA wheels), musubi-tuner[dashboard], and builds the Training Manager frontend.

.PARAMETER Cuda
    PyTorch wheel index: cu124, cu128, or cu130 (see README / pytorch.org).

.PARAMETER SkipFrontend
    Skip npm ci and npm run build.

.PARAMETER VenvPath
    Virtual environment directory, relative to repo root or absolute. Default: .venv
#>
param(
    [ValidateSet("cu124", "cu128", "cu130")]
    [string]$Cuda = "cu124",

    [switch]$SkipFrontend,

    [string]$VenvPath = ".venv"
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvFull = if ([System.IO.Path]::IsPathRooted($VenvPath)) {
    $VenvPath
} else {
    Join-Path $RepoRoot $VenvPath
}

$PyTorchIndex = "https://download.pytorch.org/whl/$Cuda"

function Write-Step($Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

try {
    Write-Step "Checking Python 3.10+"
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw "python not found on PATH. Install Python 3.10 or later and try again."
    }
    $verLine = & python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Could not run python."
    }
    $ver = [version]$verLine.Trim()
    if ($ver -lt [version]"3.10") {
        throw "Python 3.10 or later required; found $verLine"
    }

    Write-Step "Virtual environment: $VenvFull"
    $venvPython = Join-Path $VenvFull "Scripts\python.exe"
    if (-not (Test-Path $venvPython)) {
        & python -m venv $VenvFull
        if ($LASTEXITCODE -ne 0) { throw "python -m venv failed" }
    }

    Write-Step "Upgrading pip"
    & $venvPython -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed" }

    Write-Step "Installing torch and torchvision ($PyTorchIndex)"
    & $venvPython -m pip install torch torchvision --index-url $PyTorchIndex
    if ($LASTEXITCODE -ne 0) { throw "PyTorch install failed" }

    Write-Step "Installing musubi-tuner[dashboard] (editable)"
    Push-Location $RepoRoot
    try {
        & $venvPython -m pip install -e '.[dashboard]'
        if ($LASTEXITCODE -ne 0) { throw "pip install -e .[dashboard] failed" }
    } finally {
        Pop-Location
    }

    if (-not $SkipFrontend) {
        Write-Step "Checking Node.js"
        if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
            throw "node not found on PATH. Install Node.js LTS and re-run (or use -SkipFrontend)."
        }
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            throw "npm not found on PATH."
        }

        $frontend = Join-Path $RepoRoot "src\musubi_tuner\gui_dashboard\frontend"
        if (-not (Test-Path (Join-Path $frontend "package.json"))) {
            throw "Frontend not found: $frontend"
        }

        Write-Step "npm ci && npm run build"
        Push-Location $frontend
        try {
            & npm ci
            if ($LASTEXITCODE -ne 0) { throw "npm ci failed" }
            & npm run build
            if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "(Skipped frontend build -SkipFrontend)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Done. Start the Training Manager from the repo root:" -ForegroundColor Green
    Write-Host "  .\run-dashboard.bat" -ForegroundColor Green
    exit 0
} catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
