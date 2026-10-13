function Invoke-WinUtilKeyboardShortcut {
    <# .SYNOPSIS Handles navigation and search shortcuts without changing selections. #>
    param([Parameter(Mandatory)]$EventArgs)

    if ($EventArgs.Handled -or $sync.ProcessRunning) { return }
    $modifiers = $EventArgs.KeyboardDevice.Modifiers
    if ($modifiers -eq [Windows.Input.ModifierKeys]::Control) {
        switch ($EventArgs.Key) {
            'F' {
                if ($sync.currentTab -notin @('WPFTab1', 'WPFTab2')) {
                    Invoke-WPFTab 'WPFTab1BT'
                }
                if ($sync.currentTab -in @('WPFTab1', 'WPFTab2') -and
                    $sync.SearchBar -and $sync.SearchBar.IsEnabled -and
                    $sync.SearchBar.Visibility -eq 'Visible') {
                    $null = $sync.SearchBar.Focus()
                    $sync.SearchBar.SelectAll()
                    $EventArgs.Handled = $true
                }
            }
            'Q' { $sync.Form.Close(); $EventArgs.Handled = $true }
        }
        return
    }
    if ($modifiers -eq [Windows.Input.ModifierKeys]::Alt) {
        $target = switch ($EventArgs.SystemKey) {
            'I' { 'WPFTab1BT' }
            'T' { 'WPFTab2BT' }
            'C' { 'WPFTab3BT' }
            'U' { 'WPFTab4BT' }
            'W' { 'WPFTab5BT' }
        }
        if ($target) {
            Invoke-WPFButton $target
            $EventArgs.Handled = $true
        }
        return
    }
    # The key's original source is the focused input. Escape in other controls
    # or popups must stay local and must not alter a hidden search behind them.
    if ($modifiers -eq [Windows.Input.ModifierKeys]::None -and
        $EventArgs.Key -eq [Windows.Input.Key]::Escape -and
        $sync.SearchBar -and $EventArgs.OriginalSource -eq $sync.SearchBar -and
        $sync.SearchBar.Text.Length -gt 0) {
        $sync.SearchBar.Clear()
        $EventArgs.Handled = $true
    }
}
