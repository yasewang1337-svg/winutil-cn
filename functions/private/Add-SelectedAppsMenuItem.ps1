function Add-SelectedAppsMenuItem {
    <# .SYNOPSIS Adds one readable, keyboard-removable item to the selection popup. #>
    param([string]$name, [string]$key)
    $row = [Windows.Controls.Grid]::new()
    $row.Margin = '0,4,0,4'
    $null = $row.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $removeColumn = [Windows.Controls.ColumnDefinition]::new()
    $removeColumn.Width = 'Auto'
    $null = $row.ColumnDefinitions.Add($removeColumn)

    $label = [Windows.Controls.TextBlock]::new()
    $label.Text = $name
    $label.ToolTip = $name
    $label.Margin = '4,4,8,4'
    $label.VerticalAlignment = 'Center'
    $label.TextTrimming = 'CharacterEllipsis'
    $label.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'MainForegroundColor')
    $label.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'FontFamily')
    $null = $row.Children.Add($label)

    $remove = [Windows.Controls.Button]::new()
    $remove.Content = '移除'
    $remove.Tag = $key
    $remove.Padding = '8,5,8,5'
    $remove.ToolTip = "从已选清单移除 $name，不会卸载软件。"
    $remove.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'MainForegroundColor')
    $remove.SetResourceReference([Windows.Controls.Control]::FontFamilyProperty, 'FontFamily')
    $remove.SetResourceReference([Windows.Controls.Control]::StyleProperty, 'HoverButtonStyle')
    [Windows.Automation.AutomationProperties]::SetName($remove, "从已选清单移除 $name")
    $remove.Add_Click({
        $index = $sync.selectedAppsstackPanel.Children.IndexOf($this.Parent)
        $sync[$this.Tag].IsChecked = $false
        # The selection event rebuilds the rows; keep keyboard focus on the next row.
        $remaining = $sync.selectedAppsstackPanel.Children.Count
        if ($remaining -gt 0) {
            $nextIndex = [Math]::Min([Math]::Max(0, $index), $remaining - 1)
            $null = $sync.selectedAppsstackPanel.Children[$nextIndex].Children[1].Focus()
        } else { $null = $sync.SelectedAppsCloseButton.Focus() }
    })
    [Windows.Controls.Grid]::SetColumn($remove, 1)
    $null = $row.Children.Add($remove)
    $null = $sync.selectedAppsstackPanel.Children.Add($row)
}
