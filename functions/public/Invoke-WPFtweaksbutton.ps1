function Invoke-WPFtweaksbutton {
    <# .SYNOPSIS Confirms and runs the selected settings with recorded results. #>
    if ($sync.ProcessRunning) { Write-Warning '其他操作正在执行，请稍后再试。'; return }
    $tweaks = @($sync.selectedTweaks)
    $dns = 'Default'
    if ($sync.WPFchangedns -and $sync.WPFchangedns.Text) { $dns = $sync.WPFchangedns.Text }
    if (-not $tweaks.Count -and $dns -eq 'Default') {
        if ($sync.Form) { [System.Windows.MessageBox]::Show($sync.Form, '请先选择要执行的设置。', '设置', 'OK', 'Information') | Out-Null }
        return
    }
    if (-not (Confirm-WinUtilTweakPlan -Tweaks $tweaks -DNSProvider $dns)) { return }
    $sync.ProcessRunning = $true
    if (-not $sync.Form) {
        Invoke-WinUtilTweakBatch -Tweaks $tweaks -DNSProvider $dns
        return
    }
    try {
        Initialize-WinUtilTweakUiCallbacks
        Invoke-WPFRunspace -ParameterList @(@('Tweaks', $tweaks), @('DNSProvider', $dns)) -ScriptBlock {
            param($Tweaks, $DNSProvider)
            Invoke-WinUtilTweakBatch -Tweaks $Tweaks -DNSProvider $DNSProvider
        } | Out-Null
    } catch {
        $sync.ProcessRunning = $false
        [System.Windows.MessageBox]::Show($sync.Form, $_.Exception.Message, '无法开始执行', 'OK', 'Error') | Out-Null
    }
}
