function New-WinUtilTweakRestorePoint {
    <# .SYNOPSIS Creates a restore point and verifies its presence before continuing. #>
    [CmdletBinding()]
    param()
    if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)) {
        throw '当前 PowerShell 不支持创建还原点。请使用中文版 EXE（Windows PowerShell 5.1）运行，或在 Windows 系统保护中手动创建。'
    }
    $existing = @(Get-ComputerRestorePoint -ErrorAction Stop)
    if (-not $existing.Count) { Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction Stop }
    $description = 'WinUtil ' + [guid]::NewGuid().ToString('N')
    Checkpoint-Computer -Description $description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    $created = @(Get-ComputerRestorePoint -ErrorAction Stop | Where-Object Description -EQ $description)
    if (-not $created.Count) { throw '未能确认新的系统还原点，后续修改已停止。请检查系统保护和磁盘空间后重试。' }
    Write-Host '已创建并确认新的系统还原点。'
}
