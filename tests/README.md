# V2 Script Tests

This folder contains tests for the V2 CI/CD scripts.

## Prerequisites

### PowerShell Tests (Pester)

Install Pester module:

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
```

### Bash Tests (Bats)

#### macOS

```bash
brew install bats-core
```

#### Linux

```bash
# Ubuntu/Debian
sudo apt-get install bats

# Or install from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

#### Windows

Bats requires a bash environment on Windows. Choose one of these options:

**Option 1: WSL (Windows Subsystem for Linux) - Recommended**

```bash
# Inside WSL terminal
sudo apt-get update
sudo apt-get install bats
```

**Option 2: Git Bash + npm**

```bash
# Requires Node.js installed on Windows
npm install -g bats
```

**Option 3: Git Bash (manual install)**

```bash
# Clone and add to PATH
git clone https://github.com/bats-core/bats-core.git
# Add bats-core/bin to your PATH
```

When running Bats on Windows (Git Bash), ensure scripts have Unix line endings (LF, not CRLF).

## Running Tests

### Run all PowerShell tests

```powershell
Invoke-Pester ./tests/powershell-V2 -Output Detailed
```

### Run a single PowerShell test file

```powershell
Invoke-Pester ./tests/powershell-V2/Get-LatestDeployment.Tests.ps1 -Output Detailed
```

### Run all Bash tests

```bash
bats tests/bash-V2/
```

### Run a single Bash test file

```bash
bats tests/bash-V2/get_latest_deployment.bats
```

## Test Structure

```
tests/
├── bash-V2/                    # Bats tests for bash scripts
│   └── *.bats
├── powershell-V2/              # Pester tests for PowerShell scripts
│   └── *.Tests.ps1
└── README.md
```

## Writing New Tests

### PowerShell (Pester)

- Name test files `<ScriptName>.Tests.ps1`
- Use `Mock Invoke-WebRequest` to simulate API responses
- Reference scripts using: `Join-Path $PSScriptRoot "..\..\V2\powershell\<ScriptName>.ps1"`

### Bash (Bats)

- Name test files `<script_name>.bats`
- Mock `curl` by creating a fake executable in a temp directory and prepending it to `PATH`
- Reference scripts using: `$SCRIPT_DIR/../../V2/bash/<script_name>.sh`
