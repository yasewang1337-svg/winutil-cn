function Reset-WinUtilAppFilter {
    <# .SYNOPSIS Clears the software filters while preserving all selected software. #>
    if ($null -eq $sync) { return }
    $sync.InstallFilterUpdating = $true
    try {
        if ($sync.InstallSelectedOnly) { $sync.InstallSelectedOnly.IsChecked = $false }
        if ($sync.SearchBar) { $sync.SearchBar.Text = '' }
    } finally { $sync.InstallFilterUpdating = $false }
    Find-AppsByNameOrDescription -SearchString ''
    if ($sync.SearchBar) { $null = $sync.SearchBar.Focus() }
}