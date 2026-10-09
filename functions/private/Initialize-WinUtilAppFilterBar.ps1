function Initialize-WinUtilAppFilterBar {
    <# .SYNOPSIS Creates the compact software filter controls using the current theme. #>
    $toolbar = [Windows.Controls.WrapPanel]::new()
    $toolbar.Margin = '8,6,8,8'
    $toolbar.HorizontalAlignment = 'Stretch'
    $status = [Windows.Controls.TextBlock]::new()
    $status.Margin = '0,4,18,4'
    $status.VerticalAlignment = 'Center'
    $status.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'MainForegroundColor')
    $status.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'FontFamily')
    $status.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'ButtonFontSize')
    $sync.InstallFilterStatus = $status
    $null = $toolbar.Children.Add($status)
    $onlySelected = [Windows.Controls.CheckBox]::new()
    $onlySelected.Content = '仅看已选'
    $onlySelected.Margin = '0,5,16,5'
    $onlySelected.VerticalAlignment = 'Center'
    $onlySelected.ToolTip = '只显示已勾选的软件，可与搜索关键词一起使用。不会修改勾选。'
    $onlySelected.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'MainForegroundColor')
    $onlySelected.SetResourceReference([Windows.Controls.Control]::FontFamilyProperty, 'FontFamily')
    $onlySelected.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, 'ButtonFontSize')
    [Windows.Automation.AutomationProperties]::SetName($onlySelected, '仅看已选软件')
    $filterChanged = {
        if (-not $sync.InstallFilterUpdating) {
            $query = if ($sync.SearchBar) { $sync.SearchBar.Text } else { $sync.InstallSearchText }
            Find-AppsByNameOrDescription -SearchString $query
        }
    }
    $onlySelected.Add_Checked($filterChanged)
    $onlySelected.Add_Unchecked($filterChanged)
    $sync.InstallSelectedOnly = $onlySelected
    $null = $toolbar.Children.Add($onlySelected)
    $clear = [Windows.Controls.Button]::new()
    $clear.Content = '清除筛选'
    $clear.ToolTip = '清空搜索并关闭“仅看已选”，保留已有勾选。'
    $clear.Padding = '8,3,8,3'
    $clear.Margin = '0,1,0,1'
    $clear.SetResourceReference([Windows.Controls.Control]::StyleProperty, 'HoverButtonStyle')
    $clear.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'MainForegroundColor')
    $clear.SetResourceReference([Windows.Controls.Control]::FontFamilyProperty, 'FontFamily')
    $clear.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, 'ButtonFontSize')
    $clear.Add_Click({ Reset-WinUtilAppFilter })
    $sync.InstallClearFilter = $clear
    $null = $toolbar.Children.Add($clear)
    return $toolbar
}