function Update-WinUtilAppSelectionUi {
    <# .SYNOPSIS Refreshes the selection summary, popup and active filters together. #>
    if ($null -eq $sync) { return }
    $count = @($sync.selectedApps).Count
    if ($sync.WPFselectedAppsButton) { $sync.WPFselectedAppsButton.Content = "已选应用: $count" }
    if ($sync.selectedAppsstackPanel) {
        $sync.selectedAppsstackPanel.Children.Clear()
        foreach ($key in @($sync.selectedApps | Sort-Object { $sync.configs.applicationsHashtable[$_].Content })) {
            Add-SelectedAppsMenuItem -name ([string]$sync.configs.applicationsHashtable[$key].Content) -key $key
        }
    }
    if ($sync.SelectedAppsEmptyText) {
        $sync.SelectedAppsEmptyText.Visibility = if ($count -eq 0) { 'Visible' } else { 'Collapsed' }
    }
    if ($sync.ItemsControl) {
        $query = if ($sync.SearchBar) { $sync.SearchBar.Text } else { $sync.InstallSearchText }
        Find-AppsByNameOrDescription -SearchString $query
    }
}