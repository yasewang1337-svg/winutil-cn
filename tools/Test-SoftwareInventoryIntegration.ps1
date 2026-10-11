[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EvidenceDirectory)

# Real installation is allowed only on an explicitly enabled, disposable hosted VM.
# Keep this guard before filesystem writes, loading product functions or any process.
if ($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
    $env:RUNNER_OS -cne 'Windows' -or $env:WINUTIL_INVENTORY_DISPOSABLE_TEST -cne '1' -or
    $env:GITHUB_RUN_ID -notmatch '^\d+$' -or [Environment]::OSVersion.Platform -ne 'Win32NT') {
    throw 'DISPOSABLE_RUNNER_REQUIRED: Software inventory integration may only run on an explicitly enabled GitHub-hosted Windows VM. No changes were started.'
}
if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP) -or -not [IO.Path]::IsPathRooted($env:RUNNER_TEMP) -or
    -not [IO.Path]::IsPathRooted($EvidenceDirectory)) { throw 'Absolute runner temporary and evidence paths are required.' }

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$runnerRoot = [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\') + '\'
$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory)
if (-not $evidenceRoot.StartsWith($runnerRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'EvidenceDirectory must be a child of RUNNER_TEMP.'
}
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'The disposable runner must already be an administrator; this script never elevates.'
}

