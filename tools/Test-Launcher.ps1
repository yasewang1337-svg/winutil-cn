[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Load the net48 assembly inside Windows PowerShell instead of starting its
# requireAdministrator entry point. Only the harmless fixture is ever embedded.
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) {
    throw 'Run this test with Windows PowerShell 5.1: powershell.exe -NoProfile -File ./tools/Test-Launcher.ps1'
}
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw 'A .NET SDK is required to build the launcher regression fixture.'
}

function Assert-LauncherTest {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-SharingViolation {
    param([scriptblock]$Action, [string]$Operation)
    try {
        & $Action
    } catch {
        $exception = $_.Exception.GetBaseException()
        if ($exception -is [IO.IOException] -and ($exception.HResult -band 0xffff) -eq 32) {
            return
        }
        throw "Expected a file sharing violation for $Operation, but received: $exception"
    }
    throw "The extracted script allowed $Operation while the launcher held its handle."
}

function Get-ExtractedHash {
    param([IO.FileStream]$Stream)
    $position = $Stream.Position
    try {
        $Stream.Position = 0
        (Get-FileHash -InputStream $Stream -Algorithm SHA256).Hash
    } finally {
        $Stream.Position = $position
    }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $repoRoot 'pester/fixtures/launcher-smoke.ps1'
$source = Join-Path $PSScriptRoot 'launcher'
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'winutil-launcher-test-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempBase $testName
$project = Join-Path $testRoot 'project with spaces'
$output = Join-Path $testRoot 'fixture-output.json'
$extracted = $null
$stream = $null
$oldPath = $env:PATH
$oldOutput = $env:WINUTIL_LAUNCHER_TEST_OUTPUT

try {
    $null = New-Item -ItemType Directory -Path $project -Force
    foreach ($file in @('Launcher.cs', 'WinUtilCN.Launcher.csproj', 'app.manifest', 'icon.ico', 'build.ps1')) {
        Copy-Item -LiteralPath (Join-Path $source $file) -Destination (Join-Path $project $file)
    }
    $buildBytes = [IO.File]::ReadAllBytes((Join-Path $project 'build.ps1'))
    Assert-LauncherTest ($buildBytes.Length -ge 3 -and ($buildBytes[0..2] -join ',') -eq '239,187,191') 'The build script must retain a UTF-8 BOM for Windows PowerShell 5.1 on non-UTF8 Windows installations.'
    $fixtureBytes = [IO.File]::ReadAllBytes($fixture)
    Assert-LauncherTest ($fixtureBytes.Length -ge 3 -and ($fixtureBytes[0..2] -join ',') -eq '239,187,191') 'The fixture must retain a UTF-8 BOM for Windows PowerShell 5.1.'

    $testExe = Join-Path $testRoot 'fixture-launcher.exe'
    & (Join-Path $project 'build.ps1') -ScriptPath $fixture -OutFile $testExe
    $assembly = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes($testExe))
    $launcher = $assembly.GetType('WinUtilCN.Launcher', $true)
    $flags = [Reflection.BindingFlags]'NonPublic, Static'
    $extract = $launcher.GetMethod('ExtractScript', $flags)
    $resolve = $launcher.GetMethod('ResolvePowerShell', $flags)
    $run = $launcher.GetMethod('RunPowerShell', $flags)
    $cleanup = $launcher.GetMethod('TryDelete', $flags)
    foreach ($method in @($extract, $resolve, $run, $cleanup)) {
        Assert-LauncherTest ($null -ne $method) 'A required launcher test boundary is missing.'
    }

    # PATH must not be able to select an attacker-controlled executable.
    [IO.File]::WriteAllText((Join-Path $testRoot 'powershell.exe'), 'This is not an executable.')
    $env:PATH = $testRoot
    try {
        $resolvedPowerShell = [string]$resolve.Invoke($null, $null)
    } finally {
        $env:PATH = $oldPath
    }
    $systemPowerShell = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::System)) 'WindowsPowerShell/v1.0/powershell.exe'
    Assert-LauncherTest ([IO.Path]::IsPathRooted($resolvedPowerShell) -and $resolvedPowerShell -ieq $systemPowerShell -and [IO.File]::Exists($resolvedPowerShell)) 'The launcher did not resolve the trusted system PowerShell path.'
    Write-Host 'PASS: PowerShell resolves to the system path even with a hostile PATH.'

    $stream = $extract.Invoke($null, $null)
    Assert-LauncherTest ($stream -is [IO.FileStream]) 'ExtractScript must return the still-open FileStream.'
    $extracted = $stream.Name
    $fixtureHash = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
    Assert-LauncherTest ((Get-ExtractedHash -Stream $stream) -ceq $fixtureHash) 'Extraction changed the embedded script bytes.'
    Assert-LauncherTest ((Get-FileHash -LiteralPath $extracted -Algorithm SHA256).Hash -ceq $fixtureHash) 'A normal read-only consumer must be able to read the protected script.'

    Assert-SharingViolation -Operation 'write access' -Action {
        $writer = [IO.File]::Open($extracted, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
        $writer.Dispose()
    }
    $replacement = Join-Path $testRoot 'replacement.ps1'
    $replacementBackup = Join-Path $testRoot 'replacement-backup.ps1'
    [IO.File]::WriteAllText($replacement, '# harmless replacement')
    Assert-SharingViolation -Operation 'atomic replacement' -Action { [IO.File]::Replace($replacement, $extracted, $replacementBackup) }
    Assert-SharingViolation -Operation 'deletion' -Action { [IO.File]::Delete($extracted) }
    Assert-LauncherTest ((Get-ExtractedHash -Stream $stream) -ceq $fixtureHash) 'The protected script changed after a denied mutation.'
    Write-Host 'PASS: Extracted bytes match; writes, replacement and deletion are denied while held open.'

    $expected = [string[]]@(
        'simple',
        'value with spaces',
        '中文参数',
        'embedded "double quote"',
        'C:\folder with spaces\',
        'prefix\\"quoted"suffix\',
        "tab`tseparated",
        'literal $(throw "must not execute")',
        '-SwitchLikeText'
    )
    $env:WINUTIL_LAUNCHER_TEST_OUTPUT = $output
    $invokeArguments = New-Object object[] 2
    $invokeArguments[0] = $extracted
    $invokeArguments[1] = $expected
    $exitCode = $run.Invoke($null, $invokeArguments)
    Assert-LauncherTest ($exitCode -eq 37) "The fixture exit code was not propagated: $exitCode"
    $result = Get-Content -LiteralPath $output -Encoding UTF8 -Raw | ConvertFrom-Json
    Assert-LauncherTest ($result.PowerShellMajorVersion -eq 5) 'The fixture did not run in Windows PowerShell 5.1.'
    Assert-LauncherTest (@($result.Arguments).Count -eq $expected.Count) 'The argument count changed in transit.'
    for ($index = 0; $index -lt $expected.Count; $index++) {
        Assert-LauncherTest ($result.Arguments[$index] -ceq $expected[$index]) "Argument $index changed in transit. Expected <$($expected[$index])>, received <$($result.Arguments[$index])>."
    }
    Write-Host 'PASS: Spaces, Chinese, quotes, backslashes and literal expressions survive; exit code 37 is preserved.'

    $stream.Dispose()
    $stream = $null
    $null = $cleanup.Invoke($null, [object[]]@($extracted))
    Assert-LauncherTest (-not [IO.File]::Exists($extracted)) 'The launcher did not clean up the released script.'
    Write-Host 'PASS: Extracted fixture is deleted after the handle is closed.'
} finally {
    $env:PATH = $oldPath
    $env:WINUTIL_LAUNCHER_TEST_OUTPUT = $oldOutput
    if ($null -ne $stream) { $stream.Dispose() }
    if ($extracted -and [IO.File]::Exists($extracted)) {
        Remove-Item -LiteralPath $extracted -Force
    }
    # Resolve and constrain the recursive cleanup to this test's own directory.
    if (Test-Path -LiteralPath $testRoot) {
        $cleanupRoot = (Resolve-Path -LiteralPath $testRoot).Path
        if ((Split-Path $cleanupRoot -Parent) -ine $tempBase -or (Split-Path $cleanupRoot -Leaf) -cne $testName) {
            throw "Refusing to clean an unexpected test directory: $cleanupRoot"
        }
        Remove-Item -LiteralPath $cleanupRoot -Recurse -Force
    }
}

Write-Host 'Launcher regression tests passed without starting WinUtil or requesting elevation.'
