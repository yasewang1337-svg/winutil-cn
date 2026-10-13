function Initialize-InstallAppEntry {
    <#
        .SYNOPSIS
            Creates the app entry to be placed on the install tab for a given app
            Used to as part of the Install Tab UI generation
        .PARAMETER TargetElement
            The Element into which the Apps should be placed
        .PARAMETER appKey
            The Key of the app inside the $sync.configs.applicationsHashtable
    #>
        param(
            [Windows.Controls.WrapPanel]$TargetElement,
            $appKey
        )

        # Create the outer Border for the application type
        $border = New-Object Windows.Controls.Border
        $border.Tag = $appKey

        $description = [string]$Apps.$appKey.description
        if ([string]::IsNullOrWhiteSpace($description)) {
            $description = '暂无详细介绍。安装前请先通过软件官方资料了解其用途。'
        }

        # Keep the full description available immediately, but build the rich
        # tooltip only for rows that the user actually inspects.
        $border.Resources['WinUtilAppDefinition'] = $Apps.$appKey
        $border.ToolTip = $description
        [Windows.Controls.ToolTipService]::SetInitialShowDelay($border, 450)
        [Windows.Controls.ToolTipService]::SetBetweenShowDelay($border, 120)
        [Windows.Controls.ToolTipService]::SetShowDuration($border, 24000)
        $border.Add_ToolTipOpening({
            param($sender, $eventArgs)
            if ($eventArgs.OriginalSource -is [Windows.Controls.Button]) { return }
            Update-WinUtilAppToolTip -Border $sender
        })
        $border.Add_MouseLeftButtonUp({
            $childCheckbox = $this.Child
            $childCheckBox.isChecked = -not $childCheckbox.IsChecked
        })
        $border.Add_MouseRightButtonUp({
            param($sender, $eventArgs)
            Show-WinUtilAppActions -AppKey $sender.Tag -PlacementTarget $sender
            $eventArgs.Handled = $true
        })

        $checkBox = New-Object Windows.Controls.CheckBox
        # Sanitize the name for WPF
        $checkBox.Name = $appKey -replace '-', '_'
        # Store the original appKey in Tag
        $checkBox.Tag = $appKey
        $checkbox.Style = $sync.Form.Resources.AppEntryCheckboxStyle
        # Restore an imported selection before wiring events, so lazy page construction does not refresh once per row.
        $checkBox.IsChecked = @($sync.selectedApps) -contains $appKey
        $checkBox.Add_PreviewKeyDown({
            param($sender, $eventArgs)
            if ($eventArgs.Key -eq [Windows.Input.Key]::Apps -or
                ($eventArgs.Key -eq [Windows.Input.Key]::F10 -and
                 ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Shift))) {
                Show-WinUtilAppActions -AppKey $sender.Tag -PlacementTarget $sender -Keyboard
                $eventArgs.Handled = $true
            }
        })
        $checkbox.Add_Checked({
            Invoke-WPFSelectedCheckboxesUpdate -type "Add" -checkboxName $this.Parent.Tag
        })

        $checkbox.Add_Unchecked({
            Invoke-WPFSelectedCheckboxesUpdate -type "Remove" -checkboxName $this.Parent.Tag
        })

        # Keep names readable while showing a compact purpose on every row.
        # The complete text remains available from the row tooltip and UIA.
        $appText = [Windows.Controls.Grid]::new()
        $appText.HorizontalAlignment = 'Stretch'
        $null = $appText.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
        $actionsColumn = [Windows.Controls.ColumnDefinition]::new()
        $actionsColumn.Width = 'Auto'
        $null = $appText.ColumnDefinitions.Add($actionsColumn)
        foreach ($index in 1..2) {
            $row = [Windows.Controls.RowDefinition]::new()
            $row.Height = 'Auto'
            $null = $appText.RowDefinitions.Add($row)
        }
        $appName = New-Object Windows.Controls.TextBlock
        $appName.Style = $sync.Form.Resources.AppEntryNameStyle
        $appName.Text = $Apps.$appKey.content

        # Change color to Green if FOSS
        if ($Apps.$appKey.foss -eq $true) {
            $appName.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, "FOSSColor")
        }

        $appDescription = [Windows.Controls.TextBlock]::new()
        $appDescription.Text = ($description -replace '\s+', ' ').Trim()
        $appDescription.TextWrapping = 'NoWrap'
        $appDescription.TextTrimming = 'CharacterEllipsis'
        $appDescription.Margin = '0,2,0,0'
        $appDescription.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SecondaryForegroundColor')
        $appDescription.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'FontFamily')
        $appDescription.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'AppEntryDescriptionFontSize')
        [Windows.Controls.Grid]::SetRow($appDescription, 1)
        $null = $appText.Children.Add($appName)
        $null = $appText.Children.Add($appDescription)
        $actions = [Windows.Controls.Button]::new()
        $actions.Content = [char]0x22EF
        $actions.Tag = $appKey
        $actions.IsTabStop = $false
        $actions.Width = 32
        $actions.MinHeight = 30
        $actions.Padding = '5,2'
        $actions.Margin = '10,0,0,0'
        $actions.VerticalAlignment = 'Center'
        $actions.SetResourceReference([Windows.Controls.Control]::StyleProperty, 'HoverButtonStyle')
        $actions.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, 'ButtonFontSize')
        $actions.ToolTip = '此软件的安装、卸载与官网。'
        [Windows.Automation.AutomationProperties]::SetName($actions, "$($Apps.$appKey.content)的操作")
        $actions.Add_Click({
            param($sender, $eventArgs)
            $eventArgs.Handled = $true
            Show-WinUtilAppActions -AppKey $sender.Tag -PlacementTarget $sender
        })
        [Windows.Controls.Grid]::SetColumn($actions, 1)
        [Windows.Controls.Grid]::SetRowSpan($actions, 2)
        $null = $appText.Children.Add($actions)
        $checkBox.Content = $appText

        # Add accessibility properties to make the elements screen reader friendly
        $checkBox.SetValue([Windows.Automation.AutomationProperties]::NameProperty, $Apps.$appKey.content)
        $checkBox.SetValue([Windows.Automation.AutomationProperties]::HelpTextProperty, $description)
        $border.SetValue([Windows.Automation.AutomationProperties]::NameProperty, $Apps.$appKey.content)

        $border.Child = $checkBox
        # Decorator.Child is a CLR property; attach the child before the style's
        # Child.IsChecked binding is created so selection changes are observed.
        $border.Style = $sync.Form.Resources.AppEntryBorderStyle
        # Add the border to the corresponding Category
        $TargetElement.Children.Add($border) | Out-Null
        return $checkbox
    }

