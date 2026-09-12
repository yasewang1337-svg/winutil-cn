function Invoke-WinUtilTweakToggle {
    <# .SYNOPSIS Applies an explicit on/off target, then reads back the switch state. #>
    param($Sender, [bool]$Enabled)
    if ($sync.ImportInProgress -or $sync.TweakToggleUpdating) { return }
    if ($sync.ProcessRunning) {
        $result = [pscustomobject]@{ Status = 'Skipped'; Message = '其他操作正在执行，请结束后再切换设置。' }
    } else {
        $result = Invoke-WinUtilTweaks -CheckBox $Sender.Name -ApplyDefault:(-not $Enabled)
    }
    $sync.TweakToggleUpdating = $true
    try {
        $actual = Get-WinUtilToggleStatus $Sender.Name
        $Sender.IsChecked = $actual
        $selection = 'Remove'
        if ($actual) { $selection = 'Add' }
        Invoke-WPFSelectedCheckboxesUpdate -type $selection -checkboxName $Sender.Name
    } finally { $sync.TweakToggleUpdating = $false }
    if ($result.Status -notin @('Success')) {
        if ($sync.Form) { [System.Windows.MessageBox]::Show($sync.Form, $result.Message, '设置结果', 'OK', 'Information') | Out-Null }
        else { Write-Warning $result.Message }
    }
    return $result
}
