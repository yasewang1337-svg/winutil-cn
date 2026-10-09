function New-WinUtilISOWorkspace {
    <# .SYNOPSIS Creates a fresh administrator-only directory and records this session's source image. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourceISO, [Parameter(Mandatory)]$Profile)
    $path = New-WinUtilToolWorkspace
    $manifest = [ordered]@{
        Schema = 1; Id = (Split-Path $path -Leaf); State = 'Preparing'
        SourceISO = [IO.Path]::GetFullPath($SourceISO)
        WindowsVersion = $Profile.WindowsVersion; ImageIndex = $Profile.ImageIndex
        ImageName = $Profile.ImageName; Architecture = $Profile.Architecture
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
    }
    $manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $path 'winutil-iso.json') -Encoding UTF8 -ErrorAction Stop
    return $path
}

function Assert-WinUtilISOWorkspace {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [switch]$Completed, [string]$Root = [Environment]::GetFolderPath('CommonApplicationData'))
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    if ((Split-Path $full -Parent) -ne [IO.Path]::GetFullPath($Root).TrimEnd('\') -or
        (Split-Path $full -Leaf) -notmatch '^WinUtil-Tool-[a-f0-9]{32}$') { throw '工作目录不属于本次镜像制作，已中止。' }
    $directory = Get-Item -LiteralPath $full -Force -ErrorAction Stop
    if (-not $directory.PSIsContainer -or ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw '镜像工作目录是链接或不是文件夹，已中止。' }
    $marker = Get-Item -LiteralPath (Join-Path $full 'winutil-iso.json') -Force -ErrorAction Stop
    if ($marker.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw '镜像工作记录是链接，已中止。' }
    $manifest = Get-Content -LiteralPath $marker.FullName -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
    if ($manifest.Schema -ne 1 -or $manifest.Id -cne (Split-Path $full -Leaf) -or $manifest.WindowsVersion -notin @('Windows10','Windows11')) { throw '镜像工作记录不匹配，已中止。' }
    if ($Completed -and $manifest.State -ne 'Completed') { throw '镜像修改尚未成功完成，不能导出或写入 U 盘。' }
    return $manifest
}

function Set-WinUtilISOWorkspaceState {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][ValidateSet('Preparing','Completed','Failed')][string]$State)
    $manifest = Assert-WinUtilISOWorkspace -Path $Path
    $manifest.State = $State
    $manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Path 'winutil-iso.json') -Encoding UTF8 -ErrorAction Stop
}

function Remove-WinUtilISOWorkspace {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $null = Assert-WinUtilISOWorkspace -Path $Path
    $mount = Join-Path $Path 'wim_mount'
    $mounted = @(Get-WindowsImage -Mounted -ErrorAction Stop | Where-Object { $_.Path -eq $mount -or $_.Path -eq (Join-Path $Path 'boot_mount') })
    foreach ($image in $mounted) { Dismount-WindowsImage -Path $image.Path -Discard -ErrorAction Stop }
    # Never follow links while deleting a tree copied from external installation media.
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push([IO.Path]::GetFullPath($Path))
    while ($pending.Count) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "工作目录中存在链接，未递归删除：$($item.FullName)" }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    Remove-Item -LiteralPath ([IO.Path]::GetFullPath($Path)) -Recurse -Force -ErrorAction Stop
}
