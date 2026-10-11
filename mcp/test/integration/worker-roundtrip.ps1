[CmdletBinding()]
param(
    [ValidateSet('powershell.exe', 'pwsh.exe')][string]$PowerShellExecutable = 'powershell.exe',
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory
)

# This file deliberately performs real Windows writes. Never weaken these guards or
# set the flags on a workstation: only an ephemeral GitHub-hosted runner is allowed.
if ($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or
    $env:RUNNER_OS -cne 'Windows' -or $env:WINUTIL_MCP_DISPOSABLE_TEST -cne '1') {
    throw 'DISPOSABLE_RUNNER_REQUIRED: Real modification tests only run in an explicitly opted-in GitHub-hosted Windows runner.'
}

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
Set-StrictMode -Version Latest
$worker = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../powershell/worker.ps1'))
$runnerRoot = [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\') + '\'
$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory)
if (-not $evidenceRoot.StartsWith($runnerRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'EvidenceDirectory must be a child of RUNNER_TEMP.'
}
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Hosted runner must already be an administrator; this test never elevates.' }
$shell = (Get-Command $PowerShellExecutable -CommandType Application -ErrorAction Stop).Source
$runId = [guid]::NewGuid().ToString('N')
$evidenceRoot = Join-Path $evidenceRoot ('worker-' + [IO.Path]::GetFileNameWithoutExtension($PowerShellExecutable) + '-' + $runId)
$null = New-Item -ItemType Directory -Path $evidenceRoot -Force
$keySubPath = 'Software\WinUtilCnMcpIntegration_' + $runId
$serviceName = 'WinUtilMcpTest_' + $runId
$backupRoot = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'WinUtil-CN-MCP'
$script:backupIds = New-Object 'System.Collections.Generic.List[string]'
$script:createdHives = New-Object 'System.Collections.Generic.List[string]'
$script:cases = New-Object 'System.Collections.Generic.List[object]'
$script:cleanup = New-Object 'System.Collections.Generic.List[object]'
$script:serviceCreated = $false
$script:requestNumber = 0
$script:failure = $null
$encoding = New-Object Text.UTF8Encoding($false)

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Convert-StableJson {
    param($Value)
    ConvertTo-Json -InputObject $Value -Depth 40 -Compress
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    $left = Convert-StableJson $Expected
    $right = Convert-StableJson $Actual
    if ($left -cne $right) { throw ($Message + ": expected $left; actual $right") }
}

function Open-TestBase {
    param([ValidateSet('HKCU', 'HKLM')][string]$Hive)
    $kind = if ($Hive -eq 'HKCU') { [Microsoft.Win32.RegistryHive]::CurrentUser } else { [Microsoft.Win32.RegistryHive]::LocalMachine }
    [Microsoft.Win32.RegistryKey]::OpenBaseKey($kind, [Microsoft.Win32.RegistryView]::Registry64)
}

function Assert-TestKey {
    param([string]$SubPath)
    if ($SubPath -cne $keySubPath -and -not $SubPath.StartsWith($keySubPath + '\', [StringComparison]::Ordinal)) {
        throw 'Registry test helper refused a path outside its unique test key.'
    }
}

function Set-TestValue {
    param([string]$Hive, [string]$SubPath, [string]$Name, [string]$Type, $Value)
    Assert-TestKey $SubPath
    $base = Open-TestBase $Hive
    $key = $null
    try {
        $key = $base.CreateSubKey($SubPath)
        $key.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]::$Type)
    } finally { if ($null -ne $key) { $key.Dispose() }; $base.Dispose() }
}

function Read-TestValue {
    param([string]$Hive, [string]$SubPath, [string]$Name)
    Assert-TestKey $SubPath
    $base = Open-TestBase $Hive
    $key = $null
    try {
        $key = $base.OpenSubKey($SubPath, $false)
        $exists = $null -ne $key -and @($key.GetValueNames()) -contains $Name
        $result = [ordered]@{ existed = $exists; type = $null; value = $null }
        if ($exists) {
            $result.type = $key.GetValueKind($Name).ToString()
            $result.value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($result.type -in @('DWord', 'QWord')) { $result.value = $result.value.ToString([Globalization.CultureInfo]::InvariantCulture) }
        }
        [pscustomobject]$result
    } finally { if ($null -ne $key) { $key.Dispose() }; $base.Dispose() }
}

