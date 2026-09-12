[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot

function Read-ProjectFile {
    param([Parameter(Mandatory = $true)][string] $RelativePath)

    $path = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required project file is missing: $RelativePath"
    }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Needle,
        [Parameter(Mandatory = $true)][string] $Label
    )

    if ($Text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Repository contract failed: $Label"
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Needle,
        [Parameter(Mandatory = $true)][string] $Label
    )

    if ($Text.IndexOf($Needle, [System.StringComparison]::Ordinal) -ge 0) {
        throw "Repository contract failed: $Label"
    }
}

$checks = 0

$remotes = Read-ProjectFile 'src/shared/Remotes.lua'
$remoteNames = [regex]::Matches($remotes, 'define\s*\(\s*"([^"]+)"')
if ($remoteNames.Count -ne 35) {
    throw "Repository contract failed: expected 35 canonical remotes, found $($remoteNames.Count)"
}
$checks++
Assert-Contains $remotes 'Version = 2' 'remote contract version was not bumped'
$checks++
Assert-Contains $remotes 'RequestAdminSnapshot' 'staff snapshot remote is missing'
$checks++
Assert-Contains $remotes 'AdminAction' 'staff action remote is missing'
$checks++
Assert-Contains $remotes 'AdminUpdate' 'staff update remote is missing'
$checks++

$config = Read-ProjectFile 'src/shared/Config.lua'
Assert-Contains $config 'Admin = table.freeze' 'server-owned admin policy is missing'
$checks++
Assert-Contains $config 'OwnerUserIds = table.freeze({})' 'repository must keep owner IDs out of source control by default'
$checks++

$staffPolicy = Read-ProjectFile 'src/shared/StaffPolicy.lua'
Assert-Contains $staffPolicy 'broadcast_announcement = true' 'admin permission contract is missing'
$checks++
Assert-Contains $staffPolicy 'return "Player"' 'staff policy is not deny-by-default'
$checks++

$adminService = Read-ProjectFile 'src/server/Services/AdminService.lua'
Assert-Contains $adminService 'payload.action ~= "BroadcastTemplate"' 'admin actions are not allowlisted'
$checks++
Assert-NotContains $adminService 'loadstring' 'admin service must not execute arbitrary code'
$checks++
Assert-NotContains $adminService ':Kick(' 'admin service must not contain an unchecked kick command'
$checks++

$operation = Read-ProjectFile 'src/server/Util/DataStoreOperation.lua'
Assert-Contains $operation 'function DataStoreOperation.Update' 'shared durable-store update guard is missing'
$checks++
Assert-Contains $operation 'GetRequestBudgetForRequestType' 'durable-store request budget guard is missing'
$checks++
foreach ($servicePath in @(
    'src/server/Services/EconomyService.lua',
    'src/server/Services/SocialCreationService.lua',
    'src/server/Services/CommunityBloomService.lua'
)) {
    Assert-Contains (Read-ProjectFile $servicePath) 'DataStoreOperation' "$servicePath bypasses shared durable-store guard"
    $checks++
}

$round = Read-ProjectFile 'src/server/Services/RoundService.lua'
Assert-Contains $round 'function RoundService.Destroy' 'round lifecycle destroy is missing'
$checks++
Assert-Contains $round 'clearPlayerRuntimeState' 'round departure cleanup is missing'
$checks++

$party = Read-ProjectFile 'src/server/Services/PartyService.lua'
Assert-Contains $party 'playerAddedConnection' 'party lifecycle does not retain its PlayerAdded connection'
$checks++
Assert-Contains $party 'playerRemovingConnection' 'party lifecycle does not retain its PlayerRemoving connection'
$checks++
Assert-Contains $party 'lifecycleEpoch' 'party refresh work can outlive its lifecycle'
$checks++

$runner = Read-ProjectFile 'tests/run-studio-smoke.ps1'
$suiteNames = [regex]::Matches($runner, "Script\s*=\s*'([^']+\.luau)'")
if ($suiteNames.Count -ne 17) {
    throw "Repository contract failed: expected 17 Studio smoke suites, found $($suiteNames.Count)"
}
$checks++
foreach ($match in $suiteNames) {
    $scriptPath = Join-Path $PSScriptRoot $match.Groups[1].Value
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Repository contract failed: Studio smoke script missing: $($match.Groups[1].Value)"
    }
    $checks++
}

foreach ($document in @(
    'docs/ADMIN_OPERATIONS.md',
    'docs/RELEASE_EVIDENCE.md',
    'docs/RISK_REGISTER.md',
    'docs/DECISION_LOG.md',
    'docs/RUNBOOK.md'
)) {
    Read-ProjectFile $document | Out-Null
    $checks++
}

foreach ($currentDocument in @(
    'README.md',
    'docs/UPGRADE_STATE.md',
    'docs/GAME_ANALYSIS.md',
    'docs/ARCHITECTURE.md',
    'docs/QA_MATRIX.md'
)) {
    $documentText = Read-ProjectFile $currentDocument
    Assert-NotContains $documentText '32 remotes' "$currentDocument still describes the old remote contract"
    $checks++
    Assert-NotContains $documentText '12/12' "$currentDocument still describes the old smoke-suite count"
    $checks++
}

Write-Host "AURA_RUSH_REPOSITORY_CONTRACTS_PASS ($checks checks)"
