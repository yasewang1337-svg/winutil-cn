function Invoke-WPFGetInstalled {
    <# Reads installed software or current tweaks without leaving a failed scan busy. #>
    param([ValidateSet('winget', 'tweaks')][string]$checkbox)
    if ($sync.ProcessRunning) {
        Write-Warning '当前有任务正在运行，请等待结束后再扫描。'
        return
    }
    $managerPreference = [string]$sync.preferences.packagemanager
    if ($managerPreference -notin @('Winget', 'Choco')) { $managerPreference = 'Winget' }
    if ($checkbox -eq 'winget' -and $managerPreference -eq 'Winget' -and
        (Test-WinUtilPackageManager -winget) -eq 'not-installed') { return }

    $sync.InventoryOperationError = ''
    $sync.InstalledCheckboxes = @()
    # These delegates belong to the UI runspace, not the worker runspace.
    $sync.InventoryStartAction = [action]{ Set-WinUtilTaskbaritem -state 'Indeterminate' }
    $sync.InventoryApplyAction = [action]{
        foreach ($name in $sync.InstalledCheckboxes) {
            if ($null -ne $sync[$name]) { $sync[$name].IsChecked = $true }
        }
    }
    $sync.InventoryFinishedAction = [action]{
        if ($sync.InventoryOperationError) {
            Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
            Show-WinUtilTweakDialog -Title '扫描未完成' -Message ("$($sync.InventoryOperationError)`n请检查软件包管理器和控制台日志后重试。") | Out-Null
        } else { Set-WinUtilTaskbaritem -state 'None' }
    }
    $sync.ProcessRunning = $true
    try {
        $null = Invoke-WPFRunspace -ParameterList @(@('managerPreference', $managerPreference), @('checkbox', $checkbox)) -ScriptBlock {
            param([string]$checkbox, [string]$managerPreference)
            try {
                $sync.Form.Dispatcher.Invoke($sync.InventoryStartAction)
                $source = $checkbox
                if ($checkbox -eq 'winget' -and $managerPreference -eq 'Choco') { $source = 'choco' }
                $sync.InstalledCheckboxes = @(Invoke-WinUtilCurrentSystem -CheckBox $source)
                $sync.Form.Dispatcher.Invoke($sync.InventoryApplyAction)
                Write-Host '扫描完成。'
            } catch {
                $sync.InventoryOperationError = $_.Exception.Message
                Write-Warning "扫描未完成：$($sync.InventoryOperationError)"
            } finally {
                try { $sync.Form.Dispatcher.Invoke($sync.InventoryFinishedAction) }
                catch { Write-Warning "无法显示扫描结果：$($_.Exception.Message)" }
                finally { $sync.ProcessRunning = $false }
            }
        } -ErrorAction Stop
    } catch {
        $sync.InventoryOperationError = "无法启动后台任务：$($_.Exception.Message)"
        Write-Warning $sync.InventoryOperationError
        try { $sync.InventoryFinishedAction.Invoke() }
        catch { Write-Warning "无法显示扫描结果：$($_.Exception.Message)" }
        finally { $sync.ProcessRunning = $false }
    }
}