function New-BackupId {
    $id = [guid]::NewGuid().ToString('D')
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $backupRoot ($id + '.json')))) 'Unexpected backup ID collision.'
    $script:backupIds.Add($id)
    $id
}

function New-Request {
    param([object[]]$Registry = @(), [object[]]$Services = @(), [string]$BackupId = (New-BackupId))
    [ordered]@{
        schemaVersion = 1; operation = 'apply_tweaks'; backupId = $BackupId
        tweaks = @([ordered]@{ key = 'disposable-fixture'; name = 'Disposable worker integration fixture'; registry = @($Registry); services = @($Services) })
    }
}

function New-RegistryWrite {
    param([string]$Hive, [string]$SubPath, [string]$Name, [string]$Value = 'changed-by-disposable-test')
    Assert-TestKey $SubPath
    [ordered]@{ path = $Hive + ':\' + $SubPath; name = $Name; type = 'String'; value = $Value }
}

function Invoke-Worker {
    param($Request, [string]$RestoreId, [switch]$BadHash)
    $script:requestNumber++
    $prefix = '{0:D3}' -f $script:requestNumber
    $stdout = Join-Path $evidenceRoot ($prefix + '.stdout.jsonl')
    $stderr = Join-Path $evidenceRoot ($prefix + '.stderr.txt')
    $arguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $worker)
    if ($RestoreId) { $arguments += @('-RestoreBackupId', $RestoreId) }
    else {
        $inputFile = Join-Path $evidenceRoot ($prefix + '.request.json')
        [IO.File]::WriteAllText($inputFile, (Convert-StableJson $Request), $encoding)
        $digest = (Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($BadHash) { $digest = '0' * 64 }
        $arguments += @('-InputPath', $inputFile, '-ExpectedSha256', $digest)
    }
    # Native argument invocation preserves paths containing spaces, without -Command
    # interpolation or changing any execution policy.
    & $shell @arguments 1> $stdout 2> $stderr
    $exitCode = $LASTEXITCODE
    $errorText = [IO.File]::ReadAllText($stderr)
    Assert-That ([string]::IsNullOrWhiteSpace($errorText)) ("Worker stderr: " + $errorText)
    $rows = @([IO.File]::ReadAllLines($stdout) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json -ErrorAction Stop })
    Assert-That ($rows.Count -gt 0) 'Worker did not return JSON.'
    $result = $rows[$rows.Count - 1]
    Assert-That ($result.schemaVersion -eq 1) 'Worker returned an unknown schema.'
    Assert-That (($exitCode -eq 0) -eq ($result.status -eq 'completed')) 'Worker exit code disagrees with its reported result.'
    [pscustomobject]@{ exitCode = $exitCode; result = $result; checkpoints = @($rows | Where-Object { $_.PSObject.Properties.Name -contains 'checkpoint' }); stdoutFile = [IO.Path]::GetFileName($stdout) }
}

function Read-BackupAcl {
    param([string]$Id)
    $path = Join-Path $backupRoot ($Id + '.json')
    $details = @()
    foreach ($target in @($backupRoot, $path)) {
        $acl = Get-Acl -LiteralPath $target -ErrorAction Stop
        $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
        $allows = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) | Where-Object { $_.AccessControlType -eq 'Allow' } | ForEach-Object { $_.IdentityReference.Value } | Select-Object -Unique)
        Assert-That (@('S-1-5-18', 'S-1-5-32-544') -contains $owner) 'Backup owner must be Administrators or SYSTEM.'
        Assert-That (@($allows | Where-Object { @('S-1-5-18', 'S-1-5-32-544') -notcontains $_ }).Count -eq 0) 'Backup ACL unexpectedly allows another identity.'
        Assert-That (($allows -contains 'S-1-5-18') -and ($allows -contains 'S-1-5-32-544')) 'Backup ACL must retain Administrators and SYSTEM access.'
        $details += [pscustomobject]@{ kind = $(if ($target -eq $backupRoot) { 'directory' } else { 'file' }); owner = $owner; allowedSids = $allows }
    }
    $details
}

