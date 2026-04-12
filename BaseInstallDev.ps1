<#
Entwicklungsumgebung

Ein Powershell file um eine blanke Windows 11 Installation in ein Dev environment für Rust, Python, Web und Cloud Entwicklung zu verwandeln.
Es installiert die wichtigsten Tools, Pakete und VS Code Extensions.

#>

$ErrorActionPreference = "Continue"

# ============================================================
# Admin rights check
# ============================================================
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host "       Right-click PowerShell and select 'Run as Administrator', then try again." -ForegroundColor Yellow
    exit 1
}

# ============================================================
# Result tracking
# ============================================================
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-Result {
    param([string]$Component, [bool]$Success, [string]$Fix = "")
    $results.Add([PSCustomObject]@{
        Component = $Component
        Status    = if ($Success) { "OK" } else { "FAIL" }
        Fix       = $Fix
    })
    if (-not $Success) {
        Write-Host "  [FAIL] $Component" -ForegroundColor Red
        if ($Fix) { Write-Host "         Retry: $Fix" -ForegroundColor Yellow }
    }
}

function Install-Package {
    param([string]$Name, [string]$Id, [string]$Source = "winget", [string]$Override = "", [string]$Fix = "")
    $sourceArgs   = if ($Source)   { @("--source",   $Source)   } else { @() }
    $overrideArgs = if ($Override) { @("--override", $Override) } else { @() }
    if (-not $Fix) { $Fix = "winget install -e --id $Id $($sourceArgs -join ' ') --accept-source-agreements --accept-package-agreements" }
    Write-Host "  $Name ($Id)..." -ForegroundColor Gray
    $output = winget install -e --id $Id @sourceArgs @overrideArgs `
        --accept-source-agreements --accept-package-agreements 2>&1
    $ok = $LASTEXITCODE -eq 0
    if (-not $ok) { Write-Host "    $output" -ForegroundColor DarkGray }
    Add-Result $Name $ok $Fix
}

function Install-Extension {
    param([string]$Id)
    Write-Host "  $Id..." -ForegroundColor Gray
    code --install-extension $Id --force 2>&1 | Out-Null
    Add-Result "VSCode: $Id" ($LASTEXITCODE -eq 0) "code --install-extension $Id --force"
}

function Invoke-Step {
    param([string]$Name, [scriptblock]$Block, [string]$Fix = "")
    Write-Host "  $Name..." -ForegroundColor Gray
    try {
        $output = & $Block 2>&1
        $ok = $LASTEXITCODE -eq 0
        if (-not $ok) { Write-Host "    $output" -ForegroundColor DarkGray }
        Add-Result $Name $ok $Fix
    } catch {
        Write-Host "    $_" -ForegroundColor DarkGray
        Add-Result $Name $false $Fix
    }
}

function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

# Returns $true if the command is found in PATH, $false otherwise.
function Test-Cmd {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# Records every step in $Block as SKIP when a prerequisite command is missing.
# Prints a single clear message explaining why and what to do.
function Skip-Section {
    param(
        [string]$Prerequisite,          # command that was missing, e.g. "pip"
        [string[]]$Steps,               # human-readable names of the skipped steps
        [string]$Instructions           # what the user should do to recover
    )
    $msg = "'$Prerequisite' not found in PATH after install. $Instructions"
    Write-Host "  [SKIP] $msg" -ForegroundColor DarkYellow
    foreach ($step in $Steps) {
        $results.Add([PSCustomObject]@{
            Component = $step
            Status    = "SKIP"
            Fix       = $Instructions
        })
    }
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

# ============================================================
# Bootstrap
# ============================================================
Write-Host "Starting Windows Dev Environment Setup..." -ForegroundColor Cyan
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

Write-Section "Bootstrapping winget"
winget settings --enable BypassCertificatePinningForMicrosoftStore
winget upgrade Microsoft.AppInstaller --accept-source-agreements --accept-package-agreements

# ============================================================
# 1. Core system tools
# ============================================================
Write-Section "1 / Core System Tools"
Install-Package "PowerShell"          "Microsoft.PowerShell"
Install-Package "Git"                 "Git.Git"
Install-Package "GitHub CLI"          "GitHub.cli"
Install-Package "TortoiseGit"         "TortoiseGit.TortoiseGit"
Install-Package "Windows Terminal"    "Microsoft.WindowsTerminal"
Install-Package "UniGetUI"            "MartiCliment.UniGetUI"
Install-Package "QuickLook"           "QL-Win.QuickLook"
Install-Package "OneCommander"        "MilosParipovic.OneCommander"
Install-Package "Google Chrome"       "Google.Chrome"
Install-Package "Sysinternals Suite"  "Microsoft.Sysinternals.Suite"
Install-Package "WinRAR"              "RARLab.WinRAR"
Install-Package "Everything"          "voidtools.Everything"
Install-Package "Wget"                "JernejSimoncic.Wget"

# ============================================================
# 2. IDEs & editors
# ============================================================
Write-Section "2 / IDEs & Editors"
Install-Package "VS Code"                 "Microsoft.VisualStudioCode"
Install-Package "Visual Studio Community" "Microsoft.VisualStudio.Community" `
    -Override "--add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --quiet --wait --norestart"

# ============================================================
# 3. Language runtimes  (Python → Node.js → Rust, in dependency order)
# ============================================================
Write-Section "3 / Language Runtimes"

# Python: requires manual install step before toolchain can be configured
Install-Package "Python Install Manager" "Python.PythonInstallManager"
Write-Host ""
Write-Host "  ACTION REQUIRED:" -ForegroundColor Yellow
Write-Host "  1. Open Python Install Manager and install the latest Python version." -ForegroundColor Yellow
Write-Host "  2. Ensure Python is added to PATH." -ForegroundColor Yellow
Write-Host "     (If needed: rundll32 sysdm.cpl,EditEnvironmentVariables)" -ForegroundColor Yellow
Read-Host "  Press ENTER once Python is installed and PATH is set"
Refresh-Path

# Node.js — installed here so pnpm can follow immediately in section 4
Install-Package "Node.js LTS" "OpenJS.NodeJS.LTS"

# Rust
Install-Package "Rust (rustup)" "Rustlang.Rustup"

# ============================================================
# 4. Language toolchains  (requires runtimes + fresh PATH)
# ============================================================
Write-Section "4 / Language Toolchains"
Refresh-Path

# Python — guard on pip
if (Test-Cmd "pip") {
    Invoke-Step "pip upgrade"  { pip install --upgrade pip } "pip install --upgrade pip"
    Invoke-Step "pipx install" { pip install pipx }          "pip install pipx"
    Refresh-Path   # pipx lands in Python's Scripts dir; must refresh before first use
    if (Test-Cmd "pipx") {
        Invoke-Step "pipx ensurepath" { pipx ensurepath }          "pipx ensurepath"
        Invoke-Step "argcomplete"     { pipx install argcomplete }  "pipx install argcomplete"
        Invoke-Step "poetry"          { pipx install poetry }       "pipx install poetry"
    } else {
        Skip-Section "pipx" @("pipx ensurepath","argcomplete","poetry") `
            "Open a new PowerShell window and run: pipx ensurepath; pipx install argcomplete; pipx install poetry"
    }
} else {
    Skip-Section "pip" @("pip upgrade","pipx install","pipx ensurepath","argcomplete","poetry") `
        "Open a new PowerShell window and re-run from section 4, or run each command manually."
}

# Node.js — guard on npm
if (Test-Cmd "npm") {
    Invoke-Step "pnpm"      { npm install -g pnpm }      "npm install -g pnpm"
    Invoke-Step "aws-cdk"   { npm install -g aws-cdk }   "npm install -g aws-cdk"
} else {
    Skip-Section "npm" @("pnpm","aws-cdk") `
        "Open a new PowerShell window and run: npm install -g pnpm; npm install -g aws-cdk"
}

# Rust — guard on cargo
# Note: rustup adds ~/.cargo/bin to the registry PATH; Refresh-Path should pick it up,
# but if rustup's installer ran asynchronously it may not be visible yet.
if (Test-Cmd "cargo") {
    Invoke-Step "rustup musl target" { rustup target add aarch64-unknown-linux-musl } `
        "rustup target add aarch64-unknown-linux-musl"
    Invoke-Step "cargo-lambda"       { cargo install cargo-lambda }  "cargo install cargo-lambda"
    Invoke-Step "cargo-audit"        { cargo install cargo-audit }   "cargo install cargo-audit"
} else {
    Skip-Section "cargo" @("rustup musl target","cargo-lambda","cargo-audit") `
        "Open a new PowerShell window and run: rustup target add aarch64-unknown-linux-musl; cargo install cargo-lambda cargo-audit"
}

# ============================================================
# 5. Cloud tools
# ============================================================
Write-Section "5 / Cloud Tools"
Install-Package "AWS CLI"     "Amazon.AWSCLI"
Install-Package "AWS SAM CLI" "Amazon.AWSSAMCLI" -Source ""   # not on winget source
Install-Package "SnowSQL"     "Snowflake.SnowSQL"

# ============================================================
# 6. AI tools
# ============================================================
Write-Section "6 / AI Tools"
Install-Package "Claude"         "Anthropic.Claude"
Install-Package "Claude Code"    "Anthropic.ClaudeCode"
Install-Package "GitHub Copilot" "GitHub.Copilot"
Write-Host "  Microsoft Copilot..." -ForegroundColor Gray
winget install "Microsoft Copilot" --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
Add-Result "Microsoft Copilot" ($LASTEXITCODE -eq 0) 'winget install "Microsoft Copilot" --accept-source-agreements --accept-package-agreements'

# ============================================================
# 7. Other dev tools
# ============================================================
Write-Section "7 / Other Dev Tools"
Install-Package "Bruno (API testing)" "Bruno.Bruno"
Install-Package "QGIS"               "OSGeo.QGIS"

# ============================================================
# 8. VS Code extensions
# ============================================================
Write-Section "8 / VS Code Extensions"

$extensions = @(
    # GitHub
    "GitHub.copilot",
    "GitHub.copilot-chat",
    "GitHub.vscode-pull-request-github",
    "GitHub.remotehub",
    "GitHub.vscode-github-actions",
    "eamodio.gitlens",
    # AI
    "Anthropic.claude-vscode",
    # Rust
    "rust-lang.rust-analyzer",
    "serayuzgur.crates",
    "tamasfe.even-better-toml",
    # Python
    "ms-python.python",
    "ms-python.vscode-pylance",
    "charliermarsh.ruff",
    # Web
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "ritwickdey.LiveServer",
    # Cloud
    "AmazonWebServices.aws-toolkit-vscode",
    "Snowflake.snowflake-vsc"
)

foreach ($ext in $extensions) {
    Install-Extension $ext
}

# ============================================================
# 9. Finalize
# ============================================================
Write-Section "9 / Finalizing"
Invoke-Step "winget upgrade all" {
    winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements
} "winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements"

Invoke-Step "WSL update" { wsl.exe --update } "wsl.exe --update"

winget settings --disable BypassCertificatePinningForMicrosoftStore
Set-ExecutionPolicy Restricted -Scope CurrentUser -Force

# GitHub CLI auth is interactive — run last, outside result tracking
Write-Host ""
Write-Host "=== GitHub CLI Authentication ===" -ForegroundColor Cyan
gh auth login
Add-Result "GitHub CLI auth" ($LASTEXITCODE -eq 0) "gh auth login"

# ============================================================
# Summary
# ============================================================
$ok   = @($results | Where-Object { $_.Status -eq "OK" })
$fail = @($results | Where-Object { $_.Status -eq "FAIL" })
$skip = @($results | Where-Object { $_.Status -eq "SKIP" })

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  SETUP SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ("  Total   : {0,3}" -f $results.Count)
Write-Host ("  OK      : {0,3}" -f $ok.Count)   -ForegroundColor Green
Write-Host ("  Failed  : {0,3}" -f $fail.Count) -ForegroundColor $(if ($fail.Count -gt 0) { "Red" } else { "Green" })
Write-Host ("  Skipped : {0,3}" -f $skip.Count) -ForegroundColor $(if ($skip.Count -gt 0) { "DarkYellow" } else { "Green" })

if ($fail.Count -gt 0) {
    Write-Host ""
    Write-Host "  FAILED — retry commands:" -ForegroundColor Red
    foreach ($item in $fail) {
        Write-Host ""
        Write-Host ("  [-] {0}" -f $item.Component) -ForegroundColor Red
        if ($item.Fix) {
            Write-Host ("      {0}" -f $item.Fix) -ForegroundColor Yellow
        }
    }
}

if ($skip.Count -gt 0) {
    Write-Host ""
    Write-Host "  SKIPPED — prerequisite was not in PATH:" -ForegroundColor DarkYellow
    foreach ($item in $skip) {
        Write-Host ""
        Write-Host ("  [~] {0}" -f $item.Component) -ForegroundColor DarkYellow
        if ($item.Fix) {
            Write-Host ("      {0}" -f $item.Fix) -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
if ($fail.Count -eq 0 -and $skip.Count -eq 0) {
    Write-Host "  All installations succeeded!" -ForegroundColor Green
} else {
    $problems = $fail.Count + $skip.Count
    Write-Host ("  Setup complete with {0} item(s) needing attention. See above." -f $problems) -ForegroundColor Yellow
}
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press ENTER to exit"
