function Get-WinUtilISOImageProfile {
    <# .SYNOPSIS Validates detailed DISM metadata; display names alone never select an image profile. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Image)
    $name = [string]$Image.ImageName
    $architecture = ([string]$Image.Architecture).ToLowerInvariant()
    if ($architecture -notin @('9', 'amd64', 'x64')) {
        throw "镜像 '$name' 的架构为 '$architecture'；本工具仅制作 x64 镜像，不支持 x86 / ARM64。"
    }
    $version = $null
    if (-not [version]::TryParse([string]$Image.Version, [ref]$version) -or $version.Major -ne 10) {
        throw "镜像 '$name' 缺少可识别的 Windows 10/11 版本元数据。"
    }
    if ($Image.InstallationType -and [string]$Image.InstallationType -ne 'Client') {
        throw "镜像 '$name' 不是 Windows 客户端安装镜像。"
    }
    if ($name -match '^Windows 10(?:\s|$)' -and $version.Build -ge 19041 -and $version.Build -le 19045) {
        $system = 'Windows10'
        $label = 'Windows 10'
    } elseif ($name -match '^Windows 11(?:\s|$)' -and $version.Build -ge 22000) {
        $system = 'Windows11'
        $label = 'Windows 11'
    } else {
        throw "镜像名称与版本不受支持：$name / $version。请选择 Windows 10 22H2 或 Windows 11 的微软 x64 安装镜像。"
    }
    if ([int]$Image.ImageIndex -lt 1) { throw '镜像索引无效。' }
    [pscustomobject]@{
        ImageIndex = [int]$Image.ImageIndex; ImageName = $name
        WindowsVersion = $system; DisplayName = $label; Architecture = 'x64'; Version = $version.ToString()
    }
}

function Get-WinUtilISOImageProfiles {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ImagePath)
    $entries = @(Get-WindowsImage -ImagePath $ImagePath -ErrorAction Stop)
    if ($entries.Count -eq 0) { throw '安装镜像中没有可选择的 Windows 版本。' }
    $profiles = @($entries | ForEach-Object {
        $details = Get-WindowsImage -ImagePath $ImagePath -Index $_.ImageIndex -ErrorAction Stop
        Get-WinUtilISOImageProfile -Image $details
    })
    if (@($profiles.WindowsVersion | Sort-Object -Unique).Count -ne 1) {
        throw '不支持混合 Windows 10 / Windows 11 的安装镜像，请选择单一系统的微软原版 ISO。'
    }
    return $profiles
}

function Assert-WinUtilISODriverCompatibility {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Profile, [Parameter(Mandatory)][int]$HostBuild, [string]$HostArchitecture = $env:PROCESSOR_ARCHITECTURE)
    $hostSystem = if ($HostBuild -ge 22000) { 'Windows11' } elseif ($HostBuild -ge 19041 -and $HostBuild -le 19045) { 'Windows10' } else { 'Unsupported' }
    if ($HostArchitecture -notin @('AMD64', 'x64') -or $Profile.WindowsVersion -ne $hostSystem) {
        throw "不能把当前系统驱动注入 $($Profile.DisplayName) x64：本机与目标必须为同一 Windows 代际且均为 x64。请关闭‘加入本机驱动’后继续制作。"
    }
}

function Assert-WinUtilISONativeExit {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Operation, [Parameter(Mandatory)][int]$ExitCode, [switch]$Robocopy)
    if (($Robocopy -and ($ExitCode -lt 0 -or $ExitCode -ge 8)) -or (-not $Robocopy -and $ExitCode -notin @(0,3010))) {
        throw "$Operation 失败，退出码 $ExitCode；未报告制作成功。"
    }
}