function Invoke-Case {
    param([string]$Name, [scriptblock]$Body)
    $start = [DateTime]::UtcNow
    try {
        $detail = & $Body
        $script:cases.Add([pscustomobject]@{ name = $Name; status = 'passed'; durationMs = [int]([DateTime]::UtcNow - $start).TotalMilliseconds; detail = $detail })
        Write-Host ("PASS " + $Name)
    } catch {
        $script:cases.Add([pscustomobject]@{ name = $Name; status = 'failed'; durationMs = [int]([DateTime]::UtcNow - $start).TotalMilliseconds; error = $_.Exception.Message })
        throw
    }
}

function Set-TestDenyWrite {
    param([string]$SubPath, $RestoreAcl)
    Assert-TestKey $SubPath
    $base = Open-TestBase 'HKCU'
    $key = $null
    try {
        $rights = [Security.AccessControl.RegistryRights]::ChangePermissions -bor [Security.AccessControl.RegistryRights]::ReadPermissions
        $key = $base.OpenSubKey($SubPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, $rights)
        $deny = New-Object Security.AccessControl.RegistryAccessRule($identity.User, [Security.AccessControl.RegistryRights]::SetValue, [Security.AccessControl.AccessControlType]::Deny)
        if ($null -ne $RestoreAcl) {
            # Remove only the exact explicit ACE introduced by this fixture.
            # Replacing an entire inherited DACL can normalize its SDDL without
            # preserving byte identity, so retain the original for evidence and
            # verify the injected denial by its semantics instead.
            $restored = $key.GetAccessControl()
            $expectedDacl = $RestoreAcl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
            $restrictedDacl = $restored.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
            $restored.RemoveAccessRuleSpecific($deny)
            $key.SetAccessControl($restored)
            $actualAcl = $key.GetAccessControl()
            $actualDacl = $actualAcl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
            $rules = @($actualAcl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
            $remainingDenials = @($rules | Where-Object {
                $_.IdentityReference.Value -ceq $identity.User.Value -and $_.AccessControlType -eq 'Deny' -and
                ($_.RegistryRights -band [Security.AccessControl.RegistryRights]::SetValue) -ne 0
            })
            $diagnostic = [ordered]@{
                path = 'HKCU:\' + $SubPath; operation = 'remove-fixture-deny'; expectedSddl = $expectedDacl
                restrictedSddl = $restrictedDacl; actualSddl = $actualDacl; remainingSetValueDenials = $remainingDenials.Count
                rules = @($rules | ForEach-Object { [ordered]@{ sid = $_.IdentityReference.Value; type = [string]$_.AccessControlType; rights = [string]$_.RegistryRights; inherited = $_.IsInherited; inheritance = [string]$_.InheritanceFlags; propagation = [string]$_.PropagationFlags } })
            }
            $label = if ($SubPath.Contains('\Partial-restore\')) { 'restore' } else { 'apply' }
            [IO.File]::WriteAllText((Join-Path $evidenceRoot ('registry-acl-' + $label + '.json')), (ConvertTo-Json -InputObject $diagnostic -Depth 10), $encoding)
            Assert-That ($remainingDenials.Count -eq 0) 'Registry fixture SetValue denial remains after removing its explicit ACE; see registry-acl evidence.'
            return
        }
        $original = $key.GetAccessControl()
        $restricted = $key.GetAccessControl()
        $priorDenials = @($original.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) | Where-Object {
            $_.IdentityReference.Value -ceq $identity.User.Value -and $_.AccessControlType -eq 'Deny' -and
            ($_.RegistryRights -band [Security.AccessControl.RegistryRights]::SetValue) -ne 0
        })
        Assert-That ($priorDenials.Count -eq 0) 'Unique registry fixture already denies SetValue; refusing to alter an existing denial.'
        $restricted.AddAccessRule($deny)
        $key.SetAccessControl($restricted)
        $original
    } finally { if ($null -ne $key) { $key.Dispose() }; $base.Dispose() }
}

function Read-TestService {
    Assert-That ($serviceName -cmatch '^WinUtilMcpTest_[0-9a-f]{32}$') 'Unsafe service fixture name.'
    $service = Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction Stop
    Assert-That ($null -ne $service) 'Test service is missing.'
    $base = Open-TestBase 'HKLM'
    $key = $null
    try {
        $key = $base.OpenSubKey('SYSTEM\CurrentControlSet\Services\' + $serviceName, $false)
        $exists = @($key.GetValueNames()) -contains 'DelayedAutoStart'
        [pscustomobject]@{ startMode = [string]$service.StartMode; state = [string]$service.State; delayedExists = $exists; delayed = $(if ($exists) { [int]$key.GetValue('DelayedAutoStart') } else { $null }) }
    } finally { if ($null -ne $key) { $key.Dispose() }; $base.Dispose() }
}

try {
    foreach ($hive in @('HKCU', 'HKLM')) {
        $base = Open-TestBase $hive
        $key = $null
        try {
            $existing = $base.OpenSubKey($keySubPath, $false)
            if ($null -ne $existing) { $existing.Dispose(); throw 'Fixture registry root already exists; refusing to reuse it.' }
            $key = $base.CreateSubKey($keySubPath)
            $script:createdHives.Add($hive)
        } finally { if ($null -ne $key) { $key.Dispose() }; $base.Dispose() }
    }

    foreach ($hive in @('HKCU', 'HKLM')) {
        Invoke-Case ($hive + ' typed registry mutation and exact restoration') {
            $seeds = @(
                @{ name = 'BinaryEmpty'; type = 'Binary'; value = [byte[]]@() },
                @{ name = 'BinaryOne'; type = 'Binary'; value = [byte[]]@(255) },
                @{ name = 'BinaryMany'; type = 'Binary'; value = [byte[]]@(0, 1, 255) },
                @{ name = 'MultiEmpty'; type = 'MultiString'; value = [string[]]@() },
                @{ name = 'MultiOne'; type = 'MultiString'; value = [string[]]@('one') },
                @{ name = 'MultiMany'; type = 'MultiString'; value = [string[]]@('one', 'two', 'three') },
                @{ name = 'Expand'; type = 'ExpandString'; value = '%SystemRoot%\unexpanded\%TEMP%' },
                @{ name = ''; type = 'String'; value = 'default registry value' },
                @{ name = 'EmptyString'; type = 'String'; value = '' },
                @{ name = 'DwordZero'; type = 'DWord'; value = [int]0 },
                @{ name = 'DwordAllBits'; type = 'DWord'; value = [int]-1 },
                @{ name = 'QwordZero'; type = 'QWord'; value = [long]0 },
                @{ name = 'QwordMax'; type = 'QWord'; value = [long]::MaxValue },
                @{ name = 'QwordMin'; type = 'QWord'; value = [long]::MinValue }
            )
            $before = [ordered]@{}
            $writes = @()
            foreach ($seed in $seeds) {
                Set-TestValue $hive $keySubPath $seed.name $seed.type $seed.value
                $before[$seed.name] = Read-TestValue $hive $keySubPath $seed.name
                if ($seed.type -in @('Binary', 'MultiString')) {
                    Assert-That ($before[$seed.name].value -is [array] -and $before[$seed.name].value.Count -eq $seed.value.Count) 'Registry fixture did not preserve the expected array cardinality.'
                }
                $writes += New-RegistryWrite $hive $keySubPath $seed.name
            }
            $before['PreviouslyAbsent'] = Read-TestValue $hive $keySubPath 'PreviouslyAbsent'
            $writes += New-RegistryWrite $hive $keySubPath 'PreviouslyAbsent'
            $newSubPath = $keySubPath + '\CreatedByWorker'
            $writes += New-RegistryWrite $hive $newSubPath 'Added'
            $request = New-Request -Registry $writes
            $changed = Invoke-Worker -Request $request
            Assert-That ($changed.result.status -eq 'completed') (Convert-StableJson $changed.result)
            Assert-That ($changed.result.results.Count -eq $writes.Count) 'Not every registry write completed.'
            foreach ($seed in $seeds) {
                Assert-Equal ([pscustomobject][ordered]@{ existed = $true; type = 'String'; value = 'changed-by-disposable-test' }) (Read-TestValue $hive $keySubPath $seed.name) 'Registry write did not occur.'
            }
            $acl = @(Read-BackupAcl $request.backupId)
            $backup = Get-Content -LiteralPath (Join-Path $backupRoot ($request.backupId + '.json')) -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($entry in @($backup.entries | Where-Object { $_.type -in @('Binary', 'MultiString') })) {
                Assert-That ($entry.value -is [array]) 'Real backup flattened an array value.'
            }
            $restored = Invoke-Worker -RestoreId $request.backupId
            Assert-That ($restored.result.status -eq 'completed') (Convert-StableJson $restored.result)
            $after = [ordered]@{}
            foreach ($name in $before.Keys) {
                $after[$name] = Read-TestValue $hive $keySubPath $name
                Assert-Equal $before[$name] $after[$name] ('Registry restoration mismatch for ' + $hive + ':' + $name)
            }
            Assert-That (-not (Read-TestValue $hive $newSubPath 'Added').existed) 'Restore must remove the newly introduced value.'
            [pscustomobject]@{ backupId = $request.backupId; values = $writes.Count; before = $before; restored = $after; backupAcl = $acl; checkpointCount = $changed.checkpoints.Count; changedStatus = $changed.result.status; restoreStatus = $restored.result.status }
        }
    }

    Invoke-Case 'hash and unknown-field rejection happen before mutation' {
        $before = Read-TestValue 'HKCU' $keySubPath 'EmptyString'
        $request = New-Request -Registry @((New-RegistryWrite 'HKCU' $keySubPath 'EmptyString'))
        $badHash = Invoke-Worker -Request $request -BadHash
        Assert-That ($badHash.result.status -eq 'failed' -and $badHash.result.message -match 'REQUEST_CHANGED') 'A mismatched request digest was not rejected.'
        $request.tweaks[0]['InvokeScript'] = @('throw unexpected')
        $badField = Invoke-Worker -Request $request
        Assert-That ($badField.result.status -eq 'failed' -and $badField.result.message -match 'INVALID_REQUEST') 'An unknown executable field was not rejected.'
        Assert-Equal $before (Read-TestValue 'HKCU' $keySubPath 'EmptyString') 'Rejected request changed registry state.'
        Assert-That (-not (Test-Path -LiteralPath (Join-Path $backupRoot ($request.backupId + '.json')))) 'Rejected request unexpectedly created a backup.'
        [pscustomobject]@{ hashStatus = $badHash.result.status; unknownFieldStatus = $badField.result.status; unchanged = $true; backupCreated = $false }
    }

    Invoke-Case 'backup collision stops before the first write' {
        $id = $script:backupIds[0]
        $before = Read-TestValue 'HKCU' $keySubPath 'EmptyString'
        $path = Join-Path $backupRoot ($id + '.json')
        $backupHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        $request = New-Request -Registry @((New-RegistryWrite 'HKCU' $keySubPath 'EmptyString')) -BackupId $id
        $result = Invoke-Worker -Request $request
        Assert-That ($result.result.status -eq 'failed') 'An existing backup was silently overwritten.'
        Assert-Equal $before (Read-TestValue 'HKCU' $keySubPath 'EmptyString') 'Backup failure must occur before mutation.'
        Assert-That ($backupHash -ceq (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash) 'Existing backup bytes changed.'
        [pscustomobject]@{ workerStatus = $result.result.status; unchanged = $true; existingBackupPreserved = $true }
    }

    foreach ($phase in @('apply', 'restore')) {
        Invoke-Case ('real access denial during ' + $phase + ' retains recoverable partial state') {
            $paths = @(
                ($keySubPath + '\Partial-' + $phase + '\A'),
                ($keySubPath + '\Partial-' + $phase + '\B'),
                ($keySubPath + '\Partial-' + $phase + '\C')
            )
            $writes = @()
            foreach ($path in $paths) { Set-TestValue 'HKCU' $path 'Value' 'String' 'original'; $writes += New-RegistryWrite 'HKCU' $path 'Value' }
            $request = New-Request -Registry $writes
            $originalAcl = $null
            try {
                if ($phase -eq 'apply') { $originalAcl = Set-TestDenyWrite $paths[1] }
                $applied = Invoke-Worker -Request $request
                if ($phase -eq 'restore') {
                    Assert-That ($applied.result.status -eq 'completed') 'Fixture mutation failed before restore-denial case.'
                    $originalAcl = Set-TestDenyWrite $paths[1]
                    $partial = Invoke-Worker -RestoreId $request.backupId
                } else { $partial = $applied }
                Assert-That ($partial.result.status -eq 'partial') ('Expected real partial failure: ' + (Convert-StableJson $partial.result))
                Assert-That ($partial.result.results.Count -eq 2 -and $partial.result.results[0].status -eq 'completed' -and $partial.result.results[1].status -eq 'failed') 'Worker did not stop at the failed second item.'
                Assert-Equal 'changed-by-disposable-test' (Read-TestValue 'HKCU' $paths[0] 'Value').value 'Unexpected first-key state after partial failure.'
                Assert-Equal 'original' (Read-TestValue 'HKCU' $paths[2] 'Value').value 'Unexpected final-key state after partial failure.'
                $acl = @(Read-BackupAcl $request.backupId)
            } finally { if ($null -ne $originalAcl) { Set-TestDenyWrite $paths[1] -RestoreAcl $originalAcl } }
            $recovered = Invoke-Worker -RestoreId $request.backupId
            Assert-That ($recovered.result.status -eq 'completed') 'Restoration could not recover after the temporary denial was removed.'
            foreach ($path in $paths) { Assert-Equal 'original' (Read-TestValue 'HKCU' $path 'Value').value 'Recovery failed to restore an original value.' }
            [pscustomobject]@{ backupId = $request.backupId; partialStatus = $partial.result.status; failedItem = $partial.result.results[1]; restoredStatus = $recovered.result.status; backupAcl = $acl }
        }
    }

    Invoke-Case 'backup ACL and invalid-record rejection make no partial restore' {
        $request = New-Request -Registry @((New-RegistryWrite 'HKCU' $keySubPath 'EmptyString'), (New-RegistryWrite 'HKCU' $keySubPath 'DwordZero'))
        $applied = Invoke-Worker -Request $request
        Assert-That ($applied.result.status -eq 'completed') 'Fixture mutation failed.'
        $path = Join-Path $backupRoot ($request.backupId + '.json')
        $originalBytes = [IO.File]::ReadAllBytes($path)
        $originalAcl = Get-Acl -LiteralPath $path
        $weakRule = New-Object Security.AccessControl.FileSystemAccessRule($identity.User, 'Read', 'Allow')
        try {
            $weakAcl = Get-Acl -LiteralPath $path
            $weakAcl.AddAccessRule($weakRule)
            Set-Acl -LiteralPath $path -AclObject $weakAcl
            $badAcl = Invoke-Worker -RestoreId $request.backupId
            Assert-That ($badAcl.result.status -eq 'failed' -and $badAcl.result.message -match 'UNSAFE_BACKUP_ACL') 'Restore accepted a backup readable by another explicit identity.'
        } finally {
            $restoredAcl = Get-Acl -LiteralPath $path
            $expectedDacl = $originalAcl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
            $restrictedDacl = $restoredAcl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
            $restoredAcl.RemoveAccessRuleSpecific($weakRule)
            Set-Acl -LiteralPath $path -AclObject $restoredAcl
            $actualAcl = Get-Acl -LiteralPath $path
            $unexpectedAllows = @($actualAcl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) | Where-Object {
                $_.AccessControlType -eq 'Allow' -and @('S-1-5-18', 'S-1-5-32-544') -notcontains $_.IdentityReference.Value
            })
            $diagnostic = [ordered]@{ backupId = $request.backupId; operation = 'remove-fixture-read-allow'; expectedSddl = $expectedDacl; restrictedSddl = $restrictedDacl; actualSddl = $actualAcl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access); unexpectedAllows = $unexpectedAllows.Count }
            [IO.File]::WriteAllText((Join-Path $evidenceRoot 'backup-acl.json'), (ConvertTo-Json -InputObject $diagnostic -Depth 10), $encoding)
            Assert-That ($unexpectedAllows.Count -eq 0) 'Backup fixture still has an unauthorized allow ACE; see backup-acl evidence.'
        }
        foreach ($name in @('EmptyString', 'DwordZero')) { Assert-Equal 'changed-by-disposable-test' (Read-TestValue 'HKCU' $keySubPath $name).value 'ACL rejection unexpectedly restored a value.' }
        try {
            $invalid = [Text.Encoding]::UTF8.GetString($originalBytes) | ConvertFrom-Json
            $invalid.entries[$invalid.entries.Count - 1].type = 'ScriptBlock'
            [IO.File]::WriteAllText($path, (Convert-StableJson $invalid), $encoding)
            $badRecord = Invoke-Worker -RestoreId $request.backupId
            Assert-That ($badRecord.result.status -eq 'failed' -and $badRecord.result.message -match 'INVALID_BACKUP') 'Restore accepted an invalid backup record.'
            foreach ($name in @('EmptyString', 'DwordZero')) { Assert-Equal 'changed-by-disposable-test' (Read-TestValue 'HKCU' $keySubPath $name).value 'Whole-backup validation did not precede restoration.' }
        } finally { [IO.File]::WriteAllBytes($path, $originalBytes) }
        $recovered = Invoke-Worker -RestoreId $request.backupId
        Assert-That ($recovered.result.status -eq 'completed') 'Original backup could not be restored after validation checks.'
        Assert-Equal '' (Read-TestValue 'HKCU' $keySubPath 'EmptyString').value 'String did not recover.'
        Assert-Equal '0' (Read-TestValue 'HKCU' $keySubPath 'DwordZero').value 'DWORD did not recover.'
        [pscustomobject]@{ backupId = $request.backupId; invalidAclStatus = $badAcl.result.status; invalidRecordStatus = $badRecord.result.status; restoreStatus = $recovered.result.status }
    }

    Invoke-Case 'new test service startup and delayed startup restore exactly' {
        Assert-That ($null -eq (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)) 'Unique test service already exists.'
        $binary = '"' + (Join-Path $env:SystemRoot 'System32\cmd.exe') + '" /c exit 0'
        $null = New-Service -Name $serviceName -BinaryPathName $binary -DisplayName $serviceName -StartupType Manual -Description 'Disposable MCP integration test; never started.'
        $script:serviceCreated = $true
        $rounds = @()
        foreach ($initial in @('Manual', 'AutomaticDelayed')) {
            if ($initial -eq 'AutomaticDelayed') {
                $configOutput = & (Join-Path $env:SystemRoot 'System32\sc.exe') config $serviceName 'start=' 'delayed-auto' 2>&1
                Assert-That ($LASTEXITCODE -eq 0) ('Unable to seed delayed startup: ' + ($configOutput -join ' '))
            }
            $before = Read-TestService
            Assert-That ($before.state -eq 'Stopped') 'Test service must never be running.'
            if ($initial -eq 'AutomaticDelayed') { Assert-That ($before.startMode -eq 'Auto' -and $before.delayedExists -and $before.delayed -eq 1) 'Delayed automatic startup was not actually seeded.' }
            else { Assert-That ($before.startMode -eq 'Manual') 'Manual startup was not actually seeded.' }
            $request = New-Request -Services @([ordered]@{ name = $serviceName; startupType = 'Disabled' })
            $applied = Invoke-Worker -Request $request
            Assert-That ($applied.result.status -eq 'completed') (Convert-StableJson $applied.result)
            $changed = Read-TestService
            Assert-That ($changed.startMode -eq 'Disabled' -and $changed.state -eq 'Stopped') 'Test service startup type did not change correctly.'
            $restored = Invoke-Worker -RestoreId $request.backupId
            Assert-That ($restored.result.status -eq 'completed') (Convert-StableJson $restored.result)
            $after = Read-TestService
            Assert-Equal $before $after 'Test service original startup configuration was not restored.'
            $rounds += [pscustomobject]@{ initial = $initial; backupId = $request.backupId; before = $before; changed = $changed; restored = $after; backupAcl = @(Read-BackupAcl $request.backupId) }
        }
        [pscustomobject]@{ serviceName = $serviceName; rounds = $rounds; serviceEverStarted = $false }
    }
} catch {
    $script:failure = $_.Exception.Message
} finally {
    if ($script:serviceCreated) {
        try {
            Assert-That ($serviceName -ceq ('WinUtilMcpTest_' + $runId)) 'Unsafe service cleanup target.'
            $deleteOutput = & (Join-Path $env:SystemRoot 'System32\sc.exe') delete $serviceName 2>&1
            Assert-That ($LASTEXITCODE -eq 0) ('Service cleanup failed: ' + ($deleteOutput -join ' '))
            Assert-That ($null -eq (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)) 'Service remains after deletion.'
            $script:cleanup.Add([pscustomobject]@{ kind = 'service'; name = $serviceName; status = 'removed' })
        } catch { $script:cleanup.Add([pscustomobject]@{ kind = 'service'; status = 'failed'; error = $_.Exception.Message }); $script:failure = 'Cleanup failed: ' + $_.Exception.Message }
    }
    foreach ($hive in $script:createdHives) {
        try {
            Assert-That ($keySubPath -cmatch '^Software\\WinUtilCnMcpIntegration_[0-9a-f]{32}$') 'Unsafe registry cleanup target.'
            $base = Open-TestBase $hive
            try {
                $base.DeleteSubKeyTree($keySubPath, $false)
                $remaining = $base.OpenSubKey($keySubPath, $false)
                if ($null -ne $remaining) { $remaining.Dispose(); throw 'Registry test root remains after cleanup.' }
            } finally { $base.Dispose() }
            $script:cleanup.Add([pscustomobject]@{ kind = 'registry'; hive = $hive; subKey = $keySubPath; status = 'removed' })
        } catch { $script:cleanup.Add([pscustomobject]@{ kind = 'registry'; hive = $hive; status = 'failed'; error = $_.Exception.Message }); $script:failure = 'Cleanup failed: ' + $_.Exception.Message }
    }
    foreach ($id in $script:backupIds) {
        try {
            Assert-That ($id -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') 'Unsafe backup cleanup ID.'
            $path = [IO.Path]::GetFullPath((Join-Path $backupRoot ($id + '.json')))
            Assert-That ([IO.Path]::GetDirectoryName($path) -ceq [IO.Path]::GetFullPath($backupRoot)) 'Unsafe backup cleanup path.'
            if (Test-Path -LiteralPath $path) {
                Assert-That (((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing to clean a backup reparse point.'
                # Preserve exact backup bytes as evidence before deleting only this run's file.
                Copy-Item -LiteralPath $path -Destination (Join-Path $evidenceRoot ($id + '.backup.json'))
                Remove-Item -LiteralPath $path -Force
                Assert-That (-not (Test-Path -LiteralPath $path)) 'Backup remains after cleanup.'
                $script:cleanup.Add([pscustomobject]@{ kind = 'backup'; id = $id; status = 'removed' })
            }
        } catch { $script:cleanup.Add([pscustomobject]@{ kind = 'backup'; id = $id; status = 'failed'; error = $_.Exception.Message }); $script:failure = 'Cleanup failed: ' + $_.Exception.Message }
    }
    $evidence = [ordered]@{
        schemaVersion = 1; status = $(if ($script:failure) { 'failed' } else { 'passed' }); completedUtc = [DateTime]::UtcNow.ToString('o')
        environment = [ordered]@{ githubActions = $env:GITHUB_ACTIONS; runnerEnvironment = $env:RUNNER_ENVIRONMENT; runnerOS = $env:RUNNER_OS; runId = $env:GITHUB_RUN_ID; runAttempt = $env:GITHUB_RUN_ATTEMPT; commit = $env:GITHUB_SHA; machine = [Environment]::MachineName; harnessPowerShell = $PSVersionTable.PSVersion.ToString(); workerPowerShell = $shell; workerSha256 = (Get-FileHash -LiteralPath $worker -Algorithm SHA256).Hash }
        fixtureId = $runId; scenarios = @($script:cases.ToArray()); cleanup = @($script:cleanup.ToArray()); error = $script:failure
    }
    $evidencePath = Join-Path $evidenceRoot ('worker-roundtrip.' + [IO.Path]::GetFileNameWithoutExtension($PowerShellExecutable) + '.json')
    [IO.File]::WriteAllText($evidencePath, (ConvertTo-Json -InputObject $evidence -Depth 50), $encoding)
    Write-Host ('Evidence: ' + $evidencePath)
}
if ($script:failure) { throw $script:failure }
