function Invoke-WinUtilPackageOperation {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Plan, [switch]$NonInteractive)
    if ($sync.ProcessRunning) {
        if ($NonInteractive -or -not $sync.form) { Write-Warning '当前有任务正在运行，未启动新的软件操作。' }
        else { $null = [Windows.MessageBox]::Show('当前有任务正在运行，请等待结束后再试。', 'WinUtil CN') }
        return
    }
    if ($Plan.Count -eq 0) {
        if ($NonInteractive -or -not $sync.form) { Write-Warning '没有选择软件，未执行。' }
        else { $null = [Windows.MessageBox]::Show('请先选择要处理的软件。', 'WinUtil CN') }
        return
    }
    if ($NonInteractive -or -not $sync.form) {
        $sync.ProcessRunning = $true
        try {
            $batch = Invoke-WinUtilPackageBatch -Plan $Plan -PrepareManagers
            $sync.LastPackageRun = $batch; $sync.LastPackageResults = $batch.Results
            return $batch
        } finally { $sync.ProcessRunning = $false }
    }
    $actionLabels = @{ Install = '安装 / 升级'; Uninstall = '卸载'; UpgradeAll = '更新全部' }
    $action = $Plan[0].Action
    $description = "即将$($actionLabels[$action])以下 $($Plan.Count) 项。请核对软件名称与范围；安装 / 更新会联网下载并接受所列软件的软件包与软件源协议。"
    $description += ' 每个软件包独立处理；某项失败后会继续处理后续项。'
    if ($action -eq 'Uninstall') {
        $description = '即将卸载以下软件。卸载可能删除软件设置，请先保存工作；重新安装不保证恢复原设置。'
        $description += ' 每个软件包独立处理，某项失败后会继续处理后续项。'
    } elseif ($action -eq 'UpgradeAll') {
        $description = "将更新 $($Plan[0].Manager) 可识别的所有软件，范围不限于当前勾选项。WinGet 仅使用 winget 源，会跳过无法识别版本和已固定版本的软件。此入口只能报告整批结果，具体软件详情保存在日志中。继续会联网下载并接受相关软件包及软件源协议。请先保存工作。"
    }
    $details = ($Plan | ForEach-Object { "$($actionLabels[$_.Action])  $($_.Name)`r`n软件包：$($_.PackageId) · $($_.Manager)`r`n$($_.InvalidReason)" }) -join "`r`n`r`n"
    if ($action -ne 'Uninstall') {
        $missing = @($Plan.Manager | Select-Object -Unique | Where-Object {
            $executable = if ($_ -eq 'Choco') { 'choco.exe' } else { 'winget.exe' }
            -not (Get-Command $executable -CommandType Application -ErrorAction SilentlyContinue)
        })
        if ('Winget' -in $missing) { $description += "`r`n首次使用将先联网准备 WinGet 软件包管理器。" }
        if ('Choco' -in $missing) {
            $description += "`r`nChocolatey 未安装：请按官方说明 https://chocolatey.org/install 手动安装，或在设置中改用默认 WinGet。继续执行时，依赖 Chocolatey 的软件将报告失败。"
        }
    }
    if ((Show-WinUtilPackageDialog -Title '确认软件操作' -Description $description -Details $details) -ne 'Primary') { return }
    Initialize-WinUtilPackageUiCallbacks
    # Reserve busy before dispatch so rapid clicks cannot start competing batches.
    $sync.ProcessRunning = $true
    try {
        $null = Invoke-WPFRunspace -ParameterList (, @("Plan", $Plan)) -ScriptBlock {
            param($Plan)
            $allResults = @()
            try {
                $pendingPlan = $Plan
                do {
                    $sync.PackageProgressText = '正在准备软件任务…'
                    Invoke-WinUtilPackageUiAction -Action Progress
                    $batch = Invoke-WinUtilPackageBatch -Plan $pendingPlan -PrepareManagers -OnProgress {
                        param($item, $position, $total)
                        $sync.PackageProgressText = "[$position / $total] $($item.Name)"
                        Invoke-WinUtilPackageUiAction -Action Progress
                    }
                    $sync.LastPackageRun = $batch
                    $changedIds = @($batch.Results.Id)
                    $allResults = @($allResults | Where-Object { $_.Id -notin $changedIds }) + @($batch.Results)
                    $sync.LastPackageResults = $allResults
                    Invoke-WinUtilPackageUiAction -Action Hide
                    $failed = @($allResults | Where-Object Status -eq 'Failed')
                    $successful = @($allResults | Where-Object Status -eq 'Succeeded')
                    $skipped = @($allResults | Where-Object Status -eq 'Skipped')
                    $reboot = @($allResults | Where-Object Status -eq 'RebootRequired')
                    $summary = "成功 $($successful.Count) 项 · 失败 $($failed.Count) 项 · 已跳过 $($skipped.Count) 项 · 需重启 $($reboot.Count) 项。"
                    if (@($allResults | Where-Object NeedsReboot).Count) { $summary += ' 请保存工作，并在方便时重启电脑。' }
                    if ($batch.LogWarning) { $summary += "`r`n$($batch.LogWarning)" }
                    $resultText = ($allResults | ForEach-Object {
                        "[$($_.StatusText)] $($_.Name) · $($_.PackageId)`r`n$($_.Reason)`r`n退出码：$($_.ExitCode) $($_.ExitCodeHex)`r`n输出日志：$($_.OutputPath)`r`n错误日志：$($_.ErrorPath)"
                    }) -join "`r`n`r`n"
                    # Bulk retries would repeat successes; offer retries only for known individual failures.
                    $retryable = @($failed | Where-Object Action -ne 'UpgradeAll')
                    $retryLabel = ''
                    if ($retryable.Count) { $retryLabel = "仅重试失败项（$($retryable.Count)）" }
                    $sync.PackageRetryRequested = $false
                    $sync.PackageResultSummary = $summary
                    $sync.PackageResultDetails = $resultText
                    $sync.PackageRetryLabel = $retryLabel
                    Invoke-WinUtilPackageUiAction -Action Results
                    $pendingPlan = @($retryable | ForEach-Object { $_.Plan })
                } while ($sync.PackageRetryRequested -and $pendingPlan.Count)
            } catch {
                Write-Warning "软件任务异常中止：$($_.Exception.Message)"
                $sync.PackageOperationError = $_.Exception.Message
                Invoke-WinUtilPackageUiAction -Action Error
            } finally {
                $sync.ProcessRunning = $false
                Invoke-WinUtilPackageUiAction -Action Hide
            }
        }
    } catch {
        $sync.ProcessRunning = $false
        Hide-WPFInstallAppBusy
        $null = [Windows.MessageBox]::Show("无法启动软件任务：$($_.Exception.Message)", 'WinUtil CN')
    }
}
