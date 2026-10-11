Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-WinUtilMcpAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'ADMIN_REQUIRED: 该操作需要管理员权限；MCP 不会自动提权。'
    }
}

function Assert-WinUtilMcpFields {
    param($Object, [string[]]$Allowed, [string[]]$Required = @())
    if ($null -eq $Object -or $Object -isnot [pscustomobject]) { throw 'INVALID_REQUEST: 需要 JSON 对象。' }
    $names = @($Object.PSObject.Properties.Name)
    foreach ($name in $names) { if ($Allowed -cnotcontains $name) { throw "INVALID_REQUEST: 不支持字段 $name。" } }
    foreach ($name in $Required) { if ($names -cnotcontains $name) { throw "INVALID_REQUEST: 缺少字段 $name。" } }
}

function Get-WinUtilMcpRegistryLocation {
    param([string]$Path)
    if ($Path -notmatch '^(HKLM|HKCU):\\([^\x00-\x1f*?]+)$' -or $Path.Split('\') -contains '..' -or $Path.Split('\') -contains '.') {
        throw 'INVALID_REGISTRY: 仅支持 HKLM/HKCU 的明确子项路径。'
    }
    $hiveName = if ($Matches[1] -eq 'HKLM') { 'LocalMachine' } else { 'CurrentUser' }
    return @{ Hive = [Microsoft.Win32.RegistryHive]::$hiveName; SubKey = $Matches[2] }
}

function Assert-WinUtilMcpRegistryEntry {
    param($Entry)
    Assert-WinUtilMcpFields $Entry @('path', 'name', 'type', 'value') @('path', 'name', 'type', 'value')
    $null = Get-WinUtilMcpRegistryLocation $Entry.path
    if ($Entry.name -isnot [string] -or $Entry.name -match '[\x00-\x1f\\]' -or @('String', 'DWord', 'QWord') -cnotcontains $Entry.type) { throw 'INVALID_REGISTRY: 不支持的值名称或类型。' }
    if ($Entry.value -isnot [string]) { throw 'INVALID_REGISTRY: 值必须为规范化字符串。' }
    if ($Entry.type -eq 'String') {
        if ($Entry.value.Contains([char]0) -or $Entry.value -match '^<.*>$') { throw 'INVALID_REGISTRY: 不支持占位符。' }
    } else {
        if ($Entry.value -notmatch '^(0|[1-9][0-9]*)$') { throw 'INVALID_REGISTRY: 数值格式错误。' }
        if ($Entry.type -eq 'DWord') { $null = [uint32]::Parse($Entry.value) } else { $null = [long]::Parse($Entry.value) }
    }
}

function New-WinUtilMcpRegistrySnapshot {
    param([string]$Path, [string]$Name, [bool]$KeyExisted, [bool]$Existed, [string]$Type, $Value)
    $snapshot = [ordered]@{ kind = 'registry'; path = $Path; name = $Name; existed = $Existed; keyExisted = $KeyExisted; type = $null; value = $null }
    if ($Existed) {
        if (@('String', 'ExpandString', 'DWord', 'QWord', 'MultiString', 'Binary') -notcontains $Type) { throw 'UNSUPPORTED_BACKUP: 无法可靠保存原注册表类型。' }
        $snapshot.type = $Type
        # Assign the original object directly: a PowerShell output expression would unwrap
        # empty/single-element Binary and MultiString arrays and make their backups unrestorable.
        $snapshot.value = $Value
        if ($Type -in @('DWord', 'QWord')) {
            $snapshot.value = $Value.ToString([Globalization.CultureInfo]::InvariantCulture)
        }
    }
    return [pscustomobject]$snapshot
}

function Get-WinUtilMcpRegistry {
    param([string]$Path, [string]$Name)
    $location = Get-WinUtilMcpRegistryLocation $Path
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($location.Hive, [Microsoft.Win32.RegistryView]::Registry64)
    $key = $null
    try {
        $key = $base.OpenSubKey($location.SubKey, $false)
        $exists = $null -ne $key -and @($key.GetValueNames()) -contains $Name
        $type = $null
        $value = $null
        if ($exists) {
            $type = $key.GetValueKind($Name).ToString()
            $value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
        return New-WinUtilMcpRegistrySnapshot -Path $Path -Name $Name -KeyExisted ($null -ne $key) -Existed $exists -Type $type -Value $value
    } finally {
        if ($null -ne $key) { $key.Dispose() }
        $base.Dispose()
    }
}

function Set-WinUtilMcpRegistry {
    param([string]$Path, [string]$Name, [string]$Type, $Value, [switch]$Remove)
    $location = Get-WinUtilMcpRegistryLocation $Path
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($location.Hive, [Microsoft.Win32.RegistryView]::Registry64)
    $key = $null
    try {
        if ($Remove) {
            $key = $base.OpenSubKey($location.SubKey, $true)
            if ($null -ne $key) { $key.DeleteValue($Name, $false) }
            return
        }
        $key = $base.CreateSubKey($location.SubKey)
        $typedValue = switch ($Type) {
            'DWord' { if ([long]$Value -gt [int]::MaxValue) { [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]$Value), 0) } else { [int]$Value } }
            'QWord' { [long]$Value }
            'String' { [string]$Value }
            'ExpandString' { [string]$Value }
            'MultiString' { ,([string[]]$Value) }
            'Binary' { ,([byte[]]$Value) }
            default { throw 'INVALID_REGISTRY: 不支持的恢复类型。' }
        }
        $key.SetValue($Name, $typedValue, [Microsoft.Win32.RegistryValueKind]::$Type)
    } finally {
        if ($null -ne $key) { $key.Dispose() }
        $base.Dispose()
    }
}

