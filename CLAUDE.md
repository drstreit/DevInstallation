# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository contains a PowerShell script (`BaseInstallDev.ps1`) that automates setting up a Windows 11 development environment for Rust, Python, Web, and Cloud (AWS) development. It is a one-time setup script, not a software project with a build pipeline.

## Script Execution

To run the setup script (requires Windows 11, run as Administrator):

```powershell
powershell -ExecutionPolicy Bypass -File BaseInstallDev.ps1
```

**Important:** The script pauses mid-execution after installing Python to prompt the user to install a Python version via the Python Install Manager and restart PowerShell before continuing.

## Installation Flow

The script is structured in 9 numbered sections, each tracked for pass/fail. A summary with retry commands is printed at the end.

1. **Core system tools** — Git, PowerShell, Windows Terminal, Chrome, utilities
2. **IDEs & editors** — VS Code, Visual Studio Community
3. **Language runtimes** — Python (manual pause required), Node.js LTS, Rust via `winget install Rustlang.Rustup`
4. **Language toolchains** — pip/pipx/poetry, pnpm, `rustup target add aarch64-unknown-linux-musl`, cargo-lambda, cargo-audit (PATH refreshed before this section)
5. **Cloud tools** — AWS CLI, AWS SAM CLI, AWS CDK, SnowSQL
6. **AI tools** — Claude desktop, Claude Code, GitHub Copilot, Microsoft Copilot
7. **Other dev tools** — Bruno, QGIS
8. **VS Code extensions** — GitHub, AI, Rust, Python, Web, Cloud categories
9. **Finalize** — `winget upgrade --all`, WSL update, GitHub CLI auth

## Manual Steps After Script (TODO.md)

These steps must be done manually and are not automated:

1. Install WSL
2. `nvs add lts && nvs link lts` — activate Node.js via nvs
3. `npm install -g aws-cdk`
4. `aws configure --profile dev`
5. `docker ps` — verify Docker is running

## Helper functions

- `Install-Package $Name $Id` — wraps `winget install`, records result
- `Install-Extension $Id` — wraps `code --install-extension`, records result
- `Invoke-Step $Name { ... }` — runs an arbitrary command block, records result
- `Refresh-Path` — reloads `$env:PATH` from the registry (called before toolchain section so cargo/npm/pip are available after their runtimes are installed)
