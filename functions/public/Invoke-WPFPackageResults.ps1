function Invoke-WPFPackageResults {
    <# Review the latest software operation from this app session without rerunning it. #>
    if ($sync.ProcessRunning) {
        Show-WinUtilPackageDialog -Title '软件任务正在进行' -Description '请等待当前任务结束后查看结果。' -Details '完成后会自动显示结果；关闭窗口后仍可从“查看上次结果”重新打开。' -PrimaryLabel '' -CloseLabel '关闭' | Out-Null
        return
    }
    $results = @($sync.LastPackageResults | Where-Object { $null -ne $_ })
    if (-not $results.Count) {
        $description = '当前会话还没有软件操作结果。'
        $details = '先选择软件，查看清单并确认执行。完成后可以在这里重新查看结果与日志；重新启动程序后不会自动加载以前的记录。'
        if ($sync.PackageOperationError) {
            $description = '上次软件任务异常中止，尚未取得完整结果。'
            $details = "$($sync.PackageOperationError)`r`n请检查控制台与操作日志；不要将没有结果视为操作成功。"
        }
        Show-WinUtilPackageDialog -Title '上次软件操作结果' -Description $description -Details $details -PrimaryLabel '' -CloseLabel '关闭' | Out-Null
        return
    }
    $view = Get-WinUtilPackageResultView -Results $results -LogWarning $sync.LastPackageRun.LogWarning
    $description = $view.Summary + "`r`n当前会话的上次软件任务。查看不会重新执行；重试前会再次核对清单。"
    if ($sync.PackageOperationError) { $description += "`r`n任务曾异常中止，以下仅为已取得的结果：$($sync.PackageOperationError)" }
    $choice = Show-WinUtilPackageDialog -Title '上次软件操作结果' -Description $description -Details $view.Details -Results $results -PrimaryLabel $view.RetryLabel -CloseLabel '关闭' -LogDirectory $sync.LastPackageRun.LogDirectory
    if ($choice -eq 'Primary' -and $view.RetryPlan.Count) {
        Invoke-WinUtilPackageOperation -Plan $view.RetryPlan
    }
}
