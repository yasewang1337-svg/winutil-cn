function Invoke-WPFFeatureInstall {
    <# Installs the reviewed selection and always releases the shared task state. #>
    if ($sync.ProcessRunning) {
        Write-Warning '当前有任务正在运行，请等待结束后再安装 Windows 功能。'
        return
    }
    $features = @($sync.selectedFeatures)
    if (-not $features.Count) { Write-Warning '请先选择要安装的 Windows 功能。'; return }

    # Create delegates on the UI runspace; the worker only publishes data.
    $sync.FeatureProgressValue = 0.01
    $sync.FeatureOperationError = ''
    $sync.FeatureProgressAction = [action]{
        Set-WinUtilTaskbaritem -state 'Normal' -value $sync.FeatureProgressValue -overlay 'logo'
    }
    $sync.FeatureFinishedAction = [action]{
        if ($sync.FeatureOperationError) {
            Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
            Show-WinUtilTweakDialog -Title 'Windows 功能安装未完成' -Message ("$($sync.FeatureOperationError)`n已执行的功能可能部分生效，请查看控制台日志后重试。") | Out-Null
        } else {
            Set-WinUtilTaskbaritem -state 'None' -overlay 'checkmark'
            Write-Host 'Windows 功能处理结束；部分更改可能需要重启。'
        }
    }
    # Reserve before dispatch so repeated clicks cannot queue another installation.
    $sync.ProcessRunning = $true
    try {
        $null = Invoke-WPFRunspace -ParameterList (, @('Features', $features)) -ScriptBlock {
            param([string[]]$Features)
            try {
                $sync.Form.Dispatcher.Invoke($sync.FeatureProgressAction)
                for ($index = 0; $index -lt $Features.Count; $index++) {
                    Invoke-WinUtilFeatureInstall $Features[$index]
                    $sync.FeatureProgressValue = ($index + 1) / [double]$Features.Count
                    $sync.Form.Dispatcher.Invoke($sync.FeatureProgressAction)
                }
            } catch {
                $sync.FeatureOperationError = $_.Exception.Message
                Write-Warning "Windows 功能安装未完成：$($sync.FeatureOperationError)"
            } finally {
                try { $sync.Form.Dispatcher.Invoke($sync.FeatureFinishedAction) }
                catch { Write-Warning "无法显示 Windows 功能安装结果：$($_.Exception.Message)" }
                finally { $sync.ProcessRunning = $false }
            }
        } -ErrorAction Stop
    } catch {
        $sync.FeatureOperationError = "无法启动后台任务：$($_.Exception.Message)"
        Write-Warning $sync.FeatureOperationError
        try { $sync.FeatureFinishedAction.Invoke() }
        catch { Write-Warning "无法显示 Windows 功能安装结果：$($_.Exception.Message)" }
        finally { $sync.ProcessRunning = $false }
    }
}
