[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$wingetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'

function Resolve-Tool([string] $Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $fallback = Join-Path $wingetLinks ($Name + '.exe')
    if (Test-Path -LiteralPath $fallback) {
        return $fallback
    }

    throw "Required tool '$Name' was not found."
}

function Invoke-Checked([string] $Executable, [string[]] $Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $Executable $($Arguments -join ' ')"
    }
}

$stylua = Resolve-Tool 'stylua'
$selene = Resolve-Tool 'selene'
$rojo = Resolve-Tool 'rojo'
$placePath = Join-Path $projectRoot 'AuraRush.rbxlx'

Push-Location $projectRoot
try {
    Invoke-Checked $stylua @('--check', 'src', 'tests')
    Invoke-Checked $selene @('src', 'tests')
    Invoke-Checked $rojo @('build', 'default.project.json', '-o', $placePath)

    # Rojo 7.7's reflection database predates these current Workspace enum
    # properties. They are NotScriptable at runtime, so inject their canonical
    # enum tokens into the generated place and let the Studio smoke suite prove
    # that the current engine deserializes them correctly.
    $placeXml = [System.IO.File]::ReadAllText($placePath)
    $streamingMarker = '<int name="StreamingTargetRadius">256</int>'
    if (-not $placeXml.Contains($streamingMarker)) {
        throw 'Generated place is missing the Workspace streaming marker.'
    }
    $advancedStreamingTokens = @(
        '<token name="PredictiveStreamingMode">1</token>',
        '<token name="StreamOutBehavior">2</token>',
        '<token name="StreamingIntegrityMode">3</token>',
        '<token name="EnableSLIMAvatars">2</token>'
    )
    $missingStreamingTokens = @(
        $advancedStreamingTokens | Where-Object { -not $placeXml.Contains($_) }
    )
    if ($missingStreamingTokens.Count -gt 0) {
        $insertion = $streamingMarker + "`n      " + ($missingStreamingTokens -join "`n      ")
        $placeXml = $placeXml.Replace($streamingMarker, $insertion)
        [System.IO.File]::WriteAllText(
            $placePath,
            $placeXml,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    $verifiedPlaceXml = [System.IO.File]::ReadAllText($placePath)
    foreach ($token in $advancedStreamingTokens) {
        if (-not $verifiedPlaceXml.Contains($token)) {
            throw "Advanced Workspace property was not serialized: $token"
        }
    }

    $place = Get-Item -LiteralPath $placePath
    if ($place.Length -lt 10000) {
        throw "Built place is unexpectedly small: $($place.Length) bytes."
    }

    $clientBootstraps = @(Get-ChildItem -LiteralPath 'src/client' -Filter '*.client.lua' -File -Recurse)
    $serverBootstraps = @(Get-ChildItem -LiteralPath 'src/server' -Filter '*.server.lua' -File -Recurse)
    $loadingBootstraps = @(Get-ChildItem -LiteralPath 'src/replicatedFirst' -Filter '*.client.lua' -File -Recurse)
    if ($clientBootstraps.Count -ne 1 -or $serverBootstraps.Count -ne 1) {
        throw 'Expected exactly one client and one server bootstrap.'
    }
    if ($loadingBootstraps.Count -ne 1) {
        throw 'Expected exactly one ReplicatedFirst loading bootstrap.'
    }

    $loadingSource = [System.IO.File]::ReadAllText($loadingBootstraps[0].FullName)
    foreach ($requiredToken in @(
        'RemoveDefaultLoadingScreen',
        'AuraRushBootState',
        'AuraRushRuntimeState',
        'AuraRushProfileState',
        'client_starting',
        'ready',
        'failed',
        'server_ready',
        'server_failed',
        'profile_ready',
        'profile_failed'
    )) {
        if (-not $loadingSource.Contains($requiredToken)) {
            throw "Loading shell contract is missing '$requiredToken'."
        }
    }
    if ($loadingSource.Contains('rbxassetid://')) {
        throw 'Loading shell must not depend on a remote asset.'
    }

    $serverSource = [System.IO.File]::ReadAllText($serverBootstraps[0].FullName)
    foreach ($requiredToken in @(
        'xpcall(boot, debug.traceback)',
        'AuraRushRuntimeState',
        'server_starting',
        'server_ready',
        'server_failed',
        'ServerFailureCode',
        'AuraRushProfileState',
        'profile_loading',
        'profile_ready',
        'profile_failed',
        'AuraRushProfileFailureCode'
    )) {
        if (-not $serverSource.Contains($requiredToken)) {
            throw "Server bootstrap resilience contract is missing '$requiredToken'."
        }
    }

    $requiredBrandAssets = @(
        'assets/brand/style-raid-key-art-v1.png',
        'assets/brand/style-raid-icon-v1.png',
        'assets/brand/style-raid-key-art-v2.png',
        'assets/brand/style-raid-icon-v2.png',
        'assets/brand/remix-city-premium-map-concept-v3.png'
    )
    foreach ($assetPath in $requiredBrandAssets) {
        if (-not (Test-Path -LiteralPath $assetPath)) {
            throw "Required brand asset is missing: $assetPath"
        }
        $asset = Get-Item -LiteralPath $assetPath
        if ($asset.Length -lt 100000) {
            throw "Brand asset is unexpectedly small: $assetPath ($($asset.Length) bytes)"
        }
    }

    foreach ($contractPath in @(
        'tests/server-integration-smoke.luau',
        'tests/localization-contract.luau',
        'tests/loading-shell-smoke.luau',
        'tests/client-lifecycle-smoke.luau',
        'tests/network-security-smoke.luau',
        'tests/network-readiness-smoke.luau',
        'tests/analytics-lifecycle-smoke.luau',
        'tests/data-resilience-smoke.luau',
        'tests/secret-frames-v7-smoke.luau',
        'tests/presentation-upgrade-smoke.luau',
        'tests/economy-liveops-social-smoke.luau',
        'tests/living-city-v4-smoke.luau',
        'tests/premium-city-v6-smoke.luau'
    )) {
        if (-not (Test-Path -LiteralPath $contractPath)) {
            throw "Required upgrade contract is missing: $contractPath"
        }
    }

    Write-Host "AURA_RUSH_PROJECT_CHECK_PASS ($($place.Length) bytes)"
}
finally {
    Pop-Location
}
