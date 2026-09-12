function Set-WinUtilService {
    <# .SYNOPSIS Changes service startup configuration; never masks a failed change. #>
    [CmdletBinding()]
    param($Name, $StartupType)
    if ($StartupType -eq 'Disable') { $StartupType = 'Disabled' }
    $service = Get-Service -Name $Name -ErrorAction Stop
    if (($PSVersionTable.PSVersion.Major -lt 7) -and ($StartupType -eq 'AutomaticDelayedStart')) {
        $output = & sc.exe config $Name start= delayed-auto 2>&1
        if ($LASTEXITCODE -ne 0) { throw "服务 $Name 启动方式设置失败：$output" }
    } else {
        $service | Set-Service -StartupType $StartupType -ErrorAction Stop
    }
}