$evidenceRoot = Join-Path $evidenceRoot ('ps-' + $PSVersionTable.PSVersion.Major + '-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $evidenceRoot -Force
$utf8 = New-Object Text.UTF8Encoding($false)
$script:nativeSequence = 0
$script:ownsHexyl = $false
$script:hexylExecutable = $null
$script:caseName = 'initialization'
$script:report = [ordered]@{
    SchemaVersion = 1
    StartedAt = [datetime]::UtcNow.ToString('o')
    Status = 'failed'
    SourceCommit = $env:GITHUB_SHA
    RunId = $env:GITHUB_RUN_ID
    RunAttempt = $env:GITHUB_RUN_ATTEMPT
    Environment = [ordered]@{
        RunnerEnvironment = $env:RUNNER_ENVIRONMENT; RunnerOS = $env:RUNNER_OS
        ImageOS = $env:ImageOS; ImageVersion = $env:ImageVersion
        PowerShell = $PSVersionTable.PSVersion.ToString()
    }
    Scope = 'Real installed-package detection on a disposable Windows runner. Only sharkdp.hexyl is installed and removed; existing Chocolatey packages are read only.'
    Cases = [Collections.Generic.List[object]]::new()
    NativeCommands = [Collections.Generic.List[object]]::new()
    Cleanup = [ordered]@{ PackageAbsent = $false; PortableLinkAbsent = $false; ChocolateyUnchanged = $false; InventoryFilesCleaned = $false }
}
$transcriptStarted = $false
$chocoBaseline = $null
$initialInventoryFiles = @()

function Save-InventoryEvidence {
    [IO.File]::WriteAllText((Join-Path $evidenceRoot 'verification.json'),
        ($script:report | ConvertTo-Json -Depth 40), $utf8)
}

function Assert-InventoryCondition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-InventoryIntegrationNative {
    param([string]$Executable, [string[]]$Arguments, [string]$Label)
    $script:nativeSequence++
    $command = Get-Command -Name $Executable -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $prefix = '{0:D2}-{1}' -f $script:nativeSequence, $Label
    $outputPath = Join-Path $evidenceRoot ($prefix + '.stdout.log')
    $errorPath = Join-Path $evidenceRoot ($prefix + '.stderr.log')
    $process = $null
    try {
        # These arguments are test-owned package IDs/switches. No shell is launched.
        $process = Start-Process -FilePath $command.Source -ArgumentList $Arguments -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath -ErrorAction Stop
        $null = $process.Handle
        $process.WaitForExit()
        $process.Refresh()
        $result = [pscustomobject]@{
            Label = $Label; Executable = $command.Source; Arguments = $Arguments
            ExitCode = $process.ExitCode
            ExitCodeHex = ('0x{0:X8}' -f ([long]$process.ExitCode -band 4294967295L))
            StandardOutput = [IO.File]::ReadAllText($outputPath)
            StandardError = [IO.File]::ReadAllText($errorPath)
        }
        $script:report.NativeCommands.Add($result)
        Save-InventoryEvidence
        $result
    } finally { if ($null -ne $process) { $process.Dispose() } }
}

function Get-IntegrationPackageProbe {
    param([string]$Id, [string]$Label)
    Invoke-InventoryIntegrationNative -Executable 'winget.exe' -Arguments @(
        'list', '--id', $Id, '--exact', '--source', 'winget', '--accept-source-agreements', '--disable-interactivity'
    ) -Label $Label
}

function Get-IntegrationInventory {
    param([ValidateSet('Winget', 'Choco')][string]$Manager, $Applications, [string]$Label)
    $snapshot = Get-WinUtilInstalledInventory -Manager $Manager -Applications $Applications -TimeoutSeconds 180
    Assert-InventoryCondition ($snapshot.Manager -eq $Manager) 'Inventory manager identity was lost.'
    Assert-InventoryCondition (@($snapshot.Programs | Where-Object Manager -ne $Manager).Count -eq 0) 'Inventory contains records from another package manager.'
    Assert-InventoryCondition ($snapshot.PackageCount -eq @($snapshot.Programs).Count) 'Package count differs from the returned records.'
    Assert-InventoryCondition ($null -ne $snapshot.CompletedAt) 'Successful inventory has no completion timestamp.'
    [IO.File]::WriteAllText((Join-Path $evidenceRoot ($Label + '.json')), ($snapshot | ConvertTo-Json -Depth 20), $utf8)
    $snapshot
}

function Get-InventoryIdentity {
    param($Snapshot)
    (@($Snapshot.Programs | ForEach-Object { "$($_.Id)|$($_.Version)" } | Sort-Object) -join "`n")
}

try {
    $null = Start-Transcript -Path (Join-Path $evidenceRoot 'transcript.log') -Force
    $transcriptStarted = $true
    Save-InventoryEvidence
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    foreach ($name in @('Invoke-WinUtilInventoryQuery', 'ConvertFrom-WinUtilInventoryData', 'Get-WinUtilInventoryMatches', 'Get-WinUtilInstalledInventory')) {
        $path = Join-Path $repositoryRoot ('functions/private/' + $name + '.ps1')
        . ([scriptblock]::Create([IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false, $true))))
    }
    $initialInventoryFiles = @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Filter 'winutil-inventory-*.json' -File | ForEach-Object FullName)
    $script:caseName = 'real baseline discovery'
    $wingetVersion = Invoke-InventoryIntegrationNative 'winget.exe' @('--version') 'winget-version'
    Assert-InventoryCondition ($wingetVersion.ExitCode -eq 0) 'WinGet is unavailable on the disposable runner.'
    $chocoVersion = Invoke-InventoryIntegrationNative 'choco.exe' @('--version', '--no-color') 'choco-version'
    Assert-InventoryCondition ($chocoVersion.ExitCode -eq 0) 'Chocolatey is unavailable on the disposable runner.'

    $wingetBaseline = Get-IntegrationInventory -Manager Winget -Applications @{} -Label 'baseline-winget'
    $chocoBaseline = Get-IntegrationInventory -Manager Choco -Applications @{} -Label 'baseline-choco'
    Assert-InventoryCondition ($wingetBaseline.PackageCount -gt 0) 'Real WinGet baseline is unexpectedly empty; source availability must be investigated.'
    Assert-InventoryCondition ($chocoBaseline.PackageCount -ge 2) 'At least two existing Chocolatey packages are required for the combination scenario.'
    # Fixture catalog mappings follow the product's ID contract. Do not mistake
    # multiple installed versions of one package for a two-package combination.
    $wingetOnly = @($wingetBaseline.Programs | Where-Object {
        $_.Id -match '^[A-Za-z0-9][A-Za-z0-9._+-]*$' -and $_.Id -notin @($chocoBaseline.Programs.Id)
    }) | Select-Object -First 1
    $chocoOnly = @($chocoBaseline.Programs | Where-Object {
        $_.Id -match '^[A-Za-z0-9][A-Za-z0-9._+-]*$' -and $_.Id -notin @($wingetBaseline.Programs.Id)
    } | Group-Object Id | ForEach-Object { $_.Group[0] } | Select-Object -First 2)
    Assert-InventoryCondition ($null -ne $wingetOnly -and @($chocoOnly).Count -eq 2) 'Could not select distinct real package IDs for source isolation.'
    $probe = Get-IntegrationPackageProbe -Id $wingetOnly.Id -Label 'known-winget-package'
    Assert-InventoryCondition ($probe.ExitCode -eq 0) 'Independent WinGet exact query did not find the baseline package.'
    $chocoList = Invoke-InventoryIntegrationNative 'choco.exe' @('list', '--limit-output', '--no-color') 'independent-choco-list'
    Assert-InventoryCondition ($chocoList.ExitCode -eq 0) 'Independent Chocolatey list failed.'
    foreach ($package in $chocoOnly) {
        Assert-InventoryCondition ($chocoList.StandardOutput -match ('(?m)^' + [regex]::Escape($package.Id) + '\|')) 'Independent Chocolatey list did not contain the baseline package.'
    }
    $script:report.Cases.Add([pscustomobject]@{ Name = $script:caseName; Status = 'passed'; WingetCount = $wingetBaseline.PackageCount; ChocoCount = $chocoBaseline.PackageCount })

    $missingId = 'WinUtil.InventoryMissing.' + [guid]::NewGuid().ToString('N')
    $catalog = [ordered]@{
        WPFInstallKnownWinget = @{ winget = $wingetOnly.Id; choco = 'na' }
        WPFInstallKnownChoco = @{ winget = $missingId; choco = $chocoOnly[0].Id }
        WPFInstallChocoPair = @{ winget = $missingId; choco = ($chocoOnly.Id -join ';') }
        WPFInstallChocoIncomplete = @{ winget = $missingId; choco = ($chocoOnly[0].Id + ';' + $missingId) }
        WPFInstallWrongSource = @{ winget = $chocoOnly[0].Id; choco = $wingetOnly.Id }
        WPFInstallHexyl = @{ winget = 'sharkdp.hexyl'; choco = 'na' }
        WPFInstallHexylWrongSource = @{ winget = $missingId; choco = 'sharkdp.hexyl' }
        WPFInstallWingetPair = @{ winget = ($wingetOnly.Id + ';sharkdp.hexyl'); choco = 'na' }
    }
    $script:caseName = 'existing Chocolatey combination and manager isolation'
    $wingetMatch = Get-IntegrationInventory Winget $catalog 'matched-winget-before'
    $chocoMatch = Get-IntegrationInventory Choco $catalog 'matched-choco-before'
    Assert-InventoryCondition (@($wingetMatch.MatchedKeys) -contains 'WPFInstallKnownWinget') 'Known WinGet package was not matched.'
    Assert-InventoryCondition (@($chocoMatch.MatchedKeys) -contains 'WPFInstallKnownChoco') 'Known Chocolatey package was not matched.'
    Assert-InventoryCondition (@($chocoMatch.MatchedKeys) -contains 'WPFInstallChocoPair') 'Both installed Chocolatey packages must match their combination.'
    foreach ($key in @('WPFInstallChocoIncomplete', 'WPFInstallWrongSource', 'WPFInstallHexylWrongSource')) {
        Assert-InventoryCondition (@($chocoMatch.MatchedKeys) -notcontains $key -and @($wingetMatch.MatchedKeys) -notcontains $key) "Invalid or wrong-source catalog entry matched: $key"
    }
    Assert-InventoryCondition (@($chocoMatch.MatchedKeys) -notcontains 'WPFInstallKnownWinget') 'Chocolatey silently used a WinGet-only catalog mapping.'
    Assert-InventoryCondition (@($wingetMatch.MatchedKeys) -notcontains 'WPFInstallChocoPair') 'WinGet silently used the Chocolatey combination.'
    $script:report.Cases.Add([pscustomobject]@{ Name = $script:caseName; Status = 'passed'; ChocoCombination = @($chocoOnly.Id) })

    $script:caseName = 'real portable package installation and detection'
    $before = Get-IntegrationPackageProbe 'sharkdp.hexyl' 'hexyl-before'
    Assert-InventoryCondition ($before.ExitCodeHex -eq '0x8A150014') 'The exact test package must be absent before this test; refusing to change a pre-existing installation.'
    Assert-InventoryCondition (@($wingetMatch.Programs.Id) -notcontains 'sharkdp.hexyl' -and @($wingetMatch.MatchedKeys) -notcontains 'WPFInstallHexyl') 'Baseline falsely reported hexyl as installed.'
    $script:ownsHexyl = $true
    $install = Invoke-InventoryIntegrationNative 'winget.exe' @('install', '--id', 'sharkdp.hexyl', '--exact', '--source', 'winget', '--silent', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity') 'hexyl-install'
    Assert-InventoryCondition ($install.ExitCode -eq 0) 'Real hexyl installation failed; this is not treated as an empty inventory.'
    $afterProbe = Get-IntegrationPackageProbe 'sharkdp.hexyl' 'hexyl-after-install'
    Assert-InventoryCondition ($afterProbe.ExitCode -eq 0) 'Independent exact query did not find the installed test package.'
    $after = Get-IntegrationInventory Winget $catalog 'matched-winget-after-install'
    Assert-InventoryCondition (@($after.Programs.Id) -contains 'sharkdp.hexyl') 'New installation was not present in the structured inventory.'
    Assert-InventoryCondition (@($after.MatchedKeys) -contains 'WPFInstallHexyl' -and @($after.MatchedKeys) -contains 'WPFInstallWingetPair') 'New installation or complete WinGet combination was not matched.'
    $chocoAfter = Get-IntegrationInventory Choco $catalog 'matched-choco-after-install'
    Assert-InventoryCondition (@($chocoAfter.MatchedKeys) -notcontains 'WPFInstallHexyl' -and @($chocoAfter.MatchedKeys) -notcontains 'WPFInstallHexylWrongSource') 'WinGet installation leaked into Chocolatey matches.'
    foreach ($candidate in @((Join-Path $env:LOCALAPPDATA 'Microsoft/WinGet/Links/hexyl.exe'), (Join-Path $env:ProgramFiles 'WinGet/Links/hexyl.exe'))) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $script:hexylExecutable = $candidate; break }
    }
    Assert-InventoryCondition ([bool]$script:hexylExecutable) 'The real portable executable link was not created.'
    $hexylVersion = Invoke-InventoryIntegrationNative $script:hexylExecutable @('--version') 'hexyl-version'
    Assert-InventoryCondition ($hexylVersion.ExitCode -eq 0 -and $hexylVersion.StandardOutput -match '^hexyl\s+\d+\.') 'The installed executable did not run as hexyl.'
    $script:report.Cases.Add([pscustomobject]@{ Name = $script:caseName; Status = 'passed'; Package = 'sharkdp.hexyl'; DetectedVersion = @($after.Programs | Where-Object Id -eq 'sharkdp.hexyl')[0].Version })

    $script:caseName = 'real uninstall and fresh inventory'
    $uninstall = Invoke-InventoryIntegrationNative 'winget.exe' @('uninstall', '--id', 'sharkdp.hexyl', '--exact', '--silent', '--disable-interactivity', '--accept-source-agreements') 'hexyl-uninstall'
    Assert-InventoryCondition ($uninstall.ExitCode -eq 0) 'Real hexyl uninstall failed.'
    $removedProbe = Get-IntegrationPackageProbe 'sharkdp.hexyl' 'hexyl-after-uninstall'
    Assert-InventoryCondition ($removedProbe.ExitCodeHex -eq '0x8A150014') 'The exact package still exists or its absence cannot be established.'
    $removed = Get-IntegrationInventory Winget $catalog 'matched-winget-after-uninstall'
    Assert-InventoryCondition (@($removed.Programs.Id) -notcontains 'sharkdp.hexyl') 'Removed package remained in a fresh structured inventory.'
    Assert-InventoryCondition (@($removed.MatchedKeys) -notcontains 'WPFInstallHexyl' -and @($removed.MatchedKeys) -notcontains 'WPFInstallWingetPair') 'Removed package or incomplete combination remained matched.'
    Assert-InventoryCondition (-not (Test-Path -LiteralPath $script:hexylExecutable)) 'The installed portable link remained after uninstall.'
    $script:ownsHexyl = $false
    $script:report.Cleanup.PackageAbsent = $true
    $script:report.Cleanup.PortableLinkAbsent = $true
    $script:report.Cases.Add([pscustomobject]@{ Name = $script:caseName; Status = 'passed' })
} catch {
    $script:report.Failure = [ordered]@{ Case = $script:caseName; Message = $_.Exception.Message; Stack = $_.ScriptStackTrace }
    if ($_.Exception.Data.Contains('InventoryDiagnostics')) { $script:report.Failure.InventoryDiagnostics = $_.Exception.Data['InventoryDiagnostics'] }
} finally {
    try {
        if ($script:ownsHexyl) {
            $cleanupProbe = Get-IntegrationPackageProbe 'sharkdp.hexyl' 'cleanup-hexyl-probe'
            if ($cleanupProbe.ExitCode -eq 0) {
                $cleanupResult = Invoke-InventoryIntegrationNative 'winget.exe' @('uninstall', '--id', 'sharkdp.hexyl', '--exact', '--silent', '--disable-interactivity', '--accept-source-agreements') 'cleanup-hexyl-uninstall'
                Assert-InventoryCondition ($cleanupResult.ExitCode -eq 0) 'Cleanup uninstall failed.'
            } else { Assert-InventoryCondition ($cleanupProbe.ExitCodeHex -eq '0x8A150014') 'Cleanup could not determine the test package state.' }
            $cleanupAfter = Get-IntegrationPackageProbe 'sharkdp.hexyl' 'cleanup-hexyl-final'
            $script:report.Cleanup.PackageAbsent = $cleanupAfter.ExitCodeHex -eq '0x8A150014'
            $script:report.Cleanup.PortableLinkAbsent = -not $script:hexylExecutable -or -not (Test-Path -LiteralPath $script:hexylExecutable)
            Assert-InventoryCondition ($script:report.Cleanup.PackageAbsent -and $script:report.Cleanup.PortableLinkAbsent) 'Cleanup could not verify removal of the test package.'
        }
        if ($null -ne $chocoBaseline) {
            $chocoFinal = Get-IntegrationInventory Choco @{} 'final-choco'
            $script:report.Cleanup.ChocolateyUnchanged = (Get-InventoryIdentity $chocoFinal) -ceq (Get-InventoryIdentity $chocoBaseline)
            Assert-InventoryCondition $script:report.Cleanup.ChocolateyUnchanged 'Existing Chocolatey package IDs/versions changed.'
        }
        $leftovers = @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Filter 'winutil-inventory-*.json' -File | Where-Object FullName -notin $initialInventoryFiles)
        $script:report.Cleanup.InventoryFilesCleaned = $leftovers.Count -eq 0
        Assert-InventoryCondition $script:report.Cleanup.InventoryFilesCleaned 'Inventory left temporary export files behind.'
    } catch { $script:report.CleanupError = $_.Exception.Message }
    $script:report.FinishedAt = [datetime]::UtcNow.ToString('o')
    if (-not $script:report.Contains('Failure') -and -not $script:report.Contains('CleanupError') -and $script:report.Cases.Count -eq 4) {
        $script:report.Status = 'passed'
    }
    Save-InventoryEvidence
    if ($transcriptStarted) { $null = Stop-Transcript }
}

Write-Output ("Software inventory integration: {0}; evidence: {1}" -f $script:report.Status, $evidenceRoot)
if ($script:report.Status -ne 'passed') { throw 'Real software inventory verification failed; inspect verification.json and command logs.' }
