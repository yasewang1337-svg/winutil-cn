function Initialize-WinUtilAppCommandBar {
    <# .SYNOPSIS Places software commands next to their list, with secondary actions in menus. #>
    param([Parameter(Mandatory)][PSCustomObject]$Configuration)

    $hostGrid = $sync.Form.FindName('appscategory')
    $hostGrid.Children.Clear()
    $hostGrid.ColumnDefinitions.Clear()
    $layout = [Windows.Controls.StackPanel]::new()
    $layout.Margin = '0,0,0,4'
    $null = $hostGrid.Children.Add($layout)

    $commands = [Windows.Controls.WrapPanel]::new()
    $null = $layout.Children.Add($commands)
    $options = [Windows.Controls.WrapPanel]::new()
    $options.Margin = '0,2,0,0'
    $null = $layout.Children.Add($options)
    $sync.InstallCommandBar = $commands
    $sync.InstallSourceBar = $options

    $primaryNames = @('WPFInstall', 'WPFUninstall', 'WPFDetectInstalled', 'WPFselectedAppsButton')
    $captions = @{
        WPFInstall = '安装 / 升级…'
        WPFUninstall = '卸载…'
        WPFDetectInstalled = '检测已安装'
        WPFselectedAppsButton = '已选应用: 0'
    }
    foreach ($name in $primaryNames) {
        if (-not $Configuration.$name) { continue }
        $button = [Windows.Controls.Button]::new()
        $button.Name = $name
        $button.Content = $captions[$name]
        $button.ToolTip = $Configuration.$name.Description
        [Windows.Controls.ToolTipService]::SetShowOnDisabled($button, $true)
        $button.SetResourceReference([Windows.Controls.Control]::StyleProperty, $(if ($name -eq 'WPFInstall') { 'PrimaryButtonStyle' } else { 'HoverButtonStyle' }))
        $button.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, 'ButtonFontSize')
        $button.Width = [double]::NaN
        $button.Height = [double]::NaN
        $button.MinHeight = 34
        $button.Padding = '12,7'
        $button.Margin = '0,0,6,4'
        [Windows.Automation.AutomationProperties]::SetName($button, [string]$button.Content)
        # scripts/main.ps1 wires Button clicks once after all panels exist.
        $sync[$name] = $button
        $null = $commands.Children.Add($button)
    }

    foreach ($group in @('Bundles', 'More')) {
        $menu = [Windows.Controls.Menu]::new()
        $menu.Background = 'Transparent'
        $menu.VerticalAlignment = 'Center'
        $menu.Margin = '0,0,6,4'
        $menu.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'MainForegroundColor')
        $menu.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, 'ButtonFontSize')
        $heading = [Windows.Controls.MenuItem]::new()
        $heading.Header = $(if ($group -eq 'Bundles') { '组合推荐' } else { '更多操作' })
        $heading.Padding = '10,8'
        $heading.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'PanelBackgroundColor')
        $heading.ToolTip = $(if ($group -eq 'Bundles') { '预览常用软件组合，按需加入清单。' } else { '升级全部、查看结果、勾选已装软件及整理选择。' })
        $null = $menu.Items.Add($heading)
        $null = $commands.Children.Add($menu)
        $sync["Install${group}Menu"] = $heading
        $sync["Install${group}MenuHost"] = $menu
        $entries = $Configuration.PSObject.Properties | Where-Object {
            $_.Value.Type -eq 'Button' -and $_.Name -notin $primaryNames -and
            (($_.Name -like 'WPFBundle*') -eq ($group -eq 'Bundles'))
        } | Sort-Object @{ Expression = { $_.Value.Category } }, @{ Expression = { [int]$_.Value.Order } }
        foreach ($entry in $entries) {
            $item = [Windows.Controls.MenuItem]::new()
            $item.Name = $entry.Name
            $item.Header = $entry.Value.Content
            $item.ToolTip = $entry.Value.Description
            [Windows.Controls.ToolTipService]::SetShowOnDisabled($item, $true)
            $item.Padding = '12,7'
            $item.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'MainForegroundColor')
            $item.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'PanelBackgroundColor')
            $item.Add_Click({
                param($sender, $eventArgs)
                $eventArgs.Handled = $true
                Invoke-WPFButton -Button $sender.Name
            })
            $sync[$entry.Name] = $item
            $null = $heading.Items.Add($item)
        }
    }

    $sourceLabel = [Windows.Controls.TextBlock]::new()
    $sourceLabel.Text = '来源'
    $sourceLabel.Margin = '0,4,12,4'
    $sourceLabel.VerticalAlignment = 'Center'
    $sourceLabel.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SecondaryForegroundColor')
    $sourceLabel.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'ButtonFontSize')
    $null = $options.Children.Add($sourceLabel)
    foreach ($entry in $Configuration.PSObject.Properties | Where-Object { $_.Value.Type -eq 'RadioButton' } | Sort-Object { [int]$_.Value.Order }) {
        $radio = [Windows.Controls.RadioButton]::new()
        $radio.Name = $entry.Name
        $radio.Content = $entry.Value.Content
        $radio.GroupName = $entry.Value.GroupName
        $radio.ToolTip = $entry.Value.Description
        $radio.Margin = '0,4,16,4'
        $radio.VerticalAlignment = 'Center'
        $radio.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'MainForegroundColor')
        $radio.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, 'ButtonFontSize')
        $radio.IsChecked = [bool]$entry.Value.Checked
        $sync[$entry.Name] = $radio
        $null = $options.Children.Add($radio)
    }

    if ($Configuration.WPFToggleFOSSHighlight) {
        $foss = [Windows.Controls.CheckBox]::new()
        $foss.Name = 'WPFToggleFOSSHighlight'
        $foss.Content = '标出开源软件'
        $foss.ToolTip = $Configuration.WPFToggleFOSSHighlight.Description
        $foss.Margin = '6,4,0,4'
        $foss.VerticalAlignment = 'Center'
        $foss.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'MainForegroundColor')
        $foss.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, 'ButtonFontSize')
        $foss.IsChecked = [bool]$Configuration.WPFToggleFOSSHighlight.Checked
        $foss.Add_Checked({ Invoke-WPFButton -Button 'WPFToggleFOSSHighlight' })
        $foss.Add_Unchecked({ Invoke-WPFButton -Button 'WPFToggleFOSSHighlight' })
        $sync.WPFToggleFOSSHighlight = $foss
        $null = $options.Children.Add($foss)
    }

    $inventoryStatus = [Windows.Controls.TextBlock]::new()
    $inventoryStatus.Margin = '12,4,0,4'
    $inventoryStatus.VerticalAlignment = 'Center'
    $inventoryStatus.TextWrapping = 'Wrap'
    $inventoryStatus.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SecondaryForegroundColor')
    $inventoryStatus.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'ButtonFontSize')
    $inventoryStatus.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'FontFamily')
    $sync.InstallInventoryStatus = $inventoryStatus
    $null = $options.Children.Add($inventoryStatus)
    $sync.InstallBundlesMenuSeparator = [Windows.Controls.Separator]::new()
    # Local size events cover window, font and selection-caption changes.
    # LayoutUpdated is global across WPF windows and must not be used here.
    $layoutChanged = {
        param($sender, $eventArgs)
        if ($sender -eq $sync.InstallCommandBar -or $sender.Parent -eq $sync.InstallCommandBar) {
            Set-WinUtilAppCommandBarLayout
        }
    }
    $commands.Add_SizeChanged($layoutChanged)
    foreach ($child in $commands.Children) { $child.Add_SizeChanged($layoutChanged) }
    Update-WinUtilInventoryUi
}

