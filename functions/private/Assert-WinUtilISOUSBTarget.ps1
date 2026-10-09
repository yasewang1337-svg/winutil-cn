function Assert-WinUtilISOUSBTarget {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Expected, [Parameter(Mandatory)]$Current)
    if ($Current.BusType -ne 'USB' -or $Current.IsBoot -ne $false -or $Current.IsSystem -ne $false -or $Current.IsReadOnly) {
        throw '目标不是可写的普通 USB 数据盘，或包含当前系统/启动分区；已中止。'
    }
    if ([string]::IsNullOrWhiteSpace([string]$Expected.UniqueId) -or
        [string]$Current.UniqueId -cne [string]$Expected.UniqueId -or
        [string]$Current.SerialNumber -cne [string]$Expected.SerialNumber -or
        [int]$Current.Number -ne [int]$Expected.Number -or [int64]$Current.Size -ne [int64]$Expected.Size) {
        throw 'USB 磁盘身份或容量已变化，请刷新列表后重新确认；未擦除磁盘。'
    }
}

function Measure-WinUtilISOUSBContents {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ContentsDirectory, [Parameter(Mandatory)][long]$DiskSize)
    if (-not (Test-Path -LiteralPath (Join-Path $ContentsDirectory 'sources\install.wim') -PathType Leaf)) { throw '未找到制作完成的 install.wim。' }
    $files = @(Get-ChildItem -LiteralPath $ContentsDirectory -File -Recurse -Force -ErrorAction Stop)
    foreach ($file in $files) {
        if ($file.Length -ge 4GB -and $file.FullName -ne (Join-Path $ContentsDirectory 'sources\install.wim')) {
            throw "文件超过 FAT32 单文件限制，不能写入：$($file.Name)"
        }
    }
    $bytes = [long](($files | Measure-Object Length -Sum).Sum)
    $capacity = [Math]::Min($DiskSize - 32MB, 32700MB)
    if ($capacity -le 0 -or $bytes + 64MB -gt $capacity) { throw 'U 盘可用制作分区容量不足，尚未擦除任何数据。请使用更大U盘，或导出 ISO。' }
    return $bytes
}