function Update-WinUtilAppToolTip {
    <# .SYNOPSIS Creates detailed help on demand and refreshes its current selection and inventory context. #>
    param([Parameter(Mandatory)][Windows.Controls.Border]$Border)
    $app = $Border.Resources['WinUtilAppDefinition']
    if (-not $app) { return }
    $description = [string]$app.description
    if ([string]::IsNullOrWhiteSpace($description)) { $description = '暂无详细介绍。安装前请先通过软件官方资料了解其用途。' }
    if ($Border.ToolTip -isnot [Windows.Controls.ToolTip]) {
        $tip = [Windows.Controls.ToolTip]::new()
        $null = $tip.Resources.MergedDictionaries.Add($sync.Form.Resources)
        $tip.Padding = '16'
        $tip.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'ToolTipBackgroundColor')
        $tip.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'MainForegroundColor')
        $tip.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BorderColor')
        $tip.SetResourceReference([Windows.Controls.Control]::FontFamilyProperty, 'FontFamily')
        $tip.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, 'FontSize')
        $tip.SetResourceReference([Windows.FrameworkElement]::MaxWidthProperty, 'ToolTipWidth')
        $details = [Windows.Controls.StackPanel]::new()
        $title = [Windows.Controls.TextBlock]::new()
        $title.Text = [string]$app.content
        $title.TextWrapping = 'Wrap'
        $title.FontWeight = 'SemiBold'
        $title.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'HeaderFontSize')
        $null = $details.Children.Add($title)
        $summary = [Windows.Controls.TextBlock]::new()
        $summary.Text = $description
        $summary.TextWrapping = 'Wrap'
        $summary.Margin = '0,8,0,0'
        $null = $details.Children.Add($summary)
        $packages = [Windows.Controls.TextBlock]::new()
        $packageIds = @()
        foreach ($manager in @('winget', 'choco')) {
            $id = [string]$app.$manager
            if (-not [string]::IsNullOrWhiteSpace($id) -and $id -ne 'na') { $packageIds += "$($manager): $id" }
        }
        $packages.Text = $packageIds -join "`n"
        $packages.TextWrapping = 'Wrap'
        $packages.Margin = '0,10,0,0'
        $packages.Visibility = if ($packageIds.Count) { 'Visible' } else { 'Collapsed' }
        $packages.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SecondaryForegroundColor')
        $null = $details.Children.Add($packages)
        $context = [Windows.Controls.TextBlock]::new()
        $context.Margin = '0,12,0,0'
        $context.TextWrapping = 'Wrap'
        $context.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SecondaryForegroundColor')
        $null = $details.Children.Add($context)
        $tip.Content = $details
        $Border.ToolTip = $tip
    }
    $selection = if ($Border.Child.IsChecked) { '已加入清单' } else { '单击可加入清单' }
    $inventory = if ($Border.Resources['WinUtilAppDetected']) { ' · 本次检测已识别安装' } else { '' }
    $Border.ToolTip.Content.Children[3].Text = "$selection$inventory`n右侧 ··· 或右键：查看此软件的操作"
}
