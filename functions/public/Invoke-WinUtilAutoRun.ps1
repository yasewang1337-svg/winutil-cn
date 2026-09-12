function Invoke-WinUtilAutoRun {
    <# .SYNOPSIS Runs an explicitly supplied command-line plan and propagates incomplete results. #>
    if ($sync.selectedFeatures.Count -gt 0) {
        throw '此清单包含系统功能操作。请在图形界面导入清单后查看并执行；当前自动模式支持软件和可记录的基础设置。'
    }
    $settings = @($sync.selectedTweaks) + @($sync.selectedToggles)
    if ($settings.Count) {
        $sync.selectedTweaks = [System.Collections.Generic.List[string]]::new()
        foreach ($id in ($settings | Select-Object -Unique)) { $sync.selectedTweaks.Add($id) }
        $sync.LastTweakResults = @()
        Invoke-WPFtweaksbutton
        while ($sync.ProcessRunning) { Start-Sleep -Milliseconds 100 }
        $results = @($sync.LastTweakResults)
        if (-not $results.Count -or @($results | Where-Object { $_.Status -ne 'Success' }).Count) {
            throw '设置清单未全部完成，后续软件操作已停止。请查看逐项结果，或在界面中确认不支持自动执行的项目。'
        }
    }
    if ($sync.selectedApps.Count -gt 0) {
        $sync.LastPackageResults = @()
        $null = Invoke-WPFInstall -NonInteractive
        $results = @($sync.LastPackageResults)
        if (-not $results.Count -or @($results | Where-Object Status -eq 'Failed').Count) {
            throw '软件清单未全部完成，请查看逐项结果和操作日志。'
        }
        if (@($results | Where-Object NeedsReboot).Count) { Write-Host '软件任务已处理，部分项目需要重启后生效。' }
    }
    Write-Host '清单已处理，请以上方逐项结果为准。'
}
