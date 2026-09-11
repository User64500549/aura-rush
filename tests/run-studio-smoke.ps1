[CmdletBinding()]
param(
    [string] $Script = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$placePath = Join-Path $projectRoot 'AuraRush.rbxlx'
$outputPath = Join-Path $projectRoot 'studio-smoke.log'
$studioTempBase = Join-Path ([System.IO.Path]::GetTempPath()) 'AuraRushStudioSmoke'
$studioTempRoot = Join-Path $studioTempBase ([guid]::NewGuid().ToString('N'))

$smokeCases = @(
    @{
        Script = 'studio-smoke.luau'
        Marker = 'AURA_RUSH_SMOKE_PASS'
    },
    @{
        Script = 'server-integration-smoke.luau'
        Marker = 'AURA_RUSH_SERVER_INTEGRATION_PASS'
    },
    @{
        Script = 'loading-shell-smoke.luau'
        Marker = 'AURA_RUSH_LOADING_SHELL_PASS'
    },
    @{
        Script = 'client-lifecycle-smoke.luau'
        Marker = 'AURA_RUSH_CLIENT_LIFECYCLE_PASS'
    },
    @{
        Script = 'network-security-smoke.luau'
        Marker = 'AURA_RUSH_NETWORK_SECURITY_PASS'
    },
    @{
        Script = 'network-readiness-smoke.luau'
        Marker = 'AURA_RUSH_NETWORK_READINESS_PASS'
    },
    @{
        Script = 'analytics-lifecycle-smoke.luau'
        Marker = 'AURA_RUSH_ANALYTICS_LIFECYCLE_PASS'
    },
    @{
        Script = 'data-resilience-smoke.luau'
        Marker = 'AURA_RUSH_DATA_RESILIENCE_PASS'
    },
    @{
        Script = 'gameplay-director-smoke.luau'
        Marker = 'AURA_RUSH_GAMEPLAY_DIRECTOR_SMOKE_PASS'
    },
    @{
        Script = 'first-miracle-smoke.luau'
        Marker = 'AURA_RUSH_FIRST_MIRACLE_SMOKE_PASS'
    },
    @{
        Script = 'localization-contract.luau'
        Marker = 'AURA_RUSH_LOCALIZATION_CONTRACT_PASS'
    },
    @{
        Script = 'presentation-upgrade-smoke.luau'
        Marker = 'AURA_RUSH_PRESENTATION_UPGRADE_PASS'
    },
    @{
        Script = 'economy-liveops-social-smoke.luau'
        Marker = 'AURA_RUSH_ECONOMY_LIVEOPS_SOCIAL_PASS'
    },
    @{
        Script = 'living-city-v4-smoke.luau'
        Marker = 'AURA_RUSH_LIVING_CITY_V4_PASS'
    },
    @{
        Script = 'remix-city-v5-smoke.luau'
        Marker = 'AURA_RUSH_REMIX_CITY_V5_PASS'
    },
    @{
        Script = 'premium-city-v6-smoke.luau'
        Marker = 'AURA_RUSH_PREMIUM_CITY_V6_PASS'
    },
    @{
        Script = 'secret-frames-v7-smoke.luau'
        Marker = 'AURA_RUSH_SECRET_FRAMES_V7_PASS'
    }
)
if ($Script -ne '') {
    $smokeCases = @($smokeCases | Where-Object { $_.Script -eq $Script })
    if ($smokeCases.Count -ne 1) {
        throw "Unknown Studio smoke script: $Script"
    }
}

if (-not (Test-Path -LiteralPath $placePath)) {
    throw 'AuraRush.rbxlx is missing. Run tests/check-project.ps1 first.'
}
$place = Get-Item -LiteralPath $placePath
$buildInputs = @(
    Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src') -File -Recurse
    Get-Item -LiteralPath (Join-Path $projectRoot 'default.project.json')
)
$latestBuildInput = $buildInputs | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
if ($place.LastWriteTimeUtc -lt $latestBuildInput.LastWriteTimeUtc) {
    throw "AuraRush.rbxlx is older than '$($latestBuildInput.FullName)'. Run tests/check-project.ps1 first."
}
$placeHash = (Get-FileHash -LiteralPath $placePath -Algorithm SHA256).Hash
$runHeader = "AURA_RUSH_BUILD SHA256=$placeHash SIZE=$($place.Length) UTC=$([DateTime]::UtcNow.ToString('o'))"

$searchRoots = @(
    (Join-Path $env:LOCALAPPDATA 'Roblox\Versions'),
    'C:\Program Files (x86)\Roblox\Versions'
)
$studio = Get-ChildItem -Path $searchRoots -Filter 'RobloxStudioBeta.exe' -File -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $studio) {
    throw 'RobloxStudioBeta.exe was not found.'
}

