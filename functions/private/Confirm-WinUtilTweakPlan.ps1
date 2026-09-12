function Confirm-WinUtilTweakPlan {
    <# .SYNOPSIS Explains selected changes and recovery limits before execution. #>
    param([string[]]$Tweaks, [switch]$Undo, [string]$DNSProvider = 'Default')
    $lines = @()
    foreach ($id in $Tweaks) {
        $tweak = $sync.configs.tweaks.$id
        $lines += "• $($tweak.Content)：$($tweak.Description)"
    }
    if ($Undo) {
        $heading = '将按最近未撤销的记录，恢复所选项目修改前的注册表值和服务启动配置。没有记录的项目会跳过。'
        $footer = '应用、文件及脚本的其他改动无法由这里完整恢复。恢复会覆盖这些记录项当前的值；如果之后手动改过，请先核对操作历史。'
    } else {
        $heading = '请核对本次修改。设置会先保存修改前的记录，部分效果需要重启后确认。'
        $footer = '仅配置中列出的注册表值和服务启动配置可按记录恢复。应用卸载、文件清理及脚本的其他改动不支持完整恢复。'
    }
    if ($DNSProvider -ne 'Default') {
        $lines += "• DNS：$DNSProvider（会修改所有已连接网卡，包括 VPN；本次历史不包含 DNS，原配置不会自动恢复）"
    }
    $message = $heading + "`n`n" + ($lines -join "`n`n") + "`n`n" + $footer
    if (-not $sync.Form) {
        Write-Host $message
        # An unattended preset must not silently opt into opaque or irreversible operations.
        $unsupported = @($Tweaks | Where-Object {
            $item = $sync.configs.tweaks.$_
            $item.InvokeScript -or $item.appx -or $item.service
        })
        if (-not $Undo -and ($unsupported.Count -or $DNSProvider -ne 'Default')) {
            throw '自动模式仅执行可记录的注册表设置；脚本、服务、应用卸载与 DNS 请在界面中逐项确认。'
        }
        return $true
    }
    return Show-WinUtilTweakDialog -Title '确认本次设置' -Message $message -Confirm
}
