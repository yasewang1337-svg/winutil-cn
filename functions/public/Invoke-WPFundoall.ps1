function Invoke-WPFundoall {
    <# .SYNOPSIS Restores selected settings from real recorded snapshots. #>
    if ($sync.ProcessRunning) { Write-Warning '其他操作正在执行，请稍后再试。'; return }
    $tweaks = @($sync.selectedTweaks)
    if (-not $tweaks.Count) {
        if ($sync.Form) { [System.Windows.MessageBox]::Show($sync.Form, '请先勾选需要恢复的设置。', '恢复记录', 'OK', 'Information') | Out-Null }
        return
    }
    if (-not (Confirm-WinUtilTweakPlan -Tweaks $tweaks -Undo)) { return }
    $sync.ProcessRunning = $true
    if (-not $sync.Form) { Invoke-WinUtilTweakBatch -Tweaks $tweaks -Undo; return }
    try {
        Initialize-WinUtilTweakUiCallbacks
        Invoke-WPFRunspace -ParameterList @(, @('Tweaks', $tweaks)) -ScriptBlock {
            param($Tweaks)
            Invoke-WinUtilTweakBatch -Tweaks $Tweaks -Undo
        } | Out-Null
    } catch {
        $sync.ProcessRunning = $false
        [System.Windows.MessageBox]::Show($sync.Form, $_.Exception.Message, '无法开始恢复', 'OK', 'Error') | Out-Null
    }
}
