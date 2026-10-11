function Invoke-WPFGetInstalled {
    <# Reads installed software without changing selection unless explicitly requested. #>
    param(
        [ValidateSet('winget', 'tweaks')][string]$checkbox,
        [switch]$SelectDetected
    )
    if ($sync.ProcessRunning) {
        Write-Warning '当前有任务正在运行，请等待结束后再检测。'
        return
    }
    $managerPreference = [string]$sync.preferences.packagemanager
    if ($managerPreference -notin @('Winget', 'Choco')) { $managerPreference = 'Winget' }
    if ($checkbox -eq 'winget' -and $managerPreference -eq 'Winget' -and $PARAM_OFFLINE) {
        Write-Warning '离线模式无法检测 WinGet。联网后重新打开，或切换为本机 Chocolatey。'
        Update-WinUtilInventoryUi
        return
    }
    $sync.InventoryTaskError = ''
    if ($checkbox -eq 'winget') {
        $sync.InventoryOperationError = ''
        $sync.InventoryDiagnostics = $null
    }
    $sync.InstalledCheckboxes = @()
    $sync.InventoryScanManager = $managerPreference
    $sync.InventoryScanKind = $checkbox
    $sync.InventorySelectDetected = $SelectDetected.IsPresent -or $checkbox -eq 'tweaks'
    $sync.InventoryScanRunning = $checkbox -eq 'winget'
    # These delegates belong to the UI runspace, never the worker runspace.
    $sync.InventoryStartAction = [action]{
        Set-WinUtilTaskbaritem -state 'Indeterminate'
        if ($sync.InventoryScanKind -eq 'winget') { Update-WinUtilInventoryUi }
    }
    $sync.InventoryApplyAction = [action]{
        if ($sync.InventoryScanKind -eq 'winget') {
            $currentManager = [string]$sync.preferences.packagemanager
            if ($currentManager -notin @('Winget', 'Choco')) { $currentManager = 'Winget' }
            if ($currentManager -ne $sync.InventoryScanManager) {
                Invalidate-WinUtilInventory -Reason '检测期间已切换安装来源，'
                return
            }
            $sync.InventoryInvalidationReason = ''
        }
        if ($sync.InventorySelectDetected) {
            foreach ($name in $sync.InstalledCheckboxes) {
                if ($null -ne $sync[$name]) { $sync[$name].IsChecked = $true }
            }
        }
    }
    $sync.InventoryFinishedAction = [action]{
        $sync.InventoryScanRunning = $false
        try {
            if ($sync.InventoryTaskError) {
                if ($sync.InventoryScanKind -eq 'winget' -and $sync.SoftwareInventory) {
                    $sync.SoftwareInventory | Add-Member -MemberType NoteProperty -Name IsStale -Value $true -Force
                }
                Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
                Show-WinUtilTweakDialog -Title '检测未完成' -Message ("$($sync.InventoryTaskError)`n已有选择和上次结果已保留。请检查包管理器和控制台日志后重试。") | Out-Null
            } else { Set-WinUtilTaskbaritem -state 'None' }
        } finally {
            if ($sync.InventoryScanKind -eq 'winget') { Update-WinUtilInventoryUi }
        }
    }
    $sync.ProcessRunning = $true
    try {
        # Reserve state and refresh controls immediately, before the worker is scheduled.
        if ($checkbox -eq 'winget') { Update-WinUtilInventoryUi }
        $null = Invoke-WPFRunspace -ParameterList @(@('managerPreference', $managerPreference), @('checkbox', $checkbox)) -ScriptBlock {
            param([string]$checkbox, [string]$managerPreference)
            try {
                $sync.Form.Dispatcher.Invoke($sync.InventoryStartAction)
                $source = $checkbox
                if ($checkbox -eq 'winget' -and $managerPreference -eq 'Choco') { $source = 'choco' }
                $sync.InstalledCheckboxes = @(Invoke-WinUtilCurrentSystem -CheckBox $source)
                if ($checkbox -eq 'winget') {
                    $sync.InventoryDiagnostics = $sync.SoftwareInventory.Diagnostics
                    foreach ($query in @($sync.InventoryDiagnostics)) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$query.StandardOutput)) { Write-Host ([string]$query.StandardOutput) }
                        if (-not [string]::IsNullOrWhiteSpace([string]$query.StandardError)) { Write-Warning ([string]$query.StandardError) }
                    }
                }
                $sync.Form.Dispatcher.Invoke($sync.InventoryApplyAction)
                Write-Host '检测完成。'
            } catch {
                $sync.InventoryTaskError = $_.Exception.Message
                if ($checkbox -eq 'winget') {
                    $sync.InventoryOperationError = $sync.InventoryTaskError
                    $sync.InventoryDiagnostics = $_.Exception.Data['InventoryDiagnostics']
                }
                Write-Warning "检测未完成：$($sync.InventoryTaskError)"
                if ($checkbox -eq 'winget' -and $sync.InventoryDiagnostics) {
                    foreach ($detail in @($sync.InventoryDiagnostics.StandardError, $sync.InventoryDiagnostics.StandardOutput)) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$detail)) { Write-Warning ([string]$detail) }
                    }
                }
            } finally {
                if ($checkbox -eq 'winget' -and $sync.InventoryOperationError -and $sync.SoftwareInventory) {
                    $sync.SoftwareInventory | Add-Member -MemberType NoteProperty -Name IsStale -Value $true -Force
                }
                try { $sync.Form.Dispatcher.Invoke($sync.InventoryFinishedAction) }
                catch { Write-Warning "无法显示检测结果：$($_.Exception.Message)" }
                finally { $sync.InventoryScanRunning = $false; $sync.ProcessRunning = $false }
            }
        } -ErrorAction Stop
    } catch {
        $sync.InventoryTaskError = "无法启动后台任务：$($_.Exception.Message)"
        if ($checkbox -eq 'winget') { $sync.InventoryOperationError = $sync.InventoryTaskError }
        Write-Warning $sync.InventoryTaskError
        try { $sync.InventoryFinishedAction.Invoke() }
        catch { Write-Warning "无法显示检测结果：$($_.Exception.Message)" }
        finally { $sync.InventoryScanRunning = $false; $sync.ProcessRunning = $false }
    }
}