function Set-WinUtilAppCommandBarLayout {
    <# .SYNOPSIS Keeps primary commands on one row by moving bundles into More when necessary. #>
    $commands = $sync.InstallCommandBar
    $bundles = $sync.InstallBundlesMenu
    $hostMenu = $sync.InstallBundlesMenuHost
    $more = $sync.InstallMoreMenu
    if (-not $commands -or -not $bundles -or -not $hostMenu -or -not $more -or
        $commands.ActualWidth -le 0 -or $sync.InstallCommandLayoutUpdating) { return }
    $fontSize = [double]$commands.Children[0].FontSize
    if ($hostMenu.Visibility -ne 'Collapsed' -and $hostMenu.DesiredSize.Width -gt 0) {
        $sync.InstallBundlesMenuMeasuredWidth = $hostMenu.DesiredSize.Width
        $sync.InstallBundlesMenuMeasuredFontSize = $fontSize
    }
    if (-not $sync.InstallBundlesMenuMeasuredWidth) { return }
    $bundleWidth = $sync.InstallBundlesMenuMeasuredWidth * $fontSize / $sync.InstallBundlesMenuMeasuredFontSize
    $requiredWidth = $bundleWidth
    foreach ($child in $commands.Children) {
        if ($child -ne $hostMenu) { $requiredWidth += $child.DesiredSize.Width }
    }
    $compact = $requiredWidth -gt ($commands.ActualWidth - 2)
    if ($compact -eq ($hostMenu.Visibility -eq 'Collapsed')) { return }
    $sync.InstallCommandLayoutUpdating = $true
    try {
        $bundles.IsSubmenuOpen = $false
        if ($compact) {
            $hostMenu.Items.Remove($bundles)
            $more.Items.Insert(0, $bundles)
            $more.Items.Insert(1, $sync.InstallBundlesMenuSeparator)
            $hostMenu.Visibility = 'Collapsed'
        } else {
            $more.Items.Remove($bundles)
            $more.Items.Remove($sync.InstallBundlesMenuSeparator)
            $null = $hostMenu.Items.Add($bundles)
            $hostMenu.Visibility = 'Visible'
        }
    } finally { $sync.InstallCommandLayoutUpdating = $false }
}