[System.IO.File]::WriteAllText(
    $outputPath,
    $runHeader + "`r`n",
    [System.Text.UTF8Encoding]::new($false)
)
try {
    New-Item -ItemType Directory -Path $studioTempRoot -Force | Out-Null
    $combinedOutput = [System.Collections.Generic.List[string]]::new()
    foreach ($smokeCase in $smokeCases) {
        $sourceScriptPath = Join-Path $PSScriptRoot $smokeCase.Script
        if (-not (Test-Path -LiteralPath $sourceScriptPath)) {
            throw "Studio smoke script is missing: $sourceScriptPath"
        }

        $studioScriptPath = Join-Path $studioTempRoot $smokeCase.Script
        $caseOutputPath = Join-Path $studioTempRoot ($smokeCase.Script + '.log')
        $caseName = [System.IO.Path]::GetFileNameWithoutExtension($smokeCase.Script)
        $casePlacePath = Join-Path $studioTempRoot ($caseName + '.rbxlx')
        Copy-Item -LiteralPath $sourceScriptPath -Destination $studioScriptPath -Force
        Copy-Item -LiteralPath $placePath -Destination $casePlacePath -Force
        [System.IO.File]::WriteAllText(
            $caseOutputPath,
            '',
            [System.Text.UTF8Encoding]::new($false)
        )

        $studioArguments = @(
            '--task', 'RunScript',
            '--localPlaceFile', $casePlacePath,
            '--runScriptFile', $studioScriptPath,
            '--outputFile', $caseOutputPath,
            '--quitAfterExecution'
        )
        $studioProcess = Start-Process `
            -FilePath $studio.FullName `
            -ArgumentList $studioArguments `
            -WindowStyle Hidden `
            -PassThru

        # Current Studio builds may hand the command to a child process and let the
        # small launcher exit before the place has been opened. Waiting only on the
        # Start-Process handle can therefore delete the temporary place while the
        # real Studio process is still reading it. The output marker is the
        # authoritative completion signal; keep the temporary files alive until it
        # appears or the case deadline expires.
        $deadline = [DateTime]::UtcNow.AddSeconds(120)
        $caseOutput = ''
        $markerFound = $false
        $runtimeFailure = $false
        $prematureExit = $false
        $caseLockPath = $casePlacePath + '.lock'
        $stableSince = [DateTime]::UtcNow
        $lastOutputLength = -1
        $runtimeMarkerPattern = '(?m)^' + [regex]::Escape($smokeCase.Marker) + '(?:\s|\(|$)'
        $runtimeFailurePattern = "(?m)^(?:RunScript:\d+:|Script 'RunScript', Line \d+)"
        while ([DateTime]::UtcNow -lt $deadline) {
            if (Test-Path -LiteralPath $caseOutputPath) {
                try {
                    $rawCaseOutput = Get-Content -LiteralPath $caseOutputPath -Raw -ErrorAction Stop
                    $caseOutput = if ($null -eq $rawCaseOutput) { '' } else { [string]$rawCaseOutput }
                }
                catch [System.IO.IOException] {
                    Start-Sleep -Milliseconds 100
                    continue
                }
                if ($caseOutput.Length -ne $lastOutputLength) {
                    $lastOutputLength = $caseOutput.Length
                    $stableSince = [DateTime]::UtcNow
                }
                if ($caseOutput -match $runtimeFailurePattern) {
                    $runtimeFailure = $true
                    break
                }
                # Studio echoes the RunScript source before executing it. Accept
                # only a standalone runtime output line, never a PASS token found
                # inside the echoed source code.
                if ($caseOutput -match $runtimeMarkerPattern) {
                    $markerFound = $true
                    break
                }
            }
            if (
                $studioProcess.HasExited -and
                -not (Test-Path -LiteralPath $caseLockPath) -and
                ([DateTime]::UtcNow - $stableSince).TotalSeconds -ge 20
            ) {
                $runtimeFailure = $true
                $prematureExit = $true
                break
            }
            Start-Sleep -Milliseconds 200
        }

        if (-not $markerFound) {
            if (-not $studioProcess.HasExited) {
                Stop-Process -Id $studioProcess.Id -Force -ErrorAction SilentlyContinue
            }
            $exitDescription = if ($studioProcess.HasExited) {
                "launcher exit $($studioProcess.ExitCode)"
            }
            else {
                'launcher still running'
            }
            $failureReason = if ($runtimeFailure) {
                if ($prematureExit) { 'closed before its success marker' } else { 'reported a runtime failure' }
            }
            else {
                'exceeded 120 seconds'
            }
            [System.IO.File]::AppendAllText(
                $outputPath,
                $caseOutput + "`r`n",
                [System.Text.UTF8Encoding]::new($false)
            )
            throw "Roblox Studio smoke test '$($smokeCase.Script)' $failureReason ($exitDescription).`n$caseOutput"
        }

        if (-not $studioProcess.HasExited -and -not $studioProcess.WaitForExit(15000)) {
            Stop-Process -Id $studioProcess.Id -Force -ErrorAction SilentlyContinue
        }
        # Re-read the complete log after the runtime marker so a late flush cannot
        # hide an execution failure that followed an echoed or partial result.
        $caseOutput = Get-Content -LiteralPath $caseOutputPath -Raw
        if ($caseOutput -match $runtimeFailurePattern -or $caseOutput -notmatch $runtimeMarkerPattern) {
            [System.IO.File]::AppendAllText(
                $outputPath,
                $caseOutput + "`r`n",
                [System.Text.UTF8Encoding]::new($false)
            )
            throw "Roblox Studio smoke test '$($smokeCase.Script)' produced an invalid final log.`n$caseOutput"
        }
        $combinedOutput.Add($caseOutput.Trim())

        # Roblox Studio can delegate to a child process. Give that child time to
        # release this case's lock before starting the next isolated place.
        $releaseDeadline = [DateTime]::UtcNow.AddSeconds(30)
        while ((Test-Path -LiteralPath $caseLockPath) -and [DateTime]::UtcNow -lt $releaseDeadline) {
            Start-Sleep -Milliseconds 250
        }
    }

    $output = $runHeader + "`r`n" + ($combinedOutput -join "`r`n`r`n")
    [System.IO.File]::WriteAllText(
        $outputPath,
        $output + "`r`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host $output
}
finally {
    if (Test-Path -LiteralPath $studioTempRoot) {
        $baseFullPath = [System.IO.Path]::GetFullPath($studioTempBase).TrimEnd('\') + '\'
        $rootFullPath = [System.IO.Path]::GetFullPath($studioTempRoot)
        if (-not $rootFullPath.StartsWith($baseFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove unexpected Studio temp path: $rootFullPath"
        }
        $removed = $false
        for ($attempt = 1; $attempt -le 40; $attempt++) {
            try {
                Remove-Item -LiteralPath $rootFullPath -Recurse -Force
                $removed = $true
                break
            }
            catch {
                Start-Sleep -Milliseconds 250
            }
        }
        if (-not $removed) {
            Write-Warning "Studio temp files are still locked and were left for later cleanup: $rootFullPath"
        }
    }
}
