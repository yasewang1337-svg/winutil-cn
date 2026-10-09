function Initialize-WinUtilAppCommandBar {
    <# .SYNOPSIS Places software commands next to their list, with secondary actions in menus. #>
    param([Parameter(Mandatory)][PSCustomObject]$Configuration)

    $hostGrid = $sync.Form.FindName('appscategory')
    $hostGrid.Children.Clear()
    $hostGrid.ColumnDefinitions.Clear()
    $layout = [Windows.Controls.StackPanel]::new()
    $layout.Margin = '0,0,0,8'
    $null = $hostGrid.Children.Add($layout)

    $commands = [Windows.Controls.WrapPanel]::new()
    $null = $layout.Children.Add($commands)
    $options = [Windows.Controls.WrapPanel]::new()
    $options.Margin = '0,6,0,0'
    $null = $layout.Children.Add($options)
    $sync.InstallCommandBar = $commands
    $sync.InstallSourceBar = $options

    $primaryNames = @('WPFInstall', 'WPFUninstall', 'WPFselectedAppsButton')
    $captions = @{
        WPFInstall = '安装 / 升级…'
        WPFUninstall = '卸载…'
        WPFselectedAppsButton = '已选应用: 0'
    }
    foreach ($name in $primaryNames) {
        if (-not $Configuration.$name) { continue }
        $button = [Windows.Controls.Button]::new()
        $button.Name = $name
        $button.Content = $captions[$name]
        $button.ToolTip = $Configuration.$name.Description
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
        $entries = $Configuration.PSObject.Properties | Where-Object {
            $_.Value.Type -eq 'Button' -and $_.Name -notin $primaryNames -and
            (($_.Name -like 'WPFBundle*') -eq ($group -eq 'Bundles'))
        } | Sort-Object @{ Expression = { $_.Value.Category } }, @{ Expression = { [int]$_.Value.Order } }
        foreach ($entry in $entries) {
            $item = [Windows.Controls.MenuItem]::new()
            $item.Name = $entry.Name
            $item.Header = $entry.Value.Content
            $item.ToolTip = $entry.Value.Description
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
    $sourceLabel.Text = '安装来源'
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
}
