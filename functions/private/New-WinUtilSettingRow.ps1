function New-WinUtilSettingRow {
    <# .SYNOPSIS Adds a readable setting row while keeping the original native control and ID. #>
    param(
        [Parameter(Mandatory)][Windows.Controls.Control]$Control,
        [Parameter(Mandatory)]$Entry,
        [string]$Kind = 'Selection',
        [Windows.UIElement]$HelpLink
    )
    $title = [string]$Entry.Content
    if ($Entry.Content -is [array]) { $title = [string]$Entry.Content[0] }
    $description = [string]$Entry.Description
    $row = [Windows.Controls.Border]::new()
    $row.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingRowBorderStyle')
    $row.Tag = [pscustomobject]@{
        WinUtilSettingRow = $true; Key = [string]$Entry.Name; Title = $title
        Description = $description; Kind = $Kind; Category = [string]$Entry.Category; Control = $Control
    }
    $row.HorizontalAlignment = 'Stretch'
    $row.UseLayoutRounding = $true
    [Windows.Automation.AutomationProperties]::SetName($row, $title)
    [Windows.Automation.AutomationProperties]::SetName($Control, $title)
    [Windows.Automation.AutomationProperties]::SetHelpText($Control, $description)

    $text = [Windows.Controls.StackPanel]::new()
    $text.IsHitTestVisible = $false
    $heading = [Windows.Controls.TextBlock]::new()
    $heading.Text = $title
    $heading.TextWrapping = 'Wrap'
    $heading.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'FontFamily')
    $heading.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'FontSize')
    $heading.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'MainForegroundColor')
    $null = $text.Children.Add($heading)
    if (-not [string]::IsNullOrWhiteSpace($description)) {
        $summary = [Windows.Controls.TextBlock]::new()
        $summary.Text = ($description -replace '\s+', ' ').Trim()
        $summary.TextTrimming = 'CharacterEllipsis'
        $summary.TextWrapping = 'NoWrap'
        $summary.Margin = '0,3,0,0'
        $summary.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'FontFamily')
        $summary.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'AppEntryDescriptionFontSize')
        $summary.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SecondaryForegroundColor')
        $null = $text.Children.Add($summary)
    }
    $grid = [Windows.Controls.Grid]::new()
    $mainColumn = [Windows.Controls.ColumnDefinition]::new()
    $mainColumn.Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add($mainColumn)
    $actionColumn = [Windows.Controls.ColumnDefinition]::new()
    $actionColumn.Width = [Windows.GridLength]::Auto
    $grid.ColumnDefinitions.Add($actionColumn)
    if ($Kind -eq 'Selection') {
        $Control.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingEntryCheckboxStyle')
        $Control.Content = $text
        $Control.HorizontalAlignment = 'Stretch'
        $Control.HorizontalContentAlignment = 'Stretch'
        $Control.Margin = '0'
        $null = $grid.Children.Add($Control)
    } elseif ($Kind -eq 'Action') {
        $Control.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingActionButtonStyle')
        $Control.Content = $text
        $Control.HorizontalAlignment = 'Stretch'
        $Control.HorizontalContentAlignment = 'Stretch'
        $Control.Height = [double]::NaN
        $Control.Width = [double]::NaN
        $Control.MinWidth = 0
        $Control.Padding = '12,9'
        $Control.Margin = '0'
        $null = $grid.Children.Add($Control)
    } elseif ($Kind -eq 'Choice') {
        $stack = [Windows.Controls.StackPanel]::new()
        $stack.Margin = '12,9'
        $null = $stack.Children.Add($text)
        $Control.HorizontalAlignment = 'Stretch'
        $Control.Width = [double]::NaN
        $Control.MinWidth = 0
        $Control.Margin = '0,7,0,0'
        $null = $stack.Children.Add($Control)
        $null = $grid.Children.Add($stack)
    } else {
        $text.Margin = '12,9,8,9'
        $null = $grid.Children.Add($text)
        $actions = [Windows.Controls.StackPanel]::new()
        $actions.Margin = '8,9,12,9'
        $actions.VerticalAlignment = 'Center'
        $Control.HorizontalAlignment = 'Right'
        $null = $actions.Children.Add($Control)
        if ($Kind -eq 'Immediate') {
            $hint = [Windows.Controls.TextBlock]::new()
            $hint.Text = '直接应用'
            $hint.HorizontalAlignment = 'Right'
            $hint.Margin = '0,3,0,0'
            $hint.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'AppEntryDescriptionFontSize')
            $hint.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SecondaryForegroundColor')
            $null = $actions.Children.Add($hint)
        }
        [Windows.Controls.Grid]::SetColumn($actions, 1)
        $null = $grid.Children.Add($actions)
    }
    if ($HelpLink) {
        $HelpLink.Margin = '6,9,10,0'
        $HelpLink.VerticalAlignment = 'Top'
        [Windows.Controls.Grid]::SetColumn($HelpLink, 1)
        $null = $grid.Children.Add($HelpLink)
    }
    $row.Child = $grid
    # The whole row owns its tooltip. Build the rich popup only when needed,
    # rather than allocating hundreds of hidden TextBlocks during startup.
    $Control.ClearValue([Windows.FrameworkElement]::ToolTipProperty)
    $row.ToolTip = if ([string]::IsNullOrWhiteSpace($description)) { $title } else { $description }
    [Windows.Controls.ToolTipService]::SetInitialShowDelay($row, 500)
    [Windows.Controls.ToolTipService]::SetBetweenShowDelay($row, 150)
    [Windows.Controls.ToolTipService]::SetShowDuration($row, 20000)
    $row.Add_ToolTipOpening({ param($sender, $eventArgs) Initialize-WinUtilSettingToolTip -Row $sender })
    $row.Add_PreviewKeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.Key -eq [Windows.Input.Key]::F1) {
            Initialize-WinUtilSettingToolTip -Row $sender
            $sender.ToolTip.PlacementTarget = $sender.Tag.Control
            $sender.ToolTip.IsOpen = $true
            $eventArgs.Handled = $true
        } elseif ($eventArgs.Key -eq [Windows.Input.Key]::Escape -and
            $sender.ToolTip -is [Windows.Controls.ToolTip] -and $sender.ToolTip.IsOpen) {
            $sender.ToolTip.IsOpen = $false
            $eventArgs.Handled = $true
        }
    })
    return $row
}
