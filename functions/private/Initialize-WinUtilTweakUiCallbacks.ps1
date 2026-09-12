function Initialize-WinUtilTweakUiCallbacks {
    <# .SYNOPSIS Creates UI delegates on the UI runspace, preventing cross-runspace callback deadlocks. #>
    $sync.TweakProgressAction = [action] {
        if ($sync.progressBarTextBlock) {
            $sync.progressBarTextBlock.Text = $sync.TweakProgressLabel
            $sync.progressBarTextBlock.ToolTip = $sync.TweakProgressLabel
        }
        if ($sync.ProgressBar) { $sync.ProgressBar.Value = [Math]::Max(5, $sync.TweakProgressPercent) }
    }
    $sync.TweakResultsAction = [action[object]] {
        param($ResultSnapshot)
        if ($sync.Form.TaskbarItemInfo) { Set-WinUtilTaskbaritem -state 'None' }
        Invoke-WPFTweakHistory -ShowLastResults -Results @($ResultSnapshot)
    }
}
