function Update-WinUtilTweakSelectionUi {
    <# .SYNOPSIS Shows the pending selection without reading or changing system settings. #>
    if (-not $sync.Form) { return }
    $count = if ($sync.selectedTweaks) { @($sync.selectedTweaks).Count } else { 0 }
    $dnsPending = $sync.WPFchangedns -and $sync.WPFchangedns.Text -and $sync.WPFchangedns.Text -ne 'Default'
    $pendingCount = $count + [int][bool]$dnsPending
    $summary = $sync.Form.FindName('WPFSelectedTweaksSummary')
    if ($summary) {
        $summary.Text = "已选 $pendingCount 项"
    }
    if ($sync.ProcessRunning) { return }
    foreach ($name in @('WPFTweaksbutton', 'WPFUndoall')) {
        $button = $sync.Form.FindName($name)
        if (-not $button) { continue }
        $canRun = if ($name -eq 'WPFTweaksbutton') { $pendingCount -gt 0 } else { $count -gt 0 }
        $button.IsEnabled = $canRun
        [Windows.Controls.ToolTipService]::SetShowOnDisabled($button, $true)
        $button.ToolTip = if (-not $canRun) { '先勾选需要处理的设置，或选择上方方案。' }
            elseif ($name -eq 'WPFTweaksbutton') { '先查看所选改动及恢复范围，再决定是否运行。' }
            else { '查看所选项目支持的恢复操作。' }
    }
}
