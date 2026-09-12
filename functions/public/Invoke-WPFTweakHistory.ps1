function Invoke-WPFTweakHistory {
    <# .SYNOPSIS Shows readable results and the scope of recorded recovery. #>
    param([switch]$ShowLastResults, [object[]]$Results)
    $labels = @{ Success = '完成'; Failed = '失败'; Skipped = '跳过'; Unverified = '待确认'; Partial = '部分完成'; Pending = '已保存快照'; Restored = '已处理恢复' }
    if ($ShowLastResults) {
        $title = '本次设置结果'
        if (-not $PSBoundParameters.ContainsKey('Results')) { $Results = @($sync.LastTweakResults) }
        $lines = @($Results | ForEach-Object { "[$($labels[$_.Status])] $($_.Name)`n$($_.Message)" })
    } else {
        $title = '设置操作历史'
        $lines = @(Get-WinUtilTweakHistory | Select-Object -First 50 | ForEach-Object {
            $time = ([datetime]$_.CreatedAt).ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')
            $entryLines = @($_.Entries | ForEach-Object {
                if ($_.Kind -eq 'Registry') {
                    $before = '原先不存在该值'
                    if ($_.Exists) {
                        $before = "[$($_.ValueType)] " + ($_.Value -join ' | ')
                        if ($before.Length -gt 180) { $before = $before.Substring(0, 180) + '…（完整值保存在记录文件）' }
                    }
                    "  修改前 $($_.Path)\$($_.Name)：$before"
                } else {
                    "  修改前服务 $($_.Name)：$($_.StartupType)，延迟启动值：$($_.DelayedAutoStart.Value)"
                }
            })
            "$time  [$($labels[$_.Status])] $($_.Name)`n$($_.Message)`n$($entryLines -join "`n")"
        })
    }
    if (-not $lines.Count) { $lines = @('尚无本工具保存的设置记录。旧版本执行的项目不能精确恢复。') }
    $message = ($lines -join "`n`n") + "`n`n恢复方法：在设置页勾选项目，点击「恢复所选设置」。每次恢复该项目最近一条未撤销的记录。`n仅登记的注册表值和服务启动配置支持恢复；应用、文件及脚本的其他改动不在范围内。`n记录目录：$env:LOCALAPPDATA\WinUtil\TweakHistory"
    if ($sync.Form) { Show-WinUtilTweakDialog -Title $title -Message $message | Out-Null }
    else { Write-Host $message }
}
