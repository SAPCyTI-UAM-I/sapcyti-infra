# SPEC-010 — full-stack smoke (Windows PowerShell)
param(
    [string]$BaseUrl = $(if ($env:SMOKE_BASE_URL) { $env:SMOKE_BASE_URL } else { "http://localhost" }),
    [string]$AuthUser = $(if ($env:SMOKE_AUTH_USER) { $env:SMOKE_AUTH_USER } else { "coordinator" }),
    [string]$AuthPass = $(if ($env:SMOKE_COORDINATOR_PASSWORD) { $env:SMOKE_COORDINATOR_PASSWORD } else { "changeme" })
)

$ErrorActionPreference = "Stop"

function Get-ResponseText([object]$Content) {
    if ($Content -is [byte[]]) {
        return [Text.Encoding]::UTF8.GetString($Content)
    }
    return [string]$Content
}

$ApiUrl = "$BaseUrl/api"
$ProgramName = if ($env:SMOKE_PROGRAM_NAME) { $env:SMOKE_PROGRAM_NAME } else { "Smoke Program $(Get-Date -Format 'yyyyMMddHHmmss')" }
$Division = if ($env:SMOKE_DIVISION) { $env:SMOKE_DIVISION } else { "CBI" }

function Fail([string]$Message) {
    Write-Error "SMOKE FAILED: $Message"
    exit 1
}

$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${AuthUser}:${AuthPass}"))
$authHeader = @{ Authorization = "Basic $cred" }

Write-Host "==> Health (proxied actuator)"
try {
    $health = Invoke-WebRequest -Uri "$ApiUrl/actuator/health" -UseBasicParsing
} catch {
    Fail "actuator health unreachable at $ApiUrl/actuator/health"
}
$healthBody = Get-ResponseText $health.Content
if ($healthBody -notmatch '"status"\s*:\s*"UP"') {
    Fail "actuator status is not UP: $healthBody"
}

Write-Host "==> SPA shell"
try {
    $spa = Invoke-WebRequest -Uri "$BaseUrl/" -UseBasicParsing
} catch {
    Fail "edge unreachable at $BaseUrl/"
}
$spaBody = Get-ResponseText $spa.Content
if ($spaBody -notmatch '<app-root|data-testid="app-shell"') {
    Fail "SPA root marker not found in HTML"
}

Write-Host "==> POST /api/programs"
$body = @{ name = $ProgramName; division = $Division } | ConvertTo-Json
try {
    $create = Invoke-WebRequest -Uri "$ApiUrl/programs" -Method Post -Headers $authHeader `
        -ContentType "application/json" -Body $body -UseBasicParsing
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Fail "POST /api/programs returned $status"
}
if ($create.StatusCode -ne 201) {
    Fail "POST /api/programs returned $($create.StatusCode)"
}
$created = Get-ResponseText $create.Content | ConvertFrom-Json
$programId = $created.id
if (-not $programId) {
    Fail "could not parse program id from create response"
}

Write-Host "==> GET /api/programs"
try {
    $list = Invoke-WebRequest -Uri "$ApiUrl/programs" -Headers $authHeader -UseBasicParsing
} catch {
    Fail "GET /api/programs failed"
}
$listBody = Get-ResponseText $list.Content
if ($listBody -notmatch [regex]::Escape($ProgramName)) {
    Fail "created program not found in list"
}

Write-Host "==> GET /api/programs/$programId"
try {
    $one = Invoke-WebRequest -Uri "$ApiUrl/programs/$programId" -Headers $authHeader -UseBasicParsing
} catch {
    Fail "GET /api/programs/$programId failed"
}
$oneBody = Get-ResponseText $one.Content
if ($oneBody -notmatch [regex]::Escape($ProgramName)) {
    Fail "program name mismatch on GET by id"
}

Write-Host "SMOKE OK"