function Get-WinUtilMcpService {
    param([string]$Name)
    if ($Name -notmatch '^[A-Za-z0-9_.-]{1,128}$') { throw 'INVALID_SERVICE: 服务名称无效。' }
    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
    if ($null -eq $service) { throw "SERVICE_NOT_FOUND: $Name" }
    $startupType = switch ($service.StartMode) { 'Auto' { 'Automatic' }; 'Manual' { 'Manual' }; 'Disabled' { 'Disabled' }; default { throw 'UNSUPPORTED_SERVICE: 不支持驱动启动类型。' } }
    return [pscustomobject]@{ kind = 'service'; name = $Name; startupType = $startupType; delayed = Get-WinUtilMcpRegistry "HKLM:\SYSTEM\CurrentControlSet\Services\$Name" 'DelayedAutoStart' }
}

function Get-WinUtilMcpAdapters {
    $items = @(Get-NetAdapter -ErrorAction Stop)
    return @($items | ForEach-Object {
        [pscustomobject]@{ id = ([guid]$_.InterfaceGuid).ToString('D').ToLowerInvariant(); interfaceIndex = [int]$_.ifIndex; name = [string]$_.Name; macAddress = [string]$_.MacAddress; description = [string]$_.InterfaceDescription; connectionStatus = [string]$_.Status; status = 'completed' }
    })
}

function Assert-WinUtilMcpAdapterIdentity {
    param($Expected, $Current)
    if ($null -eq $Current -or $Expected.id -cne $Current.id -or [int]$Expected.interfaceIndex -ne [int]$Current.interfaceIndex -or
        $Expected.macAddress -cne $Current.macAddress -or $Expected.description -cne $Current.description) {
        throw 'ADAPTER_CHANGED: 网卡身份或接口编号已变化，请重新预览。'
    }
}

function Get-WinUtilMcpDns {
    param($Adapter)
    $families = @()
    foreach ($family in @('IPv4', 'IPv6')) {
        $service = if ($family -eq 'IPv4') { 'Tcpip' } else { 'Tcpip6' }
        $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + $service + '\Parameters\Interfaces\{' + $Adapter.id + '}'
        $setting = Get-WinUtilMcpRegistry $path 'NameServer'
        $configured = if ($setting.existed) { [string]$setting.value } else { '' }
        $addresses = @($configured -split '[,;\s]+' | Where-Object { $_ })
        foreach ($address in $addresses) { $null = [System.Net.IPAddress]::Parse($address) }
        $families += [pscustomobject]@{ family = $family; automatic = [string]::IsNullOrWhiteSpace($configured); addresses = $addresses }
    }
    return [pscustomobject]@{ kind = 'dns'; adapter = $Adapter; families = $families }
}

