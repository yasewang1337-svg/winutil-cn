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
        $border.Style = $sync.Form.Resources.AppEntryBorderStyle
        $border.Tag = $appKey

        $description = [string]$Apps.$appKey.description
        if ([string]::IsNullOrWhiteSpace($description)) {
            $description = '暂无详细介绍。安装前请先通过软件官方资料了解其用途。'
        }

        # One tooltip owner lets the name, checkbox and row padding show the
        # same description. Child tooltips would hide the ancestor tooltip.
        $appToolTip = [Windows.Controls.ToolTip]::new()
        # Popups have a separate visual tree; share the live dictionary so
        # theme and font-size changes also reach a tooltip that is already open.
        $appToolTip.Resources.MergedDictionaries.Add($sync.Form.Resources)
        $appToolTip.Padding = '14'
        $appToolTip.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'ToolTipBackgroundColor')
        $appToolTip.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'MainForegroundColor')
        $appToolTip.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BorderColor')
        $appToolTip.SetResourceReference([Windows.Controls.Control]::FontFamilyProperty, 'FontFamily')
        $appToolTip.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, 'FontSize')
        $appToolTip.SetResourceReference([Windows.FrameworkElement]::MaxWidthProperty, 'ToolTipWidth')
        $details = [Windows.Controls.StackPanel]::new()
        $title = [Windows.Controls.TextBlock]::new()
        $title.Text = [string]$Apps.$appKey.content
        $title.TextWrapping = 'Wrap'
        $title.FontWeight = 'SemiBold'
        $title.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'HeaderFontSize')
        $null = $details.Children.Add($title)

        $summary = [Windows.Controls.TextBlock]::new()
        $summary.Text = $description
        $summary.TextWrapping = 'Wrap'
        $summary.Margin = '0,8,0,0'
        $null = $details.Children.Add($summary)

        $packageIds = @()
        foreach ($manager in @('winget', 'choco')) {
            $id = [string]$Apps.$appKey.$manager
            if (-not [string]::IsNullOrWhiteSpace($id) -and $id -ne 'na') {
                $packageIds += "$($manager): $id"
            }
        }
        if ($packageIds.Count -gt 0) {
            $packages = [Windows.Controls.TextBlock]::new()
            $packages.Text = $packageIds -join "`n"
            $packages.TextWrapping = 'Wrap'
            $packages.Margin = '0,10,0,0'
            $packages.Opacity = 0.8
            $null = $details.Children.Add($packages)
        }
        $appToolTip.Content = $details
        $border.ToolTip = $appToolTip
        [Windows.Controls.ToolTipService]::SetInitialShowDelay($border, 550)
        [Windows.Controls.ToolTipService]::SetBetweenShowDelay($border, 150)
        [Windows.Controls.ToolTipService]::SetShowDuration($border, 18000)
        $border.Add_MouseLeftButtonUp({
            $childCheckbox = ($this.Child | Where-Object {$_.Template.TargetType -eq [System.Windows.Controls.Checkbox]})[0]
            $childCheckBox.isChecked = -not $childCheckbox.IsChecked
        })
        $border.Add_MouseEnter({
            if (($sync.$($this.Tag).IsChecked) -eq $false) {
                $this.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, "AppInstallHighlightedColor")
            }
        })
        $border.Add_MouseLeave({
            if (($sync.$($this.Tag).IsChecked) -eq $false) {
                $this.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, "AppInstallUnselectedColor")
            }
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
            $borderElement = $this.Parent
            $borderElement.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, "AppInstallSelectedColor")
        })

        $checkbox.Add_Unchecked({
            Invoke-WPFSelectedCheckboxesUpdate -type "Remove" -checkboxName $this.Parent.Tag
            $borderElement = $this.Parent
            $borderElement.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, "AppInstallUnselectedColor")
        })

        # Keep names readable while showing a compact purpose on every row.
        # The complete text remains available from the row tooltip and UIA.
        $appText = [Windows.Controls.StackPanel]::new()
        $appText.Orientation = 'Vertical'
        $appText.HorizontalAlignment = 'Stretch'
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
        $null = $appText.Children.Add($appName)
        $null = $appText.Children.Add($appDescription)
        $checkBox.Content = $appText

        # Add accessibility properties to make the elements screen reader friendly
        $checkBox.SetValue([Windows.Automation.AutomationProperties]::NameProperty, $Apps.$appKey.content)
        $checkBox.SetValue([Windows.Automation.AutomationProperties]::HelpTextProperty, $description)
        $border.SetValue([Windows.Automation.AutomationProperties]::NameProperty, $Apps.$appKey.content)

        $border.Child = $checkBox
        # Add the border to the corresponding Category
        $TargetElement.Children.Add($border) | Out-Null
        return $checkbox
    }
