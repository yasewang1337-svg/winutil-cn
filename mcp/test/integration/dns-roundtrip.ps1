<#
Real DNS integration test for an ephemeral GitHub-hosted Windows runner only.
Creates one inbox Microsoft loopback device, never changes an existing adapter.
Every worker operation uses the shipped, unmodified PowerShell 5.1 entry point.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [string]$WorkerPath = (Join-Path $PSScriptRoot '..\..\powershell\worker.ps1')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# This guard runs before Add-Type, adapter enumeration, file creation or mutation.
if ($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
    $env:RUNNER_OS -cne 'Windows' -or $env:WINUTIL_MCP_DISPOSABLE_TEST -cne '1') {
    '{"status":"blocked","code":"DISPOSABLE_RUNNER_REQUIRED","message":"Real DNS tests require the explicit disposable GitHub-hosted Windows job."}'
    exit 2
}
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
try { $isAdministrator = (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
finally { $identity.Dispose() }
if (-not $isAdministrator -or -not [Environment]::Is64BitProcess) {
    '{"status":"blocked","code":"ELEVATED_X64_RUNNER_REQUIRED"}'
    exit 2
}

$runnerRoot = [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\') + '\'
$EvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory)
if (-not $EvidenceDirectory.StartsWith($runnerRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Evidence must be inside RUNNER_TEMP.' }
$null = New-Item -ItemType Directory -Path $EvidenceDirectory -Force
$WorkerPath = (Resolve-Path -LiteralPath $WorkerPath).Path
$workerExecutable = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$utf8 = New-Object Text.UTF8Encoding($false)
$checks = New-Object 'System.Collections.Generic.List[object]'
$backups = New-Object 'System.Collections.Generic.List[string]'
$summary = [ordered]@{
    schemaVersion = 1; status = 'blocked'; suite = 'real-dns-roundtrip'; startedUtc = [DateTime]::UtcNow.ToString('o')
    sourceCommit = $env:GITHUB_SHA; runner = $env:RUNNER_NAME; runnerImage = $env:ImageOS
    worker = $WorkerPath; workerSha256 = (Get-FileHash -LiteralPath $WorkerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    workerPowerShell = $workerExecutable; tests = $checks; cleanup = [ordered]@{}
}
$device = $null
$adapter = $null
$existing = @()
$beforeExisting = @()
$backupRoot = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'WinUtil-CN-MCP'

function Save-Json([string]$Name, $Value) {
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory $Name), ($Value | ConvertTo-Json -Depth 50), $utf8)
}
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Add-Check([string]$Name, $Details = $null) {
    $checks.Add([pscustomobject]@{ name = $Name; status = 'passed'; details = $Details })
    Write-Host "PASS: $Name"
}
function Normalize-Addresses([object[]]$Addresses) {
    return @($Addresses | ForEach-Object { ([Net.IPAddress]::Parse([string]$_)).ToString() })
}
function Get-AdapterIdentity($Item) {
    return [pscustomobject]@{
        id = ([guid]$Item.InterfaceGuid).ToString('D').ToLowerInvariant(); interfaceIndex = [int]$Item.ifIndex
        name = [string]$Item.Name; macAddress = [string]$Item.MacAddress; description = [string]$Item.InterfaceDescription
    }
}
function Read-DnsState($Identity, [switch]$AllowMissingFamily) {
    # Independent verification, not the worker's snapshot helper or returned result.
    $families = foreach ($family in @('IPv4', 'IPv6')) {
        $service = if ($family -ceq 'IPv4') { 'Tcpip' } else { 'Tcpip6' }
        $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + $service + '\Parameters\Interfaces\{' + $Identity.id + '}'
        $configured = ''
        if (Test-Path -LiteralPath $path) {
            $key = Get-Item -LiteralPath $path
            try { $configured = [string]$key.GetValue('NameServer', '') } finally { $key.Close() }
        }
        $actual = @(Get-DnsClientServerAddress -InterfaceIndex $Identity.interfaceIndex -AddressFamily $family -ErrorAction SilentlyContinue)
        Assert-True ($actual.Count -eq 1 -or ($AllowMissingFamily -and $actual.Count -eq 0)) "Expected exactly one $family DNS interface for $($Identity.id)."
        $effective = if ($actual.Count -eq 1) { @(Normalize-Addresses @($actual[0].ServerAddresses)) } else { @() }
        [pscustomobject]@{
            family = $family; available = ($actual.Count -eq 1); automatic = [string]::IsNullOrWhiteSpace($configured)
            configured = @(Normalize-Addresses @($configured -split '[,;\s]+' | Where-Object { $_ }))
            effective = @($effective)
        }
    }
    return [pscustomobject]@{ id = $Identity.id; interfaceIndex = $Identity.interfaceIndex; families = @($families) }
}
function State-Key($State) { return ($State | ConvertTo-Json -Depth 15 -Compress) }
function Assert-State($Actual, $Expected, [string]$Label) {
    Assert-True ((State-Key $Actual) -ceq (State-Key $Expected)) "$Label DNS state differs. Expected $(State-Key $Expected); actual $(State-Key $Actual)."
}
function Assert-StaticState($State, [string[]]$Addresses) {
    foreach ($family in $State.families) {
        $expected = @(Normalize-Addresses @($Addresses | Where-Object {
            (([Net.IPAddress]::Parse($_).AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork) -eq ($family.family -ceq 'IPv4'))
        }))
        Assert-True (-not $family.automatic) "$($family.family) unexpectedly remains automatic."
        Assert-True (($family.configured -join ',') -ceq ($expected -join ',')) "$($family.family) registry configuration does not match the requested DNS addresses."
        Assert-True (($family.effective -join ',') -ceq ($expected -join ',')) "$($family.family) Get-DnsClientServerAddress does not match the requested DNS addresses."
    }
}
function Assert-ExistingUnchanged {
    $now = @(Get-NetAdapter -IncludeHidden -ErrorAction Stop)
    foreach ($entry in $beforeExisting) {
        $matched = @($now | Where-Object { ([guid]$_.InterfaceGuid).ToString('D').ToLowerInvariant() -ceq $entry.identity.id })
        Assert-True ($matched.Count -eq 1) "An existing adapter disappeared or lost its unique identity: $($entry.identity.id)."
        $currentIdentity = Get-AdapterIdentity $matched[0]
        Assert-True ($currentIdentity.interfaceIndex -eq $entry.identity.interfaceIndex -and $currentIdentity.macAddress -ceq $entry.identity.macAddress) 'An existing adapter identity changed.'
        Assert-State (Read-DnsState $currentIdentity -AllowMissingFamily) $entry.dns 'Existing adapter'
    }
}
function Quote-Native([string]$Value) {
    if ($Value.Contains('"') -or $Value.Contains([char]0)) { throw 'Unsafe native argument.' }
    return '"' + $Value + '"'
}
function Invoke-Worker([string]$Name, $Request = $null, [string]$RestoreId = '', [switch]$ExpectFailure) {
    $arguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', (Quote-Native $WorkerPath))
    if ($RestoreId) { $arguments += @('-RestoreBackupId', $RestoreId) }
    else {
        $inputPath = Join-Path $EvidenceDirectory ($Name + '.request.json')
        [IO.File]::WriteAllText($inputPath, ($Request | ConvertTo-Json -Depth 35 -Compress), $utf8)
        $hash = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $arguments += @('-InputPath', (Quote-Native $inputPath), '-ExpectedSha256', $hash)
    }
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $workerExecutable
    $start.Arguments = $arguments -join ' '
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = $utf8
    $start.StandardErrorEncoding = $utf8
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    try {
        Assert-True ($process.Start()) 'Worker process could not start.'
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(120000)) { $process.Kill(); $process.WaitForExit(); throw 'Worker timed out.' }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
    } finally { $process.Dispose() }
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory ($Name + '.stdout.log')), $stdout, $utf8)
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory ($Name + '.stderr.log')), $stderr, $utf8)
    $messages = @($stdout -split '\r?\n' | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json -ErrorAction Stop })
    $final = @($messages | Where-Object { $null -eq $_.PSObject.Properties['checkpoint'] })
    Assert-True ($final.Count -eq 1) "${Name}: worker did not return exactly one final JSON response."
    $result = $final[0]
    Save-Json ($Name + '.result.json') ([ordered]@{ exitCode = $exitCode; response = $result; stdout = $stdout; stderr = $stderr })
    if ($ExpectFailure) {
        Assert-True ($exitCode -ne 0 -and $result.status -cne 'completed') "$Name unexpectedly succeeded."
    } else {
        Assert-True ($exitCode -eq 0 -and $result.status -ceq 'completed' -and [string]::IsNullOrWhiteSpace($stderr)) "$Name failed: exit $exitCode; $stdout; $stderr"
    }
    Assert-ExistingUnchanged
    return $result
}
function New-DnsRequest([string]$Provider, [string[]]$Addresses, $Target = $adapter) {
    $id = [guid]::NewGuid().ToString('D').ToLowerInvariant()
    $backups.Add($id)
    return [ordered]@{ schemaVersion = 1; operation = 'set_dns'; provider = $Provider; addresses = @($Addresses); adapters = @($Target); backupId = $id }
}
function Retain-Backup([string]$Id) {
    $path = Join-Path $backupRoot ($Id + '.json')
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Worker reported a missing backup: $Id."
    $backup = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    Save-Json ('backup-' + $Id + '.json') $backup
    return $path
}