function Set-WinUtilMcpDnsFamily {
    param([int]$InterfaceIndex, [ValidateSet('IPv4', 'IPv6')][string]$Family, [string[]]$Addresses, [switch]$Reset)
    $inputObject = @(Get-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -AddressFamily $Family -ErrorAction Stop)
    if ($inputObject.Count -ne 1) { throw 'DNS_INTERFACE_UNAVAILABLE: 无法唯一定位网卡协议。' }
    if ($Reset) { $inputObject[0] | Set-DnsClientServerAddress -ResetServerAddresses -ErrorAction Stop }
    else { $inputObject[0] | Set-DnsClientServerAddress -ServerAddresses $Addresses -ErrorAction Stop }
}

function Assert-WinUtilMcpNoReparsePoint {
    param([string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'UNSAFE_BACKUP_PATH: 备份路径包含重解析点。' }
        }
        $parent = [IO.Directory]::GetParent($current)
        $current = if ($null -eq $parent) { $null } else { $parent.FullName }
    }
}

function Assert-WinUtilMcpBackupAcl {
    param([string]$Path)
    Assert-WinUtilMcpNoReparsePoint $Path
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    $allowed = @('S-1-5-18', 'S-1-5-32-544')
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($allowed -notcontains $owner) { throw 'UNSAFE_BACKUP_ACL: 备份所有者不是 Administrators/SYSTEM。' }
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
        if ($rule.AccessControlType -eq 'Allow' -and $allowed -notcontains $rule.IdentityReference.Value) { throw 'UNSAFE_BACKUP_ACL: 备份目录必须仅 Administrators/SYSTEM 可访问。' }
    }
}

function Get-WinUtilMcpBackupRoot {
    param([switch]$Create)
    $root = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'WinUtil-CN-MCP'
    Assert-WinUtilMcpNoReparsePoint $root
    if (-not (Test-Path -LiteralPath $root)) {
        if (-not $Create) { throw 'BACKUP_NOT_FOUND: 备份目录不存在。' }
        $acl = New-Object Security.AccessControl.DirectorySecurity
        $admins = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
        $system = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
        $acl.SetOwner($admins)
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($sid in @($admins, $system)) {
            $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.AddAccessRule($rule)
        }
        # Windows PowerShell creates the directory with its final ACL in one call.
        if ($PSVersionTable.PSEdition -eq 'Desktop') { $null = [IO.Directory]::CreateDirectory($root, $acl) }
        else { $null = [IO.FileSystemAclExtensions]::CreateDirectory((New-Object IO.DirectoryInfo($root)), $acl) }
    }
    Assert-WinUtilMcpBackupAcl $root
    return $root
}

