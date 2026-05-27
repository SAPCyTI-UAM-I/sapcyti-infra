Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = (Resolve-Path "$ScriptDir\..\..").Path

function Test-Command {
  param([string]$Name)
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-Checked {
  param([string]$FilePath, [string[]]$Arguments = @())
  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Command failed: $FilePath $($Arguments -join ' ')" }
}

Write-Host "🔍 Checking prerequisites..." -ForegroundColor Cyan

# Backend Prerequisites
try { $javaVersion = java -version 2>&1 | Select-Object -First 1; Write-Host "✅ Java: $javaVersion" -ForegroundColor Green } catch { throw "❌ Java JDK 21 is not installed." }
try { $mvnVersion = mvn -version 2>&1 | Select-Object -First 1; Write-Host "✅ Maven: $mvnVersion" -ForegroundColor Green } catch { throw "❌ Maven 3.9+ is not installed." }
try { $dockerVersion = docker --version; Write-Host "✅ Docker: $dockerVersion" -ForegroundColor Green } catch { throw "❌ Docker is not installed." }

# Frontend Prerequisites (NVM)
if (-not (Test-Command "nvm")) {
  Write-Host "📦 Installing nvm-windows..." -ForegroundColor Cyan
  if (Test-Command "winget") { Invoke-Checked "winget" @("install", "--id", "CoreyButler.NVMforWindows", "-e", "--accept-source-agreements", "--accept-package-agreements") }
  elseif (Test-Command "choco") { Invoke-Checked "choco" @("install", "nvm", "-y") }
  else { throw "Neither winget nor choco is available. Install nvm-windows manually." }
}

$candidatePaths = @("$env:ProgramFiles\nvm", "$env:ProgramFiles(x86)\nvm", "$env:APPDATA\nvm") | Where-Object { $_ -and (Test-Path $_) }
foreach ($path in $candidatePaths) { if (-not ($env:Path.Split(';') -contains $path)) { $env:Path = "$path;$env:Path" } }

Invoke-Checked "nvm" @("install", "22")
Invoke-Checked "nvm" @("use", "22")

if (-not (Test-Command "corepack")) { throw "corepack not found. Ensure Node.js 22 is active." }
& corepack enable pnpm
if ($LASTEXITCODE -ne 0) { Invoke-Checked "corepack" @("enable") }

Invoke-Checked "pnpm" @("setup")
$pnpmHome = Join-Path (if(Test-Path (Join-Path $env:LOCALAPPDATA "pnpm")){$env:LOCALAPPDATA}else{$env:APPDATA}) "pnpm"
$env:PNPM_HOME = $pnpmHome
if (-not ($env:Path.Split(';') -contains $pnpmHome)) { $env:Path = "$pnpmHome;$env:Path" }

Invoke-Checked "pnpm" @("install", "-g", "@angular/cli")
Invoke-Checked "ng" @("config", "-g", "cli.packageManager", "pnpm")

# Start Infrastructure
Write-Host ""
Write-Host "🐘 Starting local PostgreSQL database..." -ForegroundColor Cyan
Set-Location "$ScriptDir\..\local-dev"
docker compose -f docker-compose.db.yml up -d

Write-Host "⏳ Waiting for PostgreSQL to be ready..." -ForegroundColor Cyan
do {
  Start-Sleep -Seconds 1
  $ready = docker compose -f docker-compose.db.yml exec -T db pg_isready -U sapcyti -d sapcyti_dev 2>&1
} while ($LASTEXITCODE -ne 0)
Write-Host "✅ PostgreSQL is ready at localhost:5433" -ForegroundColor Green

# Setup Application Repositories
Write-Host ""
Write-Host "🔨 Building backend (sapcyti-api)..." -ForegroundColor Cyan
Set-Location "$RootDir\sapcyti-api"
npm install
mvn clean compile -q

Write-Host ""
Write-Host "🎨 Installing frontend dependencies (sapcyti-spa)..." -ForegroundColor Cyan
Set-Location "$RootDir\sapcyti-spa"
pnpm install

Write-Host ""
Write-Host "✅ Setup complete! You can now run the API and SPA, or launch the full stack." -ForegroundColor Green