try {
    foreach ($command in @('Get-NetAdapter', 'Get-DnsClientServerAddress', 'Set-DnsClientServerAddress')) { $null = Get-Command $command -ErrorAction Stop }
    $existing = @(Get-NetAdapter -IncludeHidden -ErrorAction Stop)
    # All existing adapters with any DNS family are compared after every worker call.
    # Interfaces without an IP stack have no DNS configuration to compare.
    $beforeExisting = @($existing | ForEach-Object {
        $item = Get-AdapterIdentity $_
        $dnsRows = @(Get-DnsClientServerAddress -InterfaceIndex $item.interfaceIndex -ErrorAction SilentlyContinue)
        if ($dnsRows.Count -gt 0) {
            [pscustomobject]@{ identity = $item; dns = Read-DnsState $item -AllowMissingFamily }
        }
    })
    Assert-True ($beforeExisting.Count -gt 0) 'No existing IP adapter is available for the noninterference assertion.'
    Save-Json 'existing-adapters-before.json' $beforeExisting
    Add-Type -Path (Join-Path $PSScriptRoot 'DisposableLoopback.cs')
    $device = [WinUtilMcp.Integration.DisposableLoopback]::Create()
    $summary.device = [ordered]@{ instanceId = $device.InstanceId; driverProvider = $device.DriverProvider; driverDescription = $device.DriverDescription }
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    do {
        $matches = @(Get-NetAdapter -IncludeHidden -ErrorAction Stop | Where-Object { [string]$_.PnPDeviceID -ieq $device.InstanceId })
        if ($matches.Count -eq 1) { break }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    Assert-True ($matches.Count -eq 1) 'The newly created loopback device did not expose a unique network adapter.'
    $adapter = Get-AdapterIdentity $matches[0]
    Assert-True (@($existing | Where-Object { ([guid]$_.InterfaceGuid).ToString('D').ToLowerInvariant() -ceq $adapter.id }).Count -eq 0) 'The test must never select an existing adapter.'
    $routes = @(Get-NetRoute -InterfaceIndex $adapter.interfaceIndex -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -in @('0.0.0.0/0', '::/0') })
    Assert-True ($routes.Count -eq 0) 'The test adapter unexpectedly owns a default route.'
    $summary.device.adapter = $adapter
    $baseline = Read-DnsState $adapter
    Assert-True (@($baseline.families | Where-Object { -not $_.automatic }).Count -eq 0) 'A fresh loopback adapter must begin with automatic DNS.'
    Save-Json 'loopback-baseline.json' $baseline
    Assert-ExistingUnchanged
    Add-Check 'isolated inbox loopback created without changing existing adapters' $summary.device
    $summary.status = 'failed'

    $wrong = $adapter | ConvertTo-Json | ConvertFrom-Json
    $wrong.macAddress = '00-00-00-00-00-00-WRONG'
    $badRequest = New-DnsRequest 'TestA' @('192.0.2.53', '2001:db8::53') $wrong
    $bad = Invoke-Worker 'identity-mismatch-write' -Request $badRequest -ExpectFailure
    Assert-True (($bad | ConvertTo-Json -Depth 20 -Compress) -match 'ADAPTER_CHANGED') 'Wrong adapter identity was not explicitly rejected.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $backupRoot ($badRequest.backupId + '.json')))) 'Identity rejection should happen before creating a backup or writing DNS.'
    Assert-State (Read-DnsState $adapter) $baseline 'Rejected request'
    Add-Check 'wrong identity rejected before writing or backing up'

    $addressesA = @('192.0.2.53', '192.0.2.54', '2001:db8::53', '2001:db8::54')
    $addressesB = @('198.51.100.53', '198.51.100.54', '2001:db8:1::53', '2001:db8:1::54')
    $requestA = New-DnsRequest 'TestA' $addressesA
    $resultA = Invoke-Worker 'automatic-to-static' -Request $requestA
    $null = Retain-Backup $requestA.backupId
    Assert-True ($resultA.backupId -ceq $requestA.backupId) 'Worker backup ID mismatch.'
    Assert-StaticState (Read-DnsState $adapter) $addressesA
    Add-Check 'real IPv4 and IPv6 static DNS values match the request'
    $null = Invoke-Worker 'restore-automatic' -RestoreId $requestA.backupId
    Assert-State (Read-DnsState $adapter) $baseline 'Restore automatic'
    Add-Check 'RestoreBackupId restores automatic DNS and original effective values'

    $requestOriginal = New-DnsRequest 'TestA' $addressesA
    $null = Invoke-Worker 'static-original' -Request $requestOriginal
    $originalBackupPath = Retain-Backup $requestOriginal.backupId
    $originalA = Read-DnsState $adapter
    Assert-StaticState $originalA $addressesA
    $requestB = New-DnsRequest 'TestB' $addressesB
    $null = Invoke-Worker 'static-replacement' -Request $requestB
    $null = Retain-Backup $requestB.backupId
    Assert-StaticState (Read-DnsState $adapter) $addressesB
    $null = Invoke-Worker 'restore-static-original' -RestoreId $requestB.backupId
    Assert-State (Read-DnsState $adapter) $originalA 'Restore original static addresses'
    Add-Check 'RestoreBackupId restores original static IPv4 and IPv6 addresses in order'

    $requestDefault = New-DnsRequest 'Default' @()
    $null = Invoke-Worker 'static-to-default' -Request $requestDefault
    $null = Retain-Backup $requestDefault.backupId
    Assert-State (Read-DnsState $adapter) $baseline 'Default provider'
    $null = Invoke-Worker 'restore-after-default' -RestoreId $requestDefault.backupId
    Assert-State (Read-DnsState $adapter) $originalA 'Restore after Default'
    Add-Check 'Default resets both families and its backup restores original static values'

    # Corrupt only the identity of this test's own backup, preserving its ACL.
    # Its target GUID remains the new disposable adapter, never an existing one.
    $originalBytes = [IO.File]::ReadAllBytes($originalBackupPath)
    try {
        $mismatchBackup = $utf8.GetString($originalBytes) | ConvertFrom-Json
        $mismatchBackup.entries[0].adapter.description += ' (identity changed fixture)'
        Save-Json 'identity-mismatch-restore.fixture.json' $mismatchBackup
        [IO.File]::WriteAllText($originalBackupPath, ($mismatchBackup | ConvertTo-Json -Depth 40 -Compress), $utf8)
        $rejectedRestore = Invoke-Worker 'identity-mismatch-restore' -RestoreId $requestOriginal.backupId -ExpectFailure
        Assert-True (($rejectedRestore | ConvertTo-Json -Depth 20 -Compress) -match 'ADAPTER_CHANGED') 'Restore did not reject mismatched adapter identity.'
        Assert-State (Read-DnsState $adapter) $originalA 'Rejected restore'
    } finally { [IO.File]::WriteAllBytes($originalBackupPath, $originalBytes) }
    Add-Check 'RestoreBackupId rejects a changed adapter identity without changing DNS'
    $null = Invoke-Worker 'final-restore-baseline' -RestoreId $requestOriginal.backupId
    Assert-State (Read-DnsState $adapter) $baseline 'Final restore'
    Add-Check 'final original automatic state verified before removing test device'
    $summary.status = 'passed'
} catch {
    $summary.error = $_.Exception.Message
    $summary.scriptStackTrace = $_.ScriptStackTrace
    Write-Host "DNS integration $($summary.status): $($_.Exception.Message)"
} finally {
    if ($null -ne $device) {
        try {
            $instanceId = $device.InstanceId
            $device.Dispose()
            Assert-True ($device.Removed) 'The scoped test device was not removed.'
            $remaining = @(Get-NetAdapter -IncludeHidden -ErrorAction Stop | Where-Object { [string]$_.PnPDeviceID -ieq $instanceId })
            Assert-True ($remaining.Count -eq 0) 'The test adapter still exists after scoped removal.'
            $summary.cleanup.testDeviceRemoved = $true
        } catch { $summary.status = 'failed'; $summary.cleanup.deviceError = $_.Exception.Message }
    }
    foreach ($id in $backups) {
        try {
            Assert-True ($id -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') 'Invalid generated backup ID.'
            $path = [IO.Path]::GetFullPath((Join-Path $backupRoot ($id + '.json')))
            Assert-True ($path.StartsWith(([IO.Path]::GetFullPath($backupRoot).TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) 'Backup cleanup is outside the fixed backup directory.'
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                $entry = Get-Item -LiteralPath $path
                Assert-True (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Backup cleanup rejects reparse points.'
                Save-Json ('backup-' + $id + '.json') (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
                Remove-Item -LiteralPath $path -Force
            }
        } catch { $summary.status = 'failed'; $summary.cleanup.backupError = $_.Exception.Message }
    }
    if ($beforeExisting.Count -gt 0) {
        try { Assert-ExistingUnchanged; $summary.cleanup.existingAdaptersUnchanged = $true }
        catch { $summary.status = 'failed'; $summary.cleanup.existingAdaptersError = $_.Exception.Message }
    }
    $summary.finishedUtc = [DateTime]::UtcNow.ToString('o')
    Save-Json 'dns-roundtrip.json' $summary
}
$summary | ConvertTo-Json -Depth 50
if ($summary.status -ceq 'passed') { exit 0 }
if ($summary.status -ceq 'blocked') { exit 2 }
exit 1
