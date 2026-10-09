function Get-WinUtilPackageResultView {
    <# Build the same summary and retry scope for completion and later review. #>
    param([AllowEmptyCollection()][object[]]$Results = @(), [string]$LogWarning)
    $failed = @($Results | Where-Object Status -eq 'Failed')
    $successful = @($Results | Where-Object Status -eq 'Succeeded')
    $skipped = @($Results | Where-Object Status -eq 'Skipped')
    $reboot = @($Results | Where-Object Status -eq 'RebootRequired')
    $summary = "成功 $($successful.Count) 项 · 失败 $($failed.Count) 项 · 已跳过 $($skipped.Count) 项 · 需重启 $($reboot.Count) 项。"
    if (@($Results | Where-Object NeedsReboot).Count) { $summary += ' 请保存工作，并在方便时重启电脑。' }
    if ($LogWarning) { $summary += "`r`n$LogWarning" }
    $details = ($Results | ForEach-Object {
        "[$($_.StatusText)] $($_.Name) · $($_.PackageId)`r`n$($_.Reason)`r`n退出码：$($_.ExitCode) $($_.ExitCodeHex)`r`n输出日志：$($_.OutputPath)`r`n错误日志：$($_.ErrorPath)"
    }) -join "`r`n`r`n"
    # Whole-manager upgrades cannot safely retry individual failures.
    $retryPlan = @($failed | Where-Object { $_.Action -ne 'UpgradeAll' -and $null -ne $_.Plan } | ForEach-Object { $_.Plan })
    $retryLabel = if ($retryPlan.Count) { "仅重试失败项（$($retryPlan.Count)）" } else { '' }
    [pscustomobject]@{ Summary = $summary; Details = $details; RetryPlan = $retryPlan; RetryLabel = $retryLabel }
}