function Write-WinUtilMcpBackup {
    param([string]$Operation, [object[]]$Entries, [string]$Id)
    $root = Get-WinUtilMcpBackupRoot -Create
    if ($Id -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') { throw 'INVALID_BACKUP_ID: 需要宿主生成的 GUID。' }
    $path = Join-Path $root ($Id + '.json')
    $document = [ordered]@{ schemaVersion = 1; id = $Id; operation = $Operation; createdUtc = [DateTime]::UtcNow.ToString('o'); machine = [Environment]::MachineName; userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value; entries = @($Entries) }
    $json = $document | ConvertTo-Json -Depth 30 -Compress
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json)
    $stream = New-Object IO.FileStream($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
    # Files inherit restricted access; set owner to the Administrators SID before allowing use.
    $acl = Get-Acl -LiteralPath $path
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
    Set-Acl -LiteralPath $path -AclObject $acl -ErrorAction Stop
    Assert-WinUtilMcpBackupAcl $path
    return $Id
}

function Write-WinUtilMcpCheckpoint {
    param([string]$BackupId, [object[]]$Results, $Pending = $null)
    $checkpoint = [ordered]@{ schemaVersion = 1; checkpoint = $true; backupId = $BackupId; results = @($Results); pending = $Pending }
    [Console]::Out.WriteLine(($checkpoint | ConvertTo-Json -Depth 30 -Compress))
    [Console]::Out.Flush()
}

function Assert-WinUtilMcpRequest {
    param($Request)
    if ($null -eq $Request -or $Request.schemaVersion -ne 1) { throw 'INVALID_REQUEST: schemaVersion 必须为 1。' }
    switch ($Request.operation) {
        'list_adapters' { Assert-WinUtilMcpFields $Request @('schemaVersion', 'operation') @('schemaVersion', 'operation') }
        'apply_tweaks' {
            Assert-WinUtilMcpFields $Request @('schemaVersion', 'operation', 'tweaks', 'backupId') @('schemaVersion', 'operation', 'tweaks', 'backupId')
            if ($Request.backupId -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') { throw 'INVALID_BACKUP_ID: 备份 ID 无效。' }
            if ($Request.tweaks -isnot [array] -or $Request.tweaks.Count -lt 1 -or $Request.tweaks.Count -gt 50) { throw 'INVALID_REQUEST: tweaks 数量无效。' }
            foreach ($tweak in $Request.tweaks) {
                Assert-WinUtilMcpFields $tweak @('key', 'name', 'registry', 'services') @('key', 'name', 'registry', 'services')
                if ($tweak.key -isnot [string] -or $tweak.key.Length -gt 250 -or $tweak.registry -isnot [array] -or $tweak.services -isnot [array] -or ($tweak.registry.Count + $tweak.services.Count) -lt 1) { throw 'INVALID_REQUEST: 优化项内容无效。' }
                foreach ($entry in $tweak.registry) { Assert-WinUtilMcpRegistryEntry $entry }
                foreach ($entry in $tweak.services) {
                    Assert-WinUtilMcpFields $entry @('name', 'startupType') @('name', 'startupType')
                    if ($entry.name -notmatch '^[A-Za-z0-9_.-]{1,128}$' -or @('Automatic', 'Manual', 'Disabled') -cnotcontains $entry.startupType) { throw 'INVALID_SERVICE: 服务内容无效。' }
                }
            }
        }
        'set_dns' {
            Assert-WinUtilMcpFields $Request @('schemaVersion', 'operation', 'provider', 'addresses', 'adapters', 'backupId') @('schemaVersion', 'operation', 'provider', 'addresses', 'adapters', 'backupId')
            if ($Request.backupId -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') { throw 'INVALID_BACKUP_ID: 备份 ID 无效。' }
            if ($Request.addresses -isnot [array] -or $Request.addresses.Count -gt 8 -or $Request.adapters -isnot [array] -or $Request.adapters.Count -lt 1 -or $Request.adapters.Count -gt 10) { throw 'INVALID_DNS: 地址或网卡数量无效。' }
            if (($Request.provider -eq 'Default') -ne ($Request.addresses.Count -eq 0)) { throw 'INVALID_DNS: 默认方案与地址不一致。' }
            foreach ($address in $Request.addresses) { $null = [Net.IPAddress]::Parse($address) }
            foreach ($adapter in $Request.adapters) {
                Assert-WinUtilMcpFields $adapter @('id', 'interfaceIndex', 'name', 'macAddress', 'description') @('id', 'interfaceIndex', 'name', 'macAddress', 'description')
                if ($adapter.id -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' -or $adapter.interfaceIndex -isnot [long] -and $adapter.interfaceIndex -isnot [int] -or $adapter.interfaceIndex -lt 1) { throw 'INVALID_DNS: 网卡身份无效。' }
            }
        }
        default { throw 'INVALID_OPERATION: 该操作不在允许范围内。' }
    }
}

function Invoke-WinUtilMcpRequest {
    param($Request, [switch]$ReportProgress)
    Assert-WinUtilMcpRequest $Request
    if ($Request.operation -eq 'list_adapters') { return [pscustomobject]@{ schemaVersion = 1; status = 'completed'; results = @(Get-WinUtilMcpAdapters) } }
    Assert-WinUtilMcpAdministrator
    $before = @()
    if ($Request.operation -eq 'apply_tweaks') {
        foreach ($tweak in $Request.tweaks) {
            foreach ($entry in $tweak.registry) { $before += Get-WinUtilMcpRegistry $entry.path $entry.name }
            foreach ($entry in $tweak.services) { $before += Get-WinUtilMcpService $entry.name }
        }
    } else {
        $current = @(Get-WinUtilMcpAdapters)
        foreach ($adapter in $Request.adapters) {
            Assert-WinUtilMcpAdapterIdentity $adapter ($current | Where-Object { $_.id -ceq $adapter.id } | Select-Object -First 1)
            $before += Get-WinUtilMcpDns $adapter
        }
    }
    # Capture every original value and durably save before the first modification.
    $backupId = Write-WinUtilMcpBackup $Request.operation $before $Request.backupId
    $results = New-Object 'System.Collections.Generic.List[object]'
    if ($ReportProgress) { Write-WinUtilMcpCheckpoint $backupId @() }
    $context = @{}
    $attempted = $false
    try {
        if ($Request.operation -eq 'apply_tweaks') {
            foreach ($tweak in $Request.tweaks) {
                foreach ($entry in $tweak.registry) {
                    $context = @{ key = $tweak.key; kind = 'registry'; path = $entry.path; name = $entry.name }
                    if ($ReportProgress) { Write-WinUtilMcpCheckpoint $backupId @($results.ToArray()) $context }
                    $attempted = $true
                    Set-WinUtilMcpRegistry $entry.path $entry.name $entry.type $entry.value
                    $results.Add([pscustomobject]($context + @{ status = 'completed' }))
                    if ($ReportProgress) { Write-WinUtilMcpCheckpoint $backupId @($results.ToArray()) }
                }
                foreach ($entry in $tweak.services) {
                    $context = @{ key = $tweak.key; kind = 'service'; name = $entry.name }
                    if ($ReportProgress) { Write-WinUtilMcpCheckpoint $backupId @($results.ToArray()) $context }
                    $attempted = $true
                    Set-Service -Name $entry.name -StartupType $entry.startupType -ErrorAction Stop
                    $results.Add([pscustomobject]($context + @{ status = 'completed' }))
                    if ($ReportProgress) { Write-WinUtilMcpCheckpoint $backupId @($results.ToArray()) }
                }
            }
        } else {
            foreach ($adapter in $Request.adapters) {
                foreach ($family in @('IPv4', 'IPv6')) {
                    $addresses = @($Request.addresses | Where-Object { ([Net.IPAddress]::Parse($_).AddressFamily.ToString() -eq 'InterNetwork') -eq ($family -eq 'IPv4') })
                    if ($Request.provider -ne 'Default' -and $addresses.Count -eq 0) { continue }
                    $context = @{ kind = 'dns'; adapterId = $adapter.id; interfaceIndex = $adapter.interfaceIndex; family = $family }
                    # Recheck immediately before every individual family write; indices can be reused.
                    Assert-WinUtilMcpAdapterIdentity $adapter (@(Get-WinUtilMcpAdapters) | Where-Object { $_.id -ceq $adapter.id } | Select-Object -First 1)
                    if ($ReportProgress) { Write-WinUtilMcpCheckpoint $backupId @($results.ToArray()) $context }
                    $attempted = $true
                    Set-WinUtilMcpDnsFamily $adapter.interfaceIndex $family $addresses -Reset:($Request.provider -eq 'Default')
                    $results.Add([pscustomobject]($context + @{ status = 'completed' }))
                    if ($ReportProgress) { Write-WinUtilMcpCheckpoint $backupId @($results.ToArray()) }
                }
            }
        }
        return [pscustomobject]@{ schemaVersion = 1; status = 'completed'; results = @($results.ToArray()); backupId = $backupId; recovery = '在管理员终端执行 powershell.exe -NoProfile -File <安装目录>\powershell\worker.ps1 -RestoreBackupId <backupId>。恢复只回写已保存设置，不执行任意脚本；请先查看该备份涉及的项目。' }
    } catch {
        $done = $results.Count
        $results.Add([pscustomobject]($context + @{ status = 'failed'; error = $_.Exception.Message; mayHaveChanged = $attempted }))
        return [pscustomobject]@{ schemaVersion = 1; status = $(if ($done -gt 0) { 'partial' } else { 'failed' }); results = @($results.ToArray()); backupId = $backupId; message = '遇到错误已停止后续改动；使用 backupId 可恢复已保存设置。失败项目也可能已有部分改动。' }
    }
}

function Restore-WinUtilMcpBackup {
    param([string]$Id)
    Assert-WinUtilMcpAdministrator
    if ($Id -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') { throw 'INVALID_BACKUP_ID: 只接受备份 GUID，不接受路径。' }
    $root = Get-WinUtilMcpBackupRoot
    $path = Join-Path $root ($Id + '.json')
    Assert-WinUtilMcpBackupAcl $path
    $backup = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    Assert-WinUtilMcpFields $backup @('schemaVersion', 'id', 'operation', 'createdUtc', 'machine', 'userSid', 'entries') @('schemaVersion', 'id', 'operation', 'machine', 'userSid', 'entries')
    if ($backup.schemaVersion -ne 1 -or $backup.id -cne $Id -or $backup.machine -cne [Environment]::MachineName -or
        $backup.userSid -cne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value -or @('apply_tweaks', 'set_dns') -cnotcontains $backup.operation) { throw 'INVALID_BACKUP: 备份版本、来源机器或用户不匹配。' }
    if ($backup.entries -isnot [array] -or $backup.entries.Count -lt 1 -or $backup.entries.Count -gt 5000) { throw 'INVALID_BACKUP: 备份项目数量无效。' }
    # Validate the complete backup before restoring the first item.
    foreach ($entry in $backup.entries) { Assert-WinUtilMcpBackupEntry $entry }
    $results = New-Object 'System.Collections.Generic.List[object]'
    $entries = @($backup.entries)
    # Reverse order matters when a plan touched the same property more than once.
    [array]::Reverse($entries)
    foreach ($entry in $entries) {
        try {
            switch ($entry.kind) {
                'registry' {
                    if ($entry.existed) { Set-WinUtilMcpRegistry $entry.path $entry.name $entry.type $entry.value }
                    else { Set-WinUtilMcpRegistry $entry.path $entry.name -Remove }
                }
                'service' {
                    Set-Service -Name $entry.name -StartupType $entry.startupType -ErrorAction Stop
                    $delayed = $entry.delayed
                    $expectedPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($entry.name)"
                    if ($delayed.existed) { Set-WinUtilMcpRegistry $expectedPath 'DelayedAutoStart' $delayed.type $delayed.value }
                    else { Set-WinUtilMcpRegistry $expectedPath 'DelayedAutoStart' -Remove }
                }
                'dns' {
                    foreach ($family in $entry.families) {
                        Assert-WinUtilMcpAdapterIdentity $entry.adapter (@(Get-WinUtilMcpAdapters) | Where-Object { $_.id -ceq $entry.adapter.id } | Select-Object -First 1)
                        foreach ($address in $family.addresses) { $null = [Net.IPAddress]::Parse($address) }
                        Set-WinUtilMcpDnsFamily $entry.adapter.interfaceIndex $family.family @($family.addresses) -Reset:([bool]$family.automatic)
                    }
                }
                default { throw 'INVALID_BACKUP: 备份包含不支持的项目。' }
            }
            $results.Add([pscustomobject]@{ kind = $entry.kind; status = 'completed' })
        } catch {
            $done = $results.Count
            $results.Add([pscustomobject]@{ kind = $entry.kind; status = 'failed'; error = $_.Exception.Message; mayHaveChanged = $true })
            return [pscustomobject]@{ schemaVersion = 1; status = $(if ($done -gt 0) { 'partial' } else { 'failed' }); results = @($results.ToArray()); backupId = $Id }
        }
    }
    return [pscustomobject]@{ schemaVersion = 1; status = 'completed'; results = @($results.ToArray()); backupId = $Id; note = '原值已恢复；新建的空注册表键保留，避免删除其他程序在此期间新增的设置。' }
}

function Assert-WinUtilMcpBackupEntry {
    param($Entry)
    switch ($Entry.kind) {
        'registry' {
            Assert-WinUtilMcpFields $Entry @('kind', 'path', 'name', 'existed', 'keyExisted', 'type', 'value') @('kind', 'path', 'name', 'existed', 'keyExisted', 'type', 'value')
            $null = Get-WinUtilMcpRegistryLocation $Entry.path
            if ($Entry.existed -isnot [bool] -or $Entry.keyExisted -isnot [bool] -or $Entry.name -isnot [string] -or $Entry.name -match '[\x00-\x1f\\]') { throw 'INVALID_BACKUP: 注册表原值记录无效。' }
            if ($Entry.existed) {
                switch ($Entry.type) {
                    'DWord' { $number = [long]::Parse([string]$Entry.value); if ($number -lt [int]::MinValue -or $number -gt [uint32]::MaxValue) { throw 'INVALID_BACKUP: DWord 超出范围。' } }
                    'QWord' { $null = [long]::Parse([string]$Entry.value) }
                    'String' { if ($Entry.value -isnot [string]) { throw 'INVALID_BACKUP: String 类型无效。' } }
                    'ExpandString' { if ($Entry.value -isnot [string]) { throw 'INVALID_BACKUP: ExpandString 类型无效。' } }
                    'MultiString' { if ($Entry.value -isnot [array] -or @($Entry.value | Where-Object { $_ -isnot [string] }).Count -gt 0) { throw 'INVALID_BACKUP: MultiString 类型无效。' } }
                    'Binary' { if ($Entry.value -isnot [array]) { throw 'INVALID_BACKUP: Binary 类型无效。' }; foreach ($byte in $Entry.value) { $null = [byte]$byte } }
                    default { throw 'INVALID_BACKUP: 不支持的注册表类型。' }
                }
            }
        }
        'service' {
            Assert-WinUtilMcpFields $Entry @('kind', 'name', 'startupType', 'delayed') @('kind', 'name', 'startupType', 'delayed')
            if ($Entry.name -notmatch '^[A-Za-z0-9_.-]{1,128}$' -or @('Automatic', 'Manual', 'Disabled') -cnotcontains $Entry.startupType) { throw 'INVALID_BACKUP: 服务恢复内容无效。' }
            Assert-WinUtilMcpBackupEntry $Entry.delayed
            if ($Entry.delayed.kind -cne 'registry' -or $Entry.delayed.path -cne "HKLM:\SYSTEM\CurrentControlSet\Services\$($Entry.name)" -or $Entry.delayed.name -cne 'DelayedAutoStart') { throw 'INVALID_BACKUP: 服务延迟启动记录不匹配。' }
        }
        'dns' {
            Assert-WinUtilMcpFields $Entry @('kind', 'adapter', 'families') @('kind', 'adapter', 'families')
            if ($Entry.families -isnot [array] -or $Entry.families.Count -ne 2) { throw 'INVALID_BACKUP: DNS 协议记录不完整。' }
            if (@($Entry.families.family | Select-Object -Unique).Count -ne 2) { throw 'INVALID_BACKUP: DNS 协议记录重复。' }
            foreach ($family in $Entry.families) {
                Assert-WinUtilMcpFields $family @('family', 'automatic', 'addresses') @('family', 'automatic', 'addresses')
                if (@('IPv4', 'IPv6') -cnotcontains $family.family -or $family.automatic -isnot [bool] -or $family.addresses -isnot [array]) { throw 'INVALID_BACKUP: DNS 地址记录无效。' }
                if (-not $family.automatic -and $family.addresses.Count -eq 0) { throw 'INVALID_BACKUP: 静态 DNS 地址为空。' }
                foreach ($address in $family.addresses) {
                    $parsed = [Net.IPAddress]::Parse($address)
                    if (($parsed.AddressFamily.ToString() -eq 'InterNetwork') -ne ($family.family -eq 'IPv4')) { throw 'INVALID_BACKUP: DNS 地址协议不匹配。' }
                }
            }
            Assert-WinUtilMcpFields $Entry.adapter @('id', 'interfaceIndex', 'name', 'macAddress', 'description') @('id', 'interfaceIndex', 'name', 'macAddress', 'description')
            if ($Entry.adapter.id -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' -or $Entry.adapter.interfaceIndex -lt 1) { throw 'INVALID_BACKUP: 网卡记录无效。' }
        }
        default { throw 'INVALID_BACKUP: 不支持的备份项目。' }
    }
}
