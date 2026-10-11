function Update-WinUtilInventoryUi {
    <# Refresh the read-only inventory summary and filter on the owning UI thread. #>
    if ($null -eq $sync) { return }
    $manager = [string]$sync.preferences.packagemanager
    if ($manager -notin @('Winget', 'Choco')) { $manager = 'Winget' }
    $label = if ($manager -eq 'Choco') { 'Chocolatey' } else { 'WinGet' }
    $offlineWinget = $PARAM_OFFLINE -and $manager -eq 'Winget'
    $inventory = $sync.SoftwareInventory
    $current = (Test-WinUtilInventoryCurrent -Inventory $inventory -Manager $manager) -and
        -not $sync.InventoryScanRunning -and -not $sync.InventoryOperationError

    if ($sync.InstallInstalledOnly) {
        $sync.InstallInstalledOnly.IsEnabled = $current
        $sync.InstallInstalledOnly.ToolTip = if ($current) {
            '仅显示本次检测在软件目录中匹配到的已装软件。未识别不代表未安装；不会改变已有勾选。'
        } else { '请先使用当前安装来源完成“检测已安装”。切换来源或执行软件操作后需要重新检测；已有勾选会保留。' }
        if (-not $current) {
            $wasUpdating = $sync.InstallFilterUpdating
            $sync.InstallFilterUpdating = $true
            try { $sync.InstallInstalledOnly.IsChecked = $false }
            finally { $sync.InstallFilterUpdating = $wasUpdating }
        }
    }
    foreach ($name in @('WingetRadioButton', 'ChocoRadioButton')) {
        if ($sync[$name]) { $sync[$name].IsEnabled = -not $sync.InventoryScanRunning }
    }
    foreach ($name in @('WPFDetectInstalled', 'WPFGetInstalled')) {
        if ($sync[$name]) {
            $sync[$name].IsEnabled = -not $sync.InventoryScanRunning -and -not $offlineWinget
            $sync[$name].ToolTip = if ($offlineWinget) {
                '离线模式无法检测 WinGet：查询可能联网同步源。联网后重新打开，或切换为本机 Chocolatey。'
            } elseif ($sync.configs.appnavigation.$name) {
                $sync.configs.appnavigation.$name.Description
            } elseif ($name -eq 'WPFDetectInstalled') {
                '检测当前来源识别到的已装软件，不改变勾选。WinGet 可能联网同步源并接受源协议。'
            } else { '检测并追加勾选已装软件，保留已有选择。WinGet 可能联网同步源并接受源协议。' }
        }
    }
    if ($sync.InstallInventoryStatus) {
        $previous = ''
        if ($inventory) {
            $source = if ($inventory.Manager -eq 'Choco') { 'Chocolatey' } else { 'WinGet' }
            $time = ([datetime]$inventory.CompletedAt).ToString('MM-dd HH:mm')
            $previous = "$source · $time 检测 · 目录匹配 $(@($inventory.MatchedKeys).Count) 项"
        }
        $status = if ($sync.InventoryScanRunning) {
            "正在检测 $label 已安装软件，请稍候…"
        } elseif ($sync.InventoryOperationError) {
            $detail = ([string]$sync.InventoryOperationError -replace '[\r\n]+', ' ').Trim()
            if ($detail.Length -gt 120) { $detail = $detail.Substring(0, 120) + '…' }
            "检测失败：$detail" + $(if ($previous) { "`n历史结果：$previous（请重新检测）" } else { '' })
        } elseif ($current) {
            "$previous · 未识别不代表未安装"
        } elseif ($previous) {
            "历史结果：$previous · $($sync.InventoryInvalidationReason)请重新检测。"
        } elseif ($offlineWinget) {
            '离线模式 · WinGet 检测可能联网同步源。联网后重新打开，或使用本机 Chocolatey。'
        } else {
            '尚未检测 · 点击“检测已安装”查看 {0} 识别到的软件，不改变勾选。' -f $label
        }
        $sync.InstallInventoryStatus.Text = $status
        $sync.InstallInventoryStatus.ToolTip = if ($sync.InventoryOperationError) { [string]$sync.InventoryOperationError } else {
            "$status`n来源匹配警告可能造成漏识别，详情可查看控制台日志。"
        }
        [Windows.Automation.AutomationProperties]::SetName($sync.InstallInventoryStatus, $status)
    }
    if ($sync.ItemsControl) {
        $query = if ($sync.SearchBar) { $sync.SearchBar.Text } else { $sync.InstallSearchText }
        Find-AppsByNameOrDescription -SearchString $query
    }
}
