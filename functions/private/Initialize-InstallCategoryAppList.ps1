function Initialize-InstallCategoryAppList {
    <#
        .SYNOPSIS
            Clears the Target Element and sets up a "Loading" message. This is done, because loading of all apps can take a bit of time in some scenarios
            Iterates through all Categories and Apps and adds them to the UI
            Used to as part of the Install Tab UI generation
        .PARAMETER TargetElement
            The Element into which the Categories and Apps should be placed
        .PARAMETER Apps
            The Hashtable of Apps to be added to the UI
            The Categories are also extracted from the Apps Hashtable

    #>
        param(
            $TargetElement,
            $Apps
        )

        # Pre-group apps by category
        $appsByCategory = @{}
        foreach ($appKey in $Apps.Keys) {
            $category = $Apps.$appKey.Category
            if (-not $appsByCategory.ContainsKey($category)) {
                $appsByCategory[$category] = @()
            }
            $appsByCategory[$category] += $appKey
        }
        foreach ($category in $($appsByCategory.Keys | Sort-Object)) {
            # Create a container for category label + apps
            $categoryContainer = New-Object Windows.Controls.StackPanel
            $categoryContainer.Orientation = "Vertical"
            $categoryContainer.Margin = New-Object Windows.Thickness(0, 0, 0, 4)
            $categoryContainer.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
            [System.Windows.Automation.AutomationProperties]::SetName($categoryContainer, $Category)

            # Bind Width to the ItemsControl's ActualWidth to force full-row layout in WrapPanel
            $binding = New-Object Windows.Data.Binding
            $binding.Path = New-Object Windows.PropertyPath("ActualWidth")
            $binding.RelativeSource = New-Object Windows.Data.RelativeSource([Windows.Data.RelativeSourceMode]::FindAncestor, [Windows.Controls.ItemsControl], 1)
            [void][Windows.Data.BindingOperations]::SetBinding($categoryContainer, [Windows.FrameworkElement]::WidthProperty, $binding)

            # Add category label to container
            $toggleButton = New-Object Windows.Controls.Button
            $header = [Windows.Controls.Grid]::new()
            foreach ($width in @('Auto', '*', 'Auto')) {
                $column = [Windows.Controls.ColumnDefinition]::new()
                $column.Width = $width
                $null = $header.ColumnDefinitions.Add($column)
            }
            $chevron = [Windows.Controls.TextBlock]::new()
            $chevron.Text = [char]0xE70D
            $chevron.FontFamily = 'Segoe MDL2 Assets'
            $chevron.FontSize = 10
            $chevron.VerticalAlignment = 'Center'
            $chevron.Margin = '0,0,10,0'
            $null = $header.Children.Add($chevron)
            $title = [Windows.Controls.TextBlock]::new()
            $title.Text = $Category
            $title.TextWrapping = 'Wrap'
            [Windows.Controls.Grid]::SetColumn($title, 1)
            $null = $header.Children.Add($title)
            $count = [Windows.Controls.TextBlock]::new()
            $count.Text = [string]$appsByCategory[$category].Count
            $count.FontWeight = 'Normal'
            $count.VerticalAlignment = 'Center'
            $count.Margin = '16,0,0,0'
            $count.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SecondaryForegroundColor')
            $count.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'ButtonFontSize')
            [Windows.Controls.Grid]::SetColumn($count, 2)
            $null = $header.Children.Add($count)
            $toggleButton.Content = $header
            $toggleButton.Resources['AppCategoryChevron'] = $chevron
            $toggleButton.Resources['AppCategoryCount'] = $count
            $toggleButton.Resources['AppCategoryName'] = [string]$Category
            $toggleButton.HorizontalContentAlignment = 'Stretch'
            $toggleButton.Tag = "CategoryToggleButton"
            $toggleButton.SetResourceReference([Windows.Controls.Control]::StyleProperty, "CategoryHeaderStyle")
            $toggleButton.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, "HeaderFontSize")
            $toggleButton.SetResourceReference([Windows.Controls.Control]::FontFamilyProperty, "HeaderFontFamily")
            $toggleButton.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, "LabelboxForegroundColor")
            $toggleButton.Cursor = [System.Windows.Input.Cursors]::Hand
            $toggleButton.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
            $toggleButton.ToolTip = "展开或收起$Category。也可以按 Enter 或空格。"
            [Windows.Automation.AutomationProperties]::SetName($toggleButton, "展开或收起$Category")
            $sync.$Category = $toggleButton

            # Add click handler to toggle category visibility
            $toggleButton.Add_Click({
                param($sender, $e)

                # Find the parent StackPanel (categoryContainer)
                $categoryContainer = $sender.Parent
                if ($categoryContainer -and $categoryContainer.Children.Count -ge 2) {
                    # The WrapPanel is the second child
                    $wrapPanel = $categoryContainer.Children[1]

                    # Toggle visibility
                    if ($wrapPanel.Visibility -eq [Windows.Visibility]::Visible) {
                        $wrapPanel.Visibility = [Windows.Visibility]::Collapsed
                    } else {
                        $wrapPanel.Visibility = [Windows.Visibility]::Visible
                    }
                    Update-WinUtilAppCategoryHeader -Category $categoryContainer
                }
            })

            $null = $categoryContainer.Children.Add($toggleButton)

            # Add wrap panel for apps to container
            $wrapPanel = New-Object Windows.Controls.WrapPanel
            $wrapPanel.Orientation = "Horizontal"
            $wrapPanel.HorizontalAlignment = "Stretch"
            $wrapPanel.VerticalAlignment = "Top"
            $wrapPanel.Margin = New-Object Windows.Thickness(0, 0, 0, 0)
            $wrapPanel.Visibility = [Windows.Visibility]::Visible
            $wrapPanel.Tag = "CategoryWrapPanel_$category"

            # Preserve the category panel contract used by filtering while
            # giving every software row the full available list width.
            $rowWidth = [Windows.Data.Binding]::new('ActualWidth')
            $rowWidth.RelativeSource = [Windows.Data.RelativeSource]::new([Windows.Data.RelativeSourceMode]::Self)
            $null = [Windows.Data.BindingOperations]::SetBinding($wrapPanel, [Windows.Controls.WrapPanel]::ItemWidthProperty, $rowWidth)

            $null = $categoryContainer.Children.Add($wrapPanel)

            # Add the entire category container to the target element
            $null = $TargetElement.Items.Add($categoryContainer)

            # Add apps to the wrap panel
            $appsByCategory[$category] | Sort-Object @{ Expression = { [string]$Apps.$_.Content } }, @{ Expression = { $_ } } | ForEach-Object {
                $sync.$_ = $(Initialize-InstallAppEntry -TargetElement $wrapPanel -AppKey $_)
            }
        }
    }

function Update-WinUtilAppCategoryHeader {
    param([Parameter(Mandatory)]$Category, [int]$VisibleCount = -1)
    $button = $Category.Children[0]
    $wrap = $Category.Children[1]
    $chevron = $button.Resources['AppCategoryChevron']
    if ($chevron) { $chevron.Text = [char]$(if ($wrap.Visibility -eq 'Collapsed') { 0xE76C } else { 0xE70D }) }
    if ($VisibleCount -ge 0 -and $button.Resources['AppCategoryCount']) {
        $button.Resources['AppCategoryCount'].Text = [string]$VisibleCount
    }
}
