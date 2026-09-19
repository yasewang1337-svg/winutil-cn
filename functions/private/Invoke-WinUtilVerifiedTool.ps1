function New-WinUtilToolWorkspace {
    <# .SYNOPSIS Creates an isolated tool directory writable only by elevated administrators and SYSTEM. #>
    [CmdletBinding()]
    param()

    $root = [Environment]::GetFolderPath('CommonApplicationData')
    if (-not $root) { throw '无法定位公共应用数据目录。' }
    $path = Join-Path $root ('WinUtil-Tool-' + [guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $path) { throw '工具临时目录已存在，已中止。' }
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $admins = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $acl.SetOwner($admins)
    foreach ($sid in @($admins, [Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new(
            $sid, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }
    # Apply the DACL at creation, before any downloaded content exists.
    $directory = [IO.DirectoryInfo]::new($path)
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        [IO.FileSystemAclExtensions]::Create($directory, $acl)
    } else {
        $directory.Create($acl)
    }
    return $path
}

function Remove-WinUtilToolWorkspace {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $full = [IO.Path]::GetFullPath($Path)
    $root = [Environment]::GetFolderPath('CommonApplicationData').TrimEnd('\', '/')
    if ([IO.Path]::GetDirectoryName($full) -ne $root -or
        [IO.Path]::GetFileName($full) -notmatch '^WinUtil-Tool-[a-f0-9]{32}$') {
        throw "工具目录不在允许清理的范围内：$full"
    }
    if (-not (Test-Path -LiteralPath $full)) { return }
    $directory = Get-Item -LiteralPath $full -Force -ErrorAction Stop
    if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw '工具目录是链接，未清理。' }
    # Tools use a flat directory. Never follow or recursively remove tool-created subdirectories.
    $items = @(Get-ChildItem -LiteralPath $full -Force -ErrorAction Stop)
    if (@($items | Where-Object { $_.PSIsContainer -or ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) }).Count) {
        throw "工具目录包含子目录或链接，保留以供检查：$full"
    }
    foreach ($item in $items) { Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop }
    Remove-Item -LiteralPath $full -Force -ErrorAction Stop
}

function Invoke-WinUtilVerifiedTool {
    <#
    .SYNOPSIS Downloads a known tool, verifies its integrity, and retains read locks until it exits.
    .DESCRIPTION
    ViVeTool is pinned to the SHA256 of the official v0.3.4 release ZIP for each architecture.
    O&O uses its official rolling URL and must have a valid O&O Software GmbH signature.
    This source is also embedded in autounattend.xml; sync it with tools/Sync-VerifiedToolTemplate.ps1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('ViVeTool', 'OOSU')][string]$Tool,
        [ValidateSet('Disable', 'Enable')][string]$Action = 'Disable'
    )

    $ErrorActionPreference = 'Stop'
    $previousProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    $workspace = $null
    $locks = [Collections.Generic.List[IDisposable]]::new()
    $stage = '创建受保护的临时目录'
    try {
        $workspace = New-WinUtilToolWorkspace
        $isArm64 = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64'
        if ($Tool -eq 'ViVeTool') {
            $uri = 'https://github.com/thebookisclosed/ViVe/releases/download/v0.3.4/ViVeTool-v0.3.4-IntelAmd.zip'
            $expectedZipHash = 'CC27F073F3FE5DD2C3D947FAF558FD4B2F8E34454F812689B0D65EE8A52E4147'
            if ($isArm64) {
                $uri = 'https://github.com/thebookisclosed/ViVe/releases/download/v0.3.4/ViVeTool-v0.3.4-SnapdragonArm64.zip'
                $expectedZipHash = '30AD9A4912686355BFCE60E1D7BEF608735475B7E2160D67418EED8F5E3BA8C7'
            }
            $download = Join-Path $workspace 'ViVeTool.zip'
        } else {
            $uri = 'https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe'
            if ($isArm64) { $uri = 'https://dl5.oo-software.com/files/ooshutup10/OOSU10-arm64.exe' }
            elseif (-not [Environment]::Is64BitOperatingSystem) { $uri = 'https://dl5.oo-software.com/files/ooshutup10/OOSU10-x86.exe' }
            $download = Join-Path $workspace 'OOSU10.exe'
        }
        $stage = '下载'
        Invoke-WebRequest -Uri $uri -OutFile $download -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
        $downloadLock = [IO.File]::Open($download, 'Open', 'Read', 'Read')
        $locks.Add($downloadLock)

        if ($Tool -eq 'ViVeTool') {
            $stage = '校验下载包 SHA256'
            $actualHash = (Get-FileHash -InputStream $downloadLock -Algorithm SHA256 -ErrorAction Stop).Hash
            if ($actualHash -ne $expectedZipHash) { throw '下载包与固定版本的可信哈希不符，已拒绝执行。' }
            $downloadLock.Position = 0
            $stage = '解压并校验工具文件'
            Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
            $archive = [IO.Compression.ZipArchive]::new($downloadLock, [IO.Compression.ZipArchiveMode]::Read, $true)
            try {
                $expectedNames = @('Albacore.ViVe.dll', 'FeatureDictionary.pfs', 'Newtonsoft.Json.dll', 'ViVeTool.exe')
                if ($archive.Entries.Count -ne $expectedNames.Count) { throw '下载包的文件清单异常。' }
                $seen = @{}
                foreach ($entry in $archive.Entries) {
                    if ($entry.FullName -cnotin $expectedNames -or $seen.ContainsKey($entry.FullName) -or
                        $entry.Length -le 0 -or $entry.Length -gt 20MB) { throw '下载包包含异常文件。' }
                    $seen[$entry.FullName] = $true
                    $target = Join-Path $workspace $entry.FullName
                    $source = $entry.Open()
                    try {
                        $destination = [IO.File]::Open($target, 'CreateNew', 'Write', 'None')
                        try { $source.CopyTo($destination) } finally { $destination.Dispose() }
                    } finally { $source.Dispose() }
                    # Lock first, then compare the locked bytes with the verified archive entry.
                    $fileLock = [IO.File]::Open($target, 'Open', 'Read', 'Read')
                    $locks.Add($fileLock)
                    $source = $entry.Open()
                    try {
                        $expectedHash = (Get-FileHash -InputStream $source -Algorithm SHA256 -ErrorAction Stop).Hash
                        $fileHash = (Get-FileHash -InputStream $fileLock -Algorithm SHA256 -ErrorAction Stop).Hash
                        if ($fileHash -ne $expectedHash) { throw "解压后的文件校验失败：$($entry.FullName)" }
                    } finally { $source.Dispose() }
                }
            } finally { $archive.Dispose() }
            $executable = Join-Path $workspace 'ViVeTool.exe'
            $arguments = @('/' + $Action.ToLowerInvariant(), '/id:47205210')
        } else {
            $stage = '校验数字签名及发布者'
            $signature = Get-AuthenticodeSignature -LiteralPath $download -ErrorAction Stop
            if ($signature.Status -ne 'Valid' -or -not $signature.SignerCertificate) {
                throw 'O&O 数字签名无效或无法确认，已拒绝执行。'
            }
            $publisher = $signature.SignerCertificate.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
            if ($publisher -cne 'O&O Software GmbH') { throw '数字签名的发布者不是 O&O Software GmbH，已拒绝执行。' }
            $executable = $download
        }

        $stage = '运行'
        $startParameters = @{
            FilePath = $executable; WorkingDirectory = $workspace
            Wait = $true; PassThru = $true; ErrorAction = 'Stop'
        }
        if ($Tool -eq 'ViVeTool') {
            $startParameters.ArgumentList = $arguments
            $startParameters.NoNewWindow = $true
            $stdoutPath = Join-Path $workspace 'stdout.log'
            $stderrPath = Join-Path $workspace 'stderr.log'
            $startParameters.RedirectStandardOutput = $stdoutPath
            $startParameters.RedirectStandardError = $stderrPath
        }
        $process = Start-Process @startParameters
        if ($null -eq $process -or $null -eq $process.ExitCode) { throw '未取得工具退出码，无法确认执行完成。' }
        if ($process.ExitCode -ne 0) { throw "工具报告失败，退出码：$($process.ExitCode)。" }
        if ($Tool -eq 'ViVeTool') {
            # v0.3.4 Main returns void even when setting a feature fails. Exit 0 alone is insufficient.
            $stage = '确认工具执行结果'
            $stdout = [IO.File]::ReadAllText($stdoutPath)
            $stderr = [IO.File]::ReadAllText($stderrPath)
            # This pinned release writes warnings/errors to stdout too, sometimes before its success line.
            $lines = @($stdout -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            if ($lines.Count -ne 2 -or
                $lines[0] -cne 'ViVeTool v0.3.4 - Windows feature configuration tool' -or
                $lines[1] -cne 'Successfully set feature configuration(s)' -or
                -not [string]::IsNullOrWhiteSpace($stderr)) {
                $detail = ($stdout + "`n" + $stderr).Trim()
                if ($detail.Length -gt 2000) { $detail = $detail.Substring(0, 2000) }
                throw "ViVeTool 未确认设置成功；退出码为 0 也可能表示设置失败。输出：$detail"
            }
        }
        return [pscustomobject]@{ Tool = $Tool; ExitCode = $process.ExitCode }
    } catch {
        throw "$Tool $stage 失败：$($_.Exception.Message)"
    } finally {
        for ($i = $locks.Count - 1; $i -ge 0; $i--) { $locks[$i].Dispose() }
        if ($workspace) {
            try { Remove-WinUtilToolWorkspace -Path $workspace }
            catch { Write-Warning "工具临时目录清理失败：$workspace。$($_.Exception.Message)" }
        }
        $ProgressPreference = $previousProgress
    }
}
